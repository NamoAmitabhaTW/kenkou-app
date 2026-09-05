// パタカラ 語音辨識的離線煙霧測試。
//
// 用電腦上的 sherpa-onnx(sherpa_onnx_macos)載入 assets/asr 裡同一顆德文模型,
// 餵一支 16kHz 單聲道 wav,印出辨識出的文字、token 路徑與對到的音節。
// 改 syllable_map.dart 或 hotwords.txt 之前先跑這個。
//
//   dart run tool/pataka_smoke.dart path/to/16k.wav [hotwordsScore]
//
// hotwordsScore 預設跟 app 一樣 3.0,給 0 就等於沒有熱詞。
//
// 做測試音檔可以用 macOS 內建的中文語音:
//   say -v Meijia "啪。啪。啪。" -o pa.aiff && afconvert -f WAVE -d LEI16@16000 -c 1 pa.aiff pa.wav
// 注意 afconvert 從 m4a 轉出來的 wav 是 WAVE_FORMAT_EXTENSIBLE,sherpa 讀不了,
// 要再用 python 的 wave 模組重寫成一般 PCM。
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
    // 跟 lib/kenkou/pataka_detector.dart 的 _config 一致。
    final recognizer = sherpa.OnlineRecognizer(sherpa.OnlineRecognizerConfig(
      model: model,
      decodingMethod: 'modified_beam_search',
      maxActivePaths: 4,
      hotwordsFile: 'assets/asr/de/hotwords.txt',
      hotwordsScore: hotwordsScore,
      enableEndpoint: false,
    ));
    final stream = recognizer.createStream();
    // 跟 app 一樣先墊半秒靜音暖機。
    stream.acceptWaveform(samples: Float32List(8000), sampleRate: 16000);

    const chunk = 1600; // 0.1 秒,模擬手機上麥克風串流的餵法
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
