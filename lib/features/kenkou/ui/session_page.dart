import 'dart:async';

import 'package:face_mesh/face_mesh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/debug_log.dart';
import '../../../core/media/recording_store.dart';
import '../../../core/media/screen_capture_notice.dart';
import '../../../core/media/session_recorder.dart';
import '../domain/mouth_shape.dart';
import '../../../core/ui/overlays.dart';
import '../../../core/voice/pataka_detector.dart';
import '../../../core/voice/syllable.dart';
import '../domain/exercise_program.dart';
import '../domain/face_geometry.dart';
import 'face_markers.dart';
import 'lip_overlay.dart';
import 'session_hud.dart';
import 'session_result_view.dart';
import '../domain/session_runner.dart';
import '../domain/settings.dart';

enum SessionPhase {
  preparing,

  calibrating,

  running,

  done,
}

const _calibrationPrepare = Duration(seconds: 3);
const _calibrationTotal = Duration(seconds: 5);

const _calibrationMinFrames = 20;

///                                          ├→ [KenkouSession] → [SessionEvent]
class KenkouSessionPage extends StatefulWidget {
  const KenkouSessionPage({super.key, required this.settings});

  final KenkouSettings settings;

  @override
  State<KenkouSessionPage> createState() => _KenkouSessionPageState();
}

