import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../debug_log.dart';
import 'syllable.dart';
import 'syllable_map.dart';

/// 用 sherpa-onnx 在地端聽 パ / タ / カ / ラ,每聽到一次就送一個 [SyllableHit]。
///
/// 模型是德文的串流 zipformer transducer(int8 約 70MB):德文有 pa / ta / ka / ra
/// 四個音節,用真人錄音實測四個都認得(中文模型認不出 ラ,已拔掉)。
/// 它偶爾把 ta 聽成 ka、連續的 pa 會黏成 "paar",對照表在 syllable_map.dart。
/// 每次辨識結果有變化都印到 console(`[ASR de]`),對不到的字往對照表加。
///
/// 解碼用 modified_beam_search 加熱詞(assets/asr/de/hotwords.txt),把目標音節
/// 的路徑加分。sherpa-onnx 要把熱詞文字切成 token 得靠 bpe.vocab,這顆模型沒附,
/// 所以 bpe.vocab 是從 tokens.txt 產生的(見 assets/asr/README.md)。
///
/// 刻意**不**用 endpoint 自動 reset:reset 之後串流從零開始,前幾格沒有前後文,
/// 單獨一個音節很容易聽不到。整個動作只開一條串流,換動作時才 [restart],
/// 而且先墊半秒靜音當暖機。
class PatakaDetector {
  PatakaDetector._(this._de);

  static const sampleRate = 16000;

  /// 串流辨識大約落後這麼多,發音的起點往前抓。
  static const _latency = Duration(milliseconds: 500);

  final _Engine _de;
  final _hits = StreamController<SyllableHit>.broadcast();

  /// 剩下的半個取樣。錄音串流的 chunk 不保證是偶數 bytes。
  Uint8List _carry = Uint8List(0);
  bool _disposed = false;

  /// 每辨識到一個目標音節就送一次。
  Stream<SyllableHit> get hits => _hits.stream;

  /// 目前聽到什麼,除錯面板用。
  String get lastHeard => _de.text;

  /// 熱詞加分的預設值。sherpa-onnx 預設 1.5,但用 macOS 德文語音加噪音實測,
  /// 1.5 跟沒加一樣,3.0 在吵的環境多撿回 ta / ka / la,乾淨音檔沒多出誤判。
  static const defaultHotwordsScore = 3.0;

  /// 載入模型。第一次會把 assets 複製到 app support 目錄 ——
  /// sherpa-onnx 只吃檔案路徑,讀不了 Flutter 的 asset bundle。
  static Future<PatakaDetector> create({
    double blankPenalty = 0,
    double hotwordsScore = defaultHotwordsScore,
  }) async {
    sherpa.initBindings();
    final deDir = await _materialize('assets/asr/de', const [
      'encoder.int8.onnx',
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
            encoder: '$deDir/encoder.int8.onnx',
            decoder: '$deDir/decoder.onnx',
            joiner: '$deDir/joiner.onnx',
          ),
          tokens: '$deDir/tokens.txt',
          // 16kHz 單聲道單執行緒就跟得上,開多條反而跟相機的臉部偵測搶 CPU。
          numThreads: 1,
          debug: false,
          // 熱詞文字 → token 用的切詞表,見 assets/asr/README.md。
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
      // 熱詞只在 modified_beam_search 生效,greedy_search 會默默忽略。
      decodingMethod: 'modified_beam_search',
      // beam 寬度。要認的只有四個單音節,4 條路徑就夠;加大只是多花算力。
      maxActivePaths: 4,
      hotwordsFile: hotwordsFile,
      hotwordsScore: hotwordsScore,
      // 靈敏度刻度換算而來,決定模型多願意吐字(見 voice_sensitivity.dart)。
      blankPenalty: blankPenalty,
      // 不自動切句,理由見類別說明。
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
      // 大檔用長度判斷要不要重寫:換了模型之後才會重新複製。
      // 小檔(熱詞、切詞表)改了內容長度未必變,每次都重寫,反正很小。
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

  /// 換動作時重新開始聽,把上一個動作說到一半的東西丟掉。
  void restart() {
    if (_disposed) return;
    _de.restart();
    _carry = Uint8List(0);
  }

  /// 餵進 16kHz、單聲道、16-bit little-endian 的 PCM。
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

  // MARK: 文字 → 音節(解析本體在 syllable_map.dart,純 Dart 可測)

  static List<_RawHit> _parseGerman(
      String text, int seen, void Function(int) commit) {
    final (items, newSeen) = parseGermanIncrement(text, seen);
    commit(newSeen);

    final hits = <_RawHit>[];
    for (final item in items) {
      if (item.label.isEmpty) {
        // 對不到的字往 syllable_map.dart 加。
        debugLog('ASR', '「${item.text}」不在對照表');
        continue;
      }
      hits.add(_RawHit(item.text, _syllableOf(item.label), unknown: item.unknown));
    }
    return hits;
  }

  static Syllable _syllableOf(String label) => Syllable.values.byName(label == 'la' ? 'ra' : label);
}

/// 一顆串流辨識器加上它的解析狀態。
class _Engine {
  _Engine(this._recognizer, this._parse) : _stream = _recognizer.createStream() {
    _prime();
  }

  final sherpa.OnlineRecognizer _recognizer;
  final List<_RawHit> Function(String text, int seen, void Function(int) commit) _parse;
  sherpa.OnlineStream _stream;

  /// 結果文字裡已經處理到第幾個詞。
  int _seen = 0;

  String text = '';

  void restart() {
    _stream.free();
    _stream = _recognizer.createStream();
    _seen = 0;
    text = '';
    _prime();
  }

  /// 先餵半秒靜音暖機,串流剛開始那幾格的辨識特別差。
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

/// 解析出來、還沒加上時間戳的一次命中。
class _RawHit {
  const _RawHit(this.text, this.syllable, {this.unknown = false});
  final String text;
  final Syllable syllable;
  final bool unknown;
}

/// 一次辨識到的音節、模型實際聽到的字,以及它大約是什麼時候開始發出來的。
class SyllableHit {
  const SyllableHit(this.syllable, this.char, this.onset, {this.unknown = false});
  final Syllable syllable;
  final String char;
  final DateTime onset;

  /// 模型吐的是聽不懂的音。德文模型目前不會發生,欄位留給之後換模型用。
  final bool unknown;
}
