import 'dart:io';
import 'dart:typed_data';

import 'package:screen_capture/screen_capture.dart';

import '../debug_log.dart';
import 'mic_stream.dart';
import 'recording_store.dart';

class SessionRecorder {
  SessionRecorder({required this.kind, RecordingStore? store, MicStream? mic})
      : _store = store ?? RecordingStore(),
        _mic = mic ?? MicStream();

  final RecordingKind kind;

  final RecordingStore _store;
  final MicStream _mic;

  bool _isRecording = false;

  bool _closed = false;

  String? _rawVideoPath;
  String? _wavPath;
  String? _mergedPath;

  bool get isRecording => _isRecording;

  Future<void> start({void Function(Uint8List chunk)? onPcmChunk}) async {
    try {
      final output = await _store.newRecordingPath(kind: kind);
      _mergedPath = output;
      _rawVideoPath = output.replaceAll('.mp4', '.raw.mp4');
      _wavPath = output.replaceAll('.mp4', '.wav');

      await ScreenCapture.start(_rawVideoPath!, microphone: false);
      _isRecording = true;
      debugLog('REC', 'ReplayKit 已開始 → $_rawVideoPath');
    } catch (e) {
      debugLog('REC', 'ReplayKit 啟動失敗:$e');
      _mergedPath = null;
      _isRecording = false;
    }

    final micOk = await _mic.start(onChunk: onPcmChunk);
    debugLog('REC', '麥克風 ${micOk ? '已開始' : '沒開起來(權限?)'}');
  }

  Future<String?> finish({required int score, required int total}) async {
    if (_closed) return null;
    _closed = true;

    if (!_isRecording) {
      debugLog('REC', '沒有在錄製,跳過收尾');
      await _mic.dispose();
      return null;
    }
    _isRecording = false;

    final raw = await _stopScreenCapture();
    final wav = await _stopMicrophone();

    if (raw == null) {
      debugLog('REC', '沒有錄到畫面,這次沒有影片');
      return null;
    }

    final path = await _merge(raw: raw, wav: wav);
    return _writeIndex(path, score: score, total: total);
  }

  Future<void> discard() async {
    if (_closed) return;
    _closed = true;

    await _mic.dispose();
    if (!_isRecording) return;
    _isRecording = false;
    try {
      final path = await ScreenCapture.stop();
      if (path != null) await File(path).delete();
    } catch (e) {
      debugLog('REC', '中途收尾失敗:$e');
    }
  }

  Future<String?> _stopScreenCapture() async {
    try {
      final raw = await ScreenCapture.stop();
      debugLog('REC', 'ReplayKit 收尾 → $raw');
      return raw;
    } catch (e) {
      debugLog('REC', 'ReplayKit 收尾失敗:$e');
      return null;
    }
  }

  Future<String?> _stopMicrophone() async {
    try {
      final wav = _wavPath == null ? null : await _mic.stopAndSaveWav(_wavPath!);
      debugLog('REC', '麥克風收尾 → $wav');
      return wav;
    } catch (e) {
      debugLog('REC', '麥克風收尾失敗:$e');
      return null;
    } finally {
      await _mic.dispose();
    }
  }

  Future<String> _merge({required String raw, required String? wav}) async {
    final output = _mergedPath;
    if (wav == null || output == null) return raw;
    try {
      final merged =
          await ScreenCapture.merge(video: raw, audio: wav, output: output);
      debugLog('REC', '合成 → $merged');
      return merged ?? raw;
    } catch (e) {
      debugLog('REC', '合成失敗,保留無聲版本:$e');
      return raw;
    }
  }

  Future<String?> _writeIndex(String path, {required int score, required int total}) async {
    final fileName = path.split('/').last;
    try {
      await _store.add(
        SessionRecording(
          fileName: fileName,
          recordedAt: DateTime.now(),
          correctCount: score,
          total: total,
          kind: kind,
        ),
      );
      debugLog('REC', '已寫入影片記錄:$fileName');
      return path;
    } catch (e) {
      debugLog('REC', '寫入影片記錄失敗:$e');
      return null;
    }
  }
}
