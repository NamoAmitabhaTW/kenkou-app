import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

/// 答題過程的麥克風錄音,最後會合成進影片的音軌。
///
/// 刻意不讓 ReplayKit 也開麥克風 —— 同一支麥克風被兩個消費者搶,
/// 結果通常是其中一邊拿到無聲。改成這裡自己開,錄完再跟畫面合成。
class MicStream {
  static const sampleRate = 16000;

  final _recorder = AudioRecorder();
  final _pcm = BytesBuilder(copy: false);

  StreamSubscription<Uint8List>? _subscription;

  bool get isRunning => _subscription != null;

  /// 開始擷取。取樣原封不動累積起來,結束時寫成 wav。
  ///
  /// [onChunk] 每收到一段 PCM 就會被叫一次 —— 健口操拿它同時餵給語音辨識。
  /// 讓辨識器在這裡分流,而不是自己再開一次麥克風:同一支麥克風被兩個
  /// 消費者搶,結果通常是其中一邊拿到無聲。
  Future<bool> start({void Function(Uint8List chunk)? onChunk}) async {
    if (isRunning) return true;
    if (!await _recorder.hasPermission()) return false;

    _pcm.clear();

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );

    _subscription = stream.listen((chunk) {
      _pcm.add(chunk);
      onChunk?.call(chunk);
    });
    return true;
  }

  /// 停止擷取並把累積的取樣寫成 wav。沒有錄到東西時回傳 null。
  Future<String?> stopAndSaveWav(String path) async {
    if (!isRunning) return null;

    await _subscription?.cancel();
    _subscription = null;
    await _recorder.stop();

    final samples = _pcm.takeBytes();
    if (samples.isEmpty) return null;

    await File(path).writeAsBytes(_wrapAsWav(samples), flush: true);
    return path;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _recorder.dispose();
  }

  /// 補上 44 bytes 的 RIFF 檔頭。裸 PCM 沒有檔頭,AVFoundation 讀不了。
  static Uint8List _wrapAsWav(Uint8List pcm) {
    const channels = 1;
    const bitsPerSample = 16;
    const byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;

    final header = ByteData(44);
    var offset = 0;

    void writeTag(String tag) {
      for (final unit in tag.codeUnits) {
        header.setUint8(offset++, unit);
      }
    }

    void writeUint32(int value) {
      header.setUint32(offset, value, Endian.little);
      offset += 4;
    }

    void writeUint16(int value) {
      header.setUint16(offset, value, Endian.little);
      offset += 2;
    }

    writeTag('RIFF');
    writeUint32(36 + pcm.length);
    writeTag('WAVE');
    writeTag('fmt ');
    writeUint32(16); // PCM 的 fmt chunk 長度
    writeUint16(1); // 1 = 無壓縮 PCM
    writeUint16(channels);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(bitsPerSample);
    writeTag('data');
    writeUint32(pcm.length);

    return Uint8List.fromList(header.buffer.asUint8List() + pcm);
  }
}
