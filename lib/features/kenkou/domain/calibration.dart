import 'package:face_mesh/face_mesh.dart';

class CalibrationWindow {
  CalibrationWindow({
    this.prepare = const Duration(seconds: 3),
    this.total = const Duration(seconds: 5),
    this.grace = const Duration(milliseconds: 500),
    this.minFrames = 20,
  });

  final Duration prepare;

  final Duration total;

  final Duration grace;

  final int minFrames;

  final _frames = <FaceFrame>[];
  DateTime? _openedAt;
  DateTime? _startedAt;
  DateTime? _lastFaceAt;
  bool _done = false;

  List<FaceFrame> get frames => List.unmodifiable(_frames);

  bool get isDone => _done;

  bool add(FaceFrame frame, DateTime now) {
    if (_done) return true;
    _openedAt ??= now;

    if (frame.hasFace) {
      _lastFaceAt = now;
      _startedAt ??= now;
    } else if (_startedAt != null && !_faceRecentlySeen(now)) {
      _startedAt = null;
      _frames.clear();
      return false;
    }

    final startedAt = _startedAt;
    if (startedAt == null) return false;
    final elapsed = now.difference(startedAt);
    if (frame.hasFace && elapsed >= prepare) _frames.add(frame);
    if (elapsed >= total && _frames.length >= minFrames) _done = true;
    return _done;
  }

  double progress(DateTime now) {
    final startedAt = _startedAt;
    if (startedAt == null) return 0;
    final ratio = now.difference(startedAt).inMilliseconds / total.inMilliseconds;
    return ratio.clamp(0.0, 1.0);
  }

  bool faceMissing(DateTime now) {
    final openedAt = _openedAt;
    if (openedAt == null || now.difference(openedAt) <= grace) return false;
    return !_faceRecentlySeen(now);
  }

  bool _faceRecentlySeen(DateTime now) {
    final lastFaceAt = _lastFaceAt;
    return lastFaceAt != null && now.difference(lastFaceAt) <= grace;
  }
}
