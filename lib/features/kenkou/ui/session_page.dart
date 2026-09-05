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

/// 整套健口操走到哪裡。
enum SessionPhase {
  /// 相機、錄影、語音辨識還在起來。
  preparing,

  /// 正在記錄使用者放鬆時的臉,當作判定的基準。
  calibrating,

  /// 正在做動作。
  running,

  /// 結算。
  done,
}

/// 校正分兩段:「嘴巴閉起來」3 秒,再「放鬆」2 秒,共 5 秒。
///
/// 前段只是請使用者把嘴閉起來、把臉擺正,收到的影格不算數;後段才收「放鬆」
/// 時的臉當基準。原本是收滿 45 張(約 1.5 秒)就結束,長輩還沒擺好姿勢就抓完了,
/// 基準會被「還在動的臉」汙染。
const _calibrationPrepare = Duration(seconds: 3);
const _calibrationTotal = Duration(seconds: 5);

/// 後段至少要收到這麼多張有臉的影格才算數。時間到了但臉一直偵測不到,
/// 就繼續等 —— 拿空的基準去判定比多等幾秒糟得多。
const _calibrationMinFrames = 20;

/// 按下「開始」之後,依序做完整套健口操的畫面。
///
/// 這個類別只管**把輸入接到狀態機、把狀態機的事件變成回饋**:
///
///   相機影格 → [MouthShapeClassifier] 算分 ─┐
///                                          ├→ [KenkouSession] → [SessionEvent]
///   麥克風 PCM → [PatakaDetector] 聽音節 ──┘
///
/// 「做到次數就換下一個」的規則全在 [KenkouSession](純 Dart,可以直接測);
/// 畫面在 [SessionHud] 與 [SessionResultView];錄影在 [SessionRecorder]。
///
/// 整個過程用 ReplayKit 錄下來,跟快問快答走同一條錄影鏈。麥克風的 PCM
/// 同時分一份給語音辨識 —— 不自己再開一次麥克風,兩個消費者搶同一支
/// 麥克風的結果通常是其中一邊拿到無聲。
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

  /// 臉上標記的呼吸動畫。
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  SessionPhase _phase = SessionPhase.preparing;
  String? _cameraError;
  FaceFrame _frame = const FaceFrame(hasFace: false);
  double _targetScore = 0;
  List<FaceFrame>? _calibrationBuffer;
  DateTime? _calibrationStartedAt;

  /// 最近每張影格「嘴唇有沒有閉著」。パタカラ 用來判斷剛才那個音是不是 パ。
  final _lipsHistory = <(DateTime, bool)>[];

  /// 語音辨識有沒有起來。沒有的話 パタカラ 改成手動計次。
  bool _voiceReady = false;

  /// 除錯面板用:模型聽到什麼、當時嘴唇狀態。
  String _lastHeardDebug = '';

  // 回饋
  String? _thumbText;
  Timer? _thumbTimer;
  String? _hint;
  Timer? _hintTimer;
  Timer? _advanceTimer;

  /// 上一次真的算進次數的時間。用來壓掉「剛算過又叫人重說」的誤提示。
  DateTime? _lastRepAt;

  // 引導步驟的倒數
  int _guidedRemaining = 0;
  Timer? _guidedTimer;

  // 錄影
  bool _savingVideo = true;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  /// 相機、錄影、語音辨識都準備好才開始第一個動作。
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
    // 麥克風由 SessionRecorder 開一次,同一份 PCM 分流給語音辨識。
    //
    // 只有 パタカラ 那幾個步驟要聽音節,嘴型與舌頭的步驟不餵給解碼器:
    // 空轉的解碼會跟相機的臉部偵測搶 CPU(辨識器因此已經限制成單執行緒),
    // 而嘴型步驟正好是臉部偵測最忙的時候。麥克風本身不能關 —— 整段影片
    // 的音軌要靠它,而且同一支麥克風被兩個消費者搶會有一邊拿到無聲。
    // 換步驟時 _enterStep() 本來就會 restart() 重開串流並墊靜音暖機,
    // 所以中間這段沒餵不影響進到 パタカラ 之後的辨識。
    await _recorder.start(onPcmChunk: (chunk) {
      if (_phase == SessionPhase.running && _session.step.syllable != null) {
        _detector?.feed(chunk);
      }
    });
    if (!mounted) return;

    if (_cameraError != null) {
      // 相機開不起來就沒有嘴型可判,整套做不下去。
      setState(() {});
      return;
    }

    setState(() {
      _phase = SessionPhase.calibrating;
      _calibrationBuffer = [];
      _calibrationStartedAt = DateTime.now();
    });
  }

  /// 載入語音模型。失敗不擋著不讓做 —— パタカラ 改成使用者自己按 +1 計次。
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
    // 中途離開:錄到一半的檔案不留,免得佔空間又沒人看得到。
    _recorder.discard();
    _detector?.dispose();
    FaceMesh.stop();
    super.dispose();
  }

  // MARK: 相機輸入

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
      // 沒有要判定的步驟只在需要畫標記時重繪,其他情況不必每張影格都 setState。
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

  /// 收集放鬆時的臉。每個人放鬆時的 blendshape 也不會是全 0(嘴型、皺紋、
  /// 假牙都會影響),不先記下這個底,判定門檻就得為每個人重調。
  void _collectCalibrationFrame(FaceFrame frame) {
    final buffer = _calibrationBuffer!;
    final elapsed = _calibrationElapsed;
    // 前段收到的臉不算 —— 那時候使用者還在把嘴閉起來。
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

  /// 兩句一起顯示,不要換來換去 —— 長輩正在看鏡頭調整姿勢,字一變就得重新讀。
  static const _calibrationHeadline = '嘴巴閉起來\n放鬆';

  double get _calibrationProgress =>
      (_calibrationElapsed.inMilliseconds / _calibrationTotal.inMilliseconds)
          .clamp(0.0, 1.0);

  /// 這個步驟在這張影格上做到幾分。頭沒擺正時一律 0 —— 側臉的分數只是假資料。
  double _scoreFor(ExerciseStep step, FaceFrame frame) {
    if (!frame.isPoseUsable) return 0;
    return switch (step.mode) {
      StepMode.face => _session.targetShape == null
          ? 0
          : _classifier.scoreFor(frame, _session.targetShape!),
      StepMode.speech || StepMode.guided => 0,
    };
  }

  // MARK: 語音輸入

  void _recordLips(FaceFrame frame) {
    _lipsHistory.add((DateTime.now(), _lips.isClosed(frame)));
    if (_lipsHistory.length > 90) _lipsHistory.removeAt(0);
  }

  /// 這個音開始發出來之前,嘴唇有沒有閉起來過。
  ///
  /// 語音辨識的時間戳大約準到 0.1 秒,窗口開寬一點:發音前 0.45 秒到發音後 0.08 秒。
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
    // 模型聽不懂的音只在 ラ 的步驟算數,其他步驟不提示也不扣。
    if (hit.unknown && target != Syllable.ra) return;

    final lipsClosed = _lipsClosedBefore(hit.onset);
    final effective = resolveSyllable(
        heard: hit.syllable, target: target, lipsClosed: lipsClosed);
    _lastHeardDebug = '「${hit.char}」${hit.syllable.name}'
        '${lipsClosed ? '(閉唇)' : ''} → ${effective?.name ?? '不採信'}';
    debugLog('KENKOU', '目標 ${target.name}:$_lastHeardDebug');

    final event =
        effective == null ? SessionEvent.none : _session.onSyllable(effective);
    if (event == SessionEvent.none) {
      _maybeAskAgain(target);
    } else {
      _lastRepAt = DateTime.now();
    }
    _handle(event);
  }

  /// 沒算到的時候提醒再說一次。
  ///
  /// 刻意不說「聽到什麼」—— 模型聽錯時把錯的字秀出來只會讓人更困惑。
  /// 而且剛算過一次就先不提醒:同一個音可能被吐兩次,前一次已經算了,
  /// 第二次落空不代表使用者做錯。
  void _maybeAskAgain(Syllable target) {
    final justCounted = _lastRepAt != null &&
        DateTime.now().difference(_lastRepAt!) < const Duration(milliseconds: 800);
    if (justCounted) return;
    _showHint('再說一次「${target.label}」');
  }

  // MARK: 流程

  void _enterStep() {
    _guidedTimer?.cancel();
    _hint = null;
    // 上一個動作說到一半的音節不要帶進來。
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

  /// 引導步驟的倒數。數完就當這個動作做完了。
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
        // 停一下讓人看到「完成」,再換下一個動作。
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

    // 結算畫面不需要相機和辨識,先關掉省電。
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

  // MARK: 畫面

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