class _KenkouSessionPageState extends State<KenkouSessionPage>
    with SingleTickerProviderStateMixin {
  KenkouSettings get _settings => widget.settings;

  late final List<ExerciseStep> _steps = buildProgram(_settings);
  late final KenkouSession _session = KenkouSession(
    steps: _steps,
    defaultHold: _settings.hold,
    enterThreshold: _settings.enterThreshold,
  );

  final _classifier = MouthShapeClassifier();
  final _lips = LipsClosedDetector();
  final _recorder = SessionRecorder(kind: RecordingKind.kenkou);
  PatakaDetector? _detector;

  StreamSubscription<FaceFrame>? _frames;
  StreamSubscription<SyllableHit>? _hits;

  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  SessionPhase _phase = SessionPhase.preparing;
  String? _cameraError;
  FaceFrame _frame = const FaceFrame(hasFace: false);
  double _targetScore = 0;
  List<FaceFrame>? _calibrationBuffer;
  DateTime? _calibrationStartedAt;

  final _lipsHistory = <(DateTime, bool)>[];

  bool _voiceReady = false;

  String _lastHeardDebug = '';

  String? _thumbText;
  Timer? _thumbTimer;
  String? _hint;
  Timer? _hintTimer;
  Timer? _advanceTimer;

  DateTime? _lastRepAt;

  int _guidedRemaining = 0;
  Timer? _guidedTimer;

  bool _savingVideo = true;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    _frames = FaceMesh.frames.listen(_onFrame);
    try {
      await FaceMesh.start();
    } on PlatformException catch (e) {
      _cameraError = e.message ?? e.code;
    }

    if (!mounted) return;
    await ScreenCaptureNotice.showIfNeeded(context);
    if (!mounted) return;

    await _startVoiceRecognition();
    await _recorder.start(onPcmChunk: (chunk) {
      if (_phase == SessionPhase.running && _session.step.syllable != null) {
        _detector?.feed(chunk);
      }
    });
    if (!mounted) return;

    if (_cameraError != null) {
      setState(() {});
      return;
    }

    setState(() {
      _phase = SessionPhase.calibrating;
      _calibrationBuffer = [];
      _calibrationStartedAt = DateTime.now();
    });
  }

  Future<void> _startVoiceRecognition() async {
    try {
      final detector =
          await PatakaDetector.create(blankPenalty: _settings.blankPenalty);
      _detector = detector;
      _hits = detector.hits.listen(_onSyllable);
      _voiceReady = true;
      debugLog('KENKOU', '語音辨識已載入');
    } catch (e) {
      debugLog('KENKOU', '語音辨識載入失敗,怕踏卡啦 改手動計次:$e');
      _voiceReady = false;
    }
  }

  @override
  void dispose() {
    _frames?.cancel();
    _hits?.cancel();
    _thumbTimer?.cancel();
    _hintTimer?.cancel();
    _advanceTimer?.cancel();
    _guidedTimer?.cancel();
    _pulse.dispose();
    _recorder.discard();
    _detector?.dispose();
    FaceMesh.stop();
    super.dispose();
  }

  void _onFrame(FaceFrame frame) {
    if (!mounted) return;
    _recordLips(frame);

    if (_calibrationBuffer != null) {
      _collectCalibrationFrame(frame);
      return;
    }
    if (_phase != SessionPhase.running) return;

    final step = _session.step;
    if (!step.usesFaceScore) {
      if (step.marker != FaceMarker.none) {
        setState(() => _frame = frame);
      } else {
        _frame = frame;
      }
      return;
    }

    final score = _scoreFor(step, frame);
    final event = _session.onFaceScore(score);
    setState(() {
      _frame = frame;
      _targetScore = score;
    });
    _handle(event);
  }

  void _collectCalibrationFrame(FaceFrame frame) {
    final buffer = _calibrationBuffer!;
    final elapsed = _calibrationElapsed;
    if (elapsed >= _calibrationPrepare && frame.hasFace) buffer.add(frame);
    if (elapsed >= _calibrationTotal && buffer.length >= _calibrationMinFrames) {
      _classifier.calibrate(buffer);
      _lips.calibrate(buffer);
      _calibrationBuffer = null;
      _calibrationStartedAt = null;
      _phase = SessionPhase.running;
      _enterStep();
    }
    setState(() => _frame = frame);
  }

  Duration get _calibrationElapsed => _calibrationStartedAt == null
      ? Duration.zero
      : DateTime.now().difference(_calibrationStartedAt!);

  static const _calibrationHeadline = '嘴巴閉起來\n放鬆';

  double get _calibrationProgress =>
      (_calibrationElapsed.inMilliseconds / _calibrationTotal.inMilliseconds)
          .clamp(0.0, 1.0);

  double _scoreFor(ExerciseStep step, FaceFrame frame) {
    if (!frame.isPoseUsable) return 0;
    return switch (step.mode) {
      StepMode.face => _session.targetShape == null
          ? 0
          : _classifier.scoreFor(frame, _session.targetShape!),
      StepMode.speech || StepMode.guided => 0,
    };
  }

  void _recordLips(FaceFrame frame) {
    _lipsHistory.add((DateTime.now(), _lips.isClosed(frame)));
    if (_lipsHistory.length > 90) _lipsHistory.removeAt(0);
  }

  bool _lipsClosedBefore(DateTime onset) {
    final from = onset.subtract(const Duration(milliseconds: 450));
    final to = onset.add(const Duration(milliseconds: 80));
    for (final (at, closed) in _lipsHistory) {
      if (closed && !at.isBefore(from) && !at.isAfter(to)) return true;
    }
    return false;
  }

  void _onSyllable(SyllableHit hit) {
    if (!mounted || _phase != SessionPhase.running) return;
    final step = _session.step;
    final target = step.syllable;
    if (target == null || _session.stepComplete) return;
    if (hit.unknown && target != Syllable.ra) return;

    final lipsClosed = _lipsClosedBefore(hit.onset);
    final effective = resolveSyllable(
        heard: hit.syllable, target: target, lipsClosed: lipsClosed);
    _lastHeardDebug = '「${hit.char}」${hit.syllable.name}'
        '${lipsClosed ? '(閉唇)' : ''} → ${effective?.name ?? '不採信'}';
    debugLog('KENKOU', '目標 ${target.name}:$_lastHeardDebug');

    final event =
        effective == null ? SessionEvent.none : _session.onSyllable(effective, at: hit.onset);
    if (event == SessionEvent.none) {
      _maybeAskAgain(target);
    } else {
      _lastRepAt = DateTime.now();
    }
    _handle(event);
  }

  void _maybeAskAgain(Syllable target) {
    final justCounted = _lastRepAt != null &&
        DateTime.now().difference(_lastRepAt!) < const Duration(milliseconds: 800);
    if (justCounted) return;
    _showHint('再說一次「${target.label}」');
  }

  void _enterStep() {
    _guidedTimer?.cancel();
    _hint = null;
    _detector?.restart();

    final step = _session.step;
    if (step.marker != FaceMarker.none) {
      _pulse.repeat();
    } else {
      _pulse.stop();
    }
    if (step.mode == StepMode.guided) _startCountdown(step);
    if (mounted) setState(() {});
  }

  void _startCountdown(ExerciseStep step) {
    _guidedTimer?.cancel();
    _guidedRemaining = step.guidedSeconds;
    _guidedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _guidedRemaining--);
      if (_guidedRemaining > 0) return;
      timer.cancel();
      _handle(_session.completeGuided());
    });
  }

  void _handle(SessionEvent event) {
    switch (event) {
      case SessionEvent.none:
        break;
      case SessionEvent.partial:
        final next = _session.targetShape;
        if (next != null) {
          _showHint('很好!接著「${next.label}」');
        }
      case SessionEvent.rep:
        _showThumb('做對了!');
      case SessionEvent.stepDone:
        _guidedTimer?.cancel();
        _showThumb(_session.step.mode == StepMode.guided ? '完成!' : '做對了!');
        _advanceTimer = Timer(const Duration(milliseconds: 1400), _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    _session.advance();
    if (_session.isFinished) {
      _finish();
    } else {
      _enterStep();
    }
  }

  void _skip() {
    if (_phase != SessionPhase.running) return;
    _guidedTimer?.cancel();
    final event = _session.skip();
    if (event != SessionEvent.stepDone) return;
    _advanceTimer = Timer(const Duration(milliseconds: 200), _advance);
    setState(() {});
  }

  void _showThumb(String text) {
    _thumbTimer?.cancel();
    setState(() => _thumbText = text);
    _thumbTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _thumbText = null);
    });
  }

  void _showHint(String text) {
    _hintTimer?.cancel();
    setState(() => _hint = text);
    _hintTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  Future<void> _finish() async {
    _guidedTimer?.cancel();
    _pulse.stop();
    setState(() => _phase = SessionPhase.done);

    await _hits?.cancel();
    _hits = null;
    FaceMesh.stop();

    final path = await _recorder.finish(
      score: _session.completedSteps,
      total: _steps.length,
    );
    if (!mounted) return;
    setState(() {
      _videoPath = path;
      _savingVideo = false;
    });
  }

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('要結束健口操嗎?', style: TextStyle(fontSize: 22)),
        content: const Text('這次的影片不會保存。', style: TextStyle(fontSize: 17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('繼續做', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('結束', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == SessionPhase.done) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SessionResultView(
            completed: _session.completedSteps,
            total: _steps.length,
            savingVideo: _savingVideo,
            videoPath: _videoPath,
          ),
        ),
      );
    }

    final step = _phase == SessionPhase.running ? _session.step : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const FaceMeshPreview(),
          const ScrimGradient(),
          if (step?.mode == StepMode.face)
            Positioned.fill(
              child: CustomPaint(
                painter: LipOverlayPainter(
                    frame: _frame, matched: _session.isHolding),
              ),
            ),
          if (step != null && step.marker != FaceMarker.none)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  painter: FaceMarkerPainter(
                    frame: _frame,
                    marker: step.marker,
                    side: step.side,
                    matched: step.usesFaceScore && _session.isHolding,
                    pulse: _pulse.value,
                  ),
                ),
              ),
            ),
          SafeArea(
            child: SessionHud(
              session: _session,
              settings: _settings,
              step: step,
              frame: _frame,
              classifier: _classifier,
              lips: _lips,
              targetScore: _targetScore,
              isRecording: _recorder.isRecording,
              voiceReady: _voiceReady,
              hint: _hint,
              guidedRemaining: _guidedRemaining,
              lastHeard: _detector?.lastHeard,
              lastHeardDebug: _lastHeardDebug,
              onExit: _confirmExit,
              onSkip: _skip,
              onCountManually: () => _handle(_session.countManually()),
            ),
          ),
          if (_thumbText != null) ThumbOverlay(text: _thumbText!),
          if (_phase == SessionPhase.preparing)
            const ColoredBox(color: Colors.black87, child: PreparingView()),
          if (_phase == SessionPhase.calibrating)
            CalibrationOverlay(
              headline: _calibrationHeadline,
              progress: _calibrationProgress,
              hasFace: _frame.hasFace,
            ),
          if (_cameraError != null) CameraErrorOverlay(message: _cameraError!),
        ],
      ),
    );
  }
}
