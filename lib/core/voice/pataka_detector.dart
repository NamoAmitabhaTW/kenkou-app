import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../debug_log.dart';
import 'syllable.dart';
import 'syllable_map.dart';

class PatakaDetector {
  PatakaDetector._(this._de);

  static const sampleRate = 16000;

  static const _latency = Duration(milliseconds: 500);

  final _Engine _de;
  final _hits = StreamController<SyllableHit>.broadcast();

  Uint8List _carry = Uint8List(0);
  bool _disposed = false;

  Stream<SyllableHit> get hits => _hits.stream;

  String get lastHeard => _de.text;

  static const defaultHotwordsScore = 3.0;

  static Future<PatakaDetector> create({
    double blankPenalty = 0,
    double hotwordsScore = defaultHotwordsScore,
  }) async {
    sherpa.initBindings();
    final deDir = await _materialize('assets/asr/de', const [
      'encoder.onnx',
      'decoder.onnx',
      'joiner.onnx',
      'tokens.txt',
      'bpe.vocab',
      'hotwords.txt',
    ]);
    final de = _Engine(
      sherpa.OnlineRecognizer(_config(
        sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: '$deDir/encoder.onnx',
            decoder: '$deDir/decoder.onnx',
            joiner: '$deDir/joiner.onnx',
          ),
          tokens: '$deDir/tokens.txt',
          numThreads: 1,
          debug: false,
          modelingUnit: 'bpe',
          bpeVocab: '$deDir/bpe.vocab',
        ),
        blankPenalty: blankPenalty,
        hotwordsFile: '$deDir/hotwords.txt',
        hotwordsScore: hotwordsScore,
      )),
      _parseGerman,
    );
    return PatakaDetector._(de);
  }

  static sherpa.OnlineRecognizerConfig _config(
    sherpa.OnlineModelConfig model, {
    required double blankPenalty,
    required String hotwordsFile,
    required double hotwordsScore,
  }) {
    return sherpa.OnlineRecognizerConfig(
      model: model,
      decodingMethod: 'modified_beam_search',
      maxActivePaths: 4,
      hotwordsFile: hotwordsFile,
      hotwordsScore: hotwordsScore,
      blankPenalty: blankPenalty,
      enableEndpoint: false,
    );
  }

  static const _alwaysRewriteBelow = 1 << 20;

  static Future<String> _materialize(String assetDir, List<String> names) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/${assetDir.replaceFirst('assets/', '')}');
    if (!await dir.exists()) await dir.create(recursive: true);

    for (final name in names) {
      final file = File('${dir.path}/$name');
      final data = await rootBundle.load('$assetDir/$name');
      if (data.lengthInBytes > _alwaysRewriteBelow &&
          await file.exists() &&
          await file.length() == data.lengthInBytes) {
        continue;
      }
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return dir.path;
  }

  void restart() {
    if (_disposed) return;
    _de.restart();
    _carry = Uint8List(0);
  }

  void feed(Uint8List pcm16) {
    if (_disposed) return;

    final bytes = _carry.isEmpty
        ? pcm16
        : (BytesBuilder(copy: false)
              ..add(_carry)
              ..add(pcm16))
            .takeBytes();
    final usable = bytes.length & ~1;
    _carry = usable == bytes.length
        ? Uint8List(0)
        : Uint8List.fromList(bytes.sublist(usable));

    final count = usable ~/ 2;
    if (count == 0) return;

    final view = ByteData.sublistView(bytes, 0, usable);
    final samples = Float32List(count);
    for (var i = 0; i < count; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }

    final now = DateTime.now();
    for (final raw in _de.feed(samples)) {
      debugLog('ASR', '「${raw.text}」 → ${raw.syllable.name}');
      if (!_hits.isClosed) {
        _hits.add(SyllableHit(raw.syllable, raw.text, now.subtract(_latency), unknown: raw.unknown));
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _hits.close();
    _de.dispose();
  }

  static List<_RawHit> _parseGerman(
      String text, int seen, void Function(int) commit) {
    final (items, newSeen) = parseGermanIncrement(text, seen);
    commit(newSeen);

    final hits = <_RawHit>[];
    for (final item in items) {
      if (item.label.isEmpty) {
        debugLog('ASR', '「${item.text}」不在對照表');
        continue;
      }
      hits.add(_RawHit(item.text, _syllableOf(item.label), unknown: item.unknown));
    }
    return hits;
  }

  static Syllable _syllableOf(String label) => Syllable.values.byName(label == 'la' ? 'ra' : label);
}

class _Engine {
  _Engine(this._recognizer, this._parse) : _stream = _recognizer.createStream() {
    _prime();
  }

  final sherpa.OnlineRecognizer _recognizer;
  final List<_RawHit> Function(String text, int seen, void Function(int) commit) _parse;
  sherpa.OnlineStream _stream;

  int _seen = 0;

  String text = '';

  void restart() {
    _stream.free();
    _stream = _recognizer.createStream();
    _seen = 0;
    text = '';
    _prime();
  }

  void _prime() {
    _stream.acceptWaveform(samples: Float32List(PatakaDetector.sampleRate ~/ 2), sampleRate: PatakaDetector.sampleRate);
    while (_recognizer.isReady(_stream)) {
      _recognizer.decode(_stream);
    }
  }

  List<_RawHit> feed(Float32List samples) {
    _stream.acceptWaveform(samples: samples, sampleRate: PatakaDetector.sampleRate);
    while (_recognizer.isReady(_stream)) {
      _recognizer.decode(_stream);
    }
    final result = _recognizer.getResult(_stream).text;
    if (result == text) return const [];
    text = result;
    return _parse(result, _seen, (n) => _seen = n);
  }

  void dispose() {
    _stream.free();
    _recognizer.free();
  }
}

class _RawHit {
  const _RawHit(this.text, this.syllable, {this.unknown = false});
  final String text;
  final Syllable syllable;
  final bool unknown;
}

class SyllableHit {
  const SyllableHit(this.syllable, this.char, this.onset, {this.unknown = false});
  final Syllable syllable;
  final String char;
  final DateTime onset;

  final bool unknown;
}
