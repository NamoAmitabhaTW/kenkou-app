import 'dart:io';
import 'dart:typed_data';

import 'package:futuremode2026/core/voice/syllable_map.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('用法: dart run tool/pataka_smoke.dart <16k mono wav>');
    exit(64);
  }
  sherpa.initBindings();
  final wave = sherpa.readWave(args[0]);
  stdout.writeln('sampleRate ${wave.sampleRate}, '
      '${(wave.samples.length / wave.sampleRate).toStringAsFixed(2)}s');

  final hotwordsScore = args.length > 1 ? double.parse(args[1]) : 3.0;
  final engines = {
    'de': (
      sherpa.OnlineModelConfig(
        transducer: const sherpa.OnlineTransducerModelConfig(
          encoder: 'assets/asr/de/encoder.onnx',
          decoder: 'assets/asr/de/decoder.onnx',
          joiner: 'assets/asr/de/joiner.onnx',
        ),
        tokens: 'assets/asr/de/tokens.txt',
        modelingUnit: 'bpe',
        bpeVocab: 'assets/asr/de/bpe.vocab',
        debug: false,
      ),
      parseGermanIncrement,
    ),
  };

  for (final entry in engines.entries) {
    final (model, parse) = entry.value;
    final recognizer = sherpa.OnlineRecognizer(sherpa.OnlineRecognizerConfig(
      model: model,
      decodingMethod: 'modified_beam_search',
      maxActivePaths: 4,
      hotwordsFile: 'assets/asr/de/hotwords.txt',
      hotwordsScore: hotwordsScore,
      enableEndpoint: false,
    ));
    final stream = recognizer.createStream();
    stream.acceptWaveform(samples: Float32List(8000), sampleRate: 16000);

    const chunk = 1600;
    final counts = <String, int>{};
    var seen = 0;
    var last = '';
    final sw = Stopwatch()..start();
    for (var offset = 0; offset < wave.samples.length + chunk * 10; offset += chunk) {
      final end = (offset + chunk).clamp(0, wave.samples.length);
      final samples = offset < wave.samples.length
          ? Float32List.sublistView(wave.samples, offset, end)
          : Float32List(chunk);
      stream.acceptWaveform(samples: samples, sampleRate: wave.sampleRate);
      while (recognizer.isReady(stream)) {
        recognizer.decode(stream);
      }
      final text = recognizer.getResult(stream).text;
      if (text == last) continue;
      last = text;
      final (items, next) = parse(text, seen);
      seen = next;
      for (final item in items) {
        final label = item.label.isEmpty ? '?' : '${item.label}${item.unknown ? '?(unk)' : ''}';
        counts[label] = (counts[label] ?? 0) + 1;
        stdout.writeln('  ${(end / wave.sampleRate).toStringAsFixed(2)}s  ${item.text} → $label');
      }
    }
    sw.stop();
    stdout.writeln('[${entry.key}] ${sw.elapsedMilliseconds} ms  聽到: $last');
    stdout.writeln('[${entry.key}] tokens: '
        '${recognizer.getResult(stream).tokens.map((t) => '[$t]').join(' ')}');
    stdout.writeln('[${entry.key}] 音節: $counts');
    stream.free();
    recognizer.free();
  }
}
