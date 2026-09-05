import 'dart:io';
import 'dart:typed_data';

import 'package:screen_capture/screen_capture.dart';

import '../debug_log.dart';
import 'mic_stream.dart';
import 'recording_store.dart';

/// 把一次活動(答題 / 健口操)錄成一支有聲音的影片。
///
/// 這條鏈健口操和快問快答完全一樣,以前兩頁各抄了一份 —— 然後就開始漂移:
/// 一邊記得中途離開要刪檔、另一邊不記得;一邊記得還原 audio session、
/// 另一邊不記得。收成一個類別之後,修一次兩邊都好。
///
/// 為什麼畫面和聲音分開錄:麥克風由 [MicStream] 統一開一次,ReplayKit 那邊
/// 不開。同一支麥克風被兩個消費者搶,結果通常是其中一邊整段無聲。
///
/// 為什麼每一段各自 try:停畫面、停聲音、合成是三件獨立的事。以前包在同一個
/// try 裡,合成一失敗就連已經錄好的畫面一起丟掉,使用者看到的表徵是
/// 「明明按了允許卻沒有影片」。現在合成失敗就退回無聲版本 —— 有畫面的
/// 影片仍然值得留下來。
class SessionRecorder {
  SessionRecorder({required this.kind, RecordingStore? store, MicStream? mic})
      : _store = store ?? RecordingStore(),
        _mic = mic ?? MicStream();

  /// 錄的是哪個活動,決定檔名前綴與影片記錄裡的成績說法。
  final RecordingKind kind;

  final RecordingStore _store;
  final MicStream _mic;

  bool _isRecording = false;

  /// 已經收過尾了。[finish] 和 [discard] 都可能被呼叫,而頁面 dispose 時
  /// 一定會再呼叫一次 [discard] —— 沒有這個旗標的話麥克風會被 dispose 兩次。
  bool _closed = false;

  /// ReplayKit 的無聲影片、麥克風的 wav、以及合成後成品要放的位置。
  String? _rawVideoPath;
  String? _wavPath;
  String? _mergedPath;

  /// 正在錄。頁面靠它決定要不要顯示「錄影中」。
  bool get isRecording => _isRecording;

  /// 開始錄。
  ///
  /// **不丟例外** —— 沒錄到影片不該擋住活動本身,長輩是來做健口操的,
  /// 不是來錄影的。失敗就是 [isRecording] 留在 false。
  ///
  /// [onPcmChunk] 每收到一段麥克風 PCM 就被呼叫一次。健口操拿它把同一份
  /// 聲音分給語音辨識,而不是自己再開一次麥克風。
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

  /// 停止錄製、合成、寫進影片記錄。回傳成品路徑;沒錄到就是 null。
  ///
  /// [score] / [total] 是要記在影片旁邊的成績:快問快答是答對題數,
  /// 健口操是做完的動作數。
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

  /// 中途離開:停掉並把錄到一半的檔案刪掉。
  ///
  /// 留著只會佔空間 —— 它從來不會進影片記錄,使用者根本看不到它。
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

  /// 畫面和聲音是分開錄的,合成才會變成一支有聲音的 mp4。
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

  /// 寫不進索引的影片等於不存在(「影片記錄」列表讀的就是索引),
  /// 所以這一步失敗要回報 null,頁面才不會說「已存到影片記錄」。
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
