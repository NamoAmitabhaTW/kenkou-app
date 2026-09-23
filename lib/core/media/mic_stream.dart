import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

class MicStream {
  static const sampleRate = 16000;

  final _recorder = AudioRecorder();
  final _pcm = BytesBuilder(copy: false);

  StreamSubscription<Uint8List>? _subscription;

  bool get isRunning => _subscription != null;

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
    writeUint32(16);
    writeUint16(1);
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
