import '../../../core/voice/syllable.dart';
import 'exercise_program.dart';
import 'mouth_shape.dart';

/// 一次輸入(影格分數 / 音節 / 倒數結束)之後發生了什麼。
enum SessionEvent {
  none,

  /// 一組多段動作(鼓頰 → 縮嘴)做完了其中一段,還沒算一次。
  partial,

  /// 做對了一次。
  rep,

  /// 這個動作的次數到了。呼叫端顯示完回饋之後要自己呼叫 [KenkouSession.advance]。
  stepDone,
}

/// 依序做完整套健口操的狀態機。
///
/// 純 Dart、不碰 UI 也不碰相機,所以可以直接餵分數跟音節來測。
/// 「做到次數就換下一個」的規則全部在這裡,頁面只負責把事件畫出來。
class KenkouSession {
  KenkouSession({
    required this.steps,
    required this.defaultHold,
    this.enterThreshold = 0.80,
  }) : assert(steps.isNotEmpty) {
    _enterStep();
  }

  final List<ExerciseStep> steps;

  /// 嘴型動作沒有特別指定時要維持多久。
  final Duration defaultHold;
  final double enterThreshold;

  int _index = 0;
  bool _finished = false;

  /// 目前這個動作做了幾次。
  int reps = 0;

  /// 多段動作目前做到第幾段。
  int subIndex = 0;

  /// 次數到了、正在等呼叫端 [advance]。這段期間所有輸入都忽略,
  /// 不然回饋動畫還在放,下一個動作的次數已經偷偷開始累積。
  bool stepComplete = false;

  int completedSteps = 0;
  int skippedSteps = 0;

  HoldTracker? _tracker;

  bool get isFinished => _finished;
  int get index => _index;
  ExerciseStep get step => steps[_index];
  HoldTracker? get tracker => _tracker;

  /// 目前要做的嘴型;不是嘴型動作時為 null。
  MouthShape? get targetShape =>
      step.mode == StepMode.face ? step.shapes[subIndex] : null;

  /// 多段動作的下一段;最後一段或非多段動作時為 null。
  MouthShape? get nextShape =>
      step.mode == StepMode.face && subIndex + 1 < step.shapes.length
          ? step.shapes[subIndex + 1]
          : null;

  bool get isHolding =>
      _tracker?.state == HoldState.holding ||
      _tracker?.state == HoldState.completed;

  double get holdProgress => _tracker?.progress ?? 0;

  void _enterStep() {
    reps = 0;
    subIndex = 0;
    stepComplete = false;
    _lastCountedAt = null;
    _tracker = step.usesFaceScore
        ? HoldTracker(
            enterThreshold: enterThreshold,
            // 遲滯 0.1:分數在門檻附近抖動時狀態才不會一直翻。
            exitThreshold: enterThreshold - 0.10,
            requiredHold: step.hold ?? defaultHold,
          )
        : null;
  }

  bool get _acceptsInput => !_finished && !stepComplete;

  /// 餵進目前目標(嘴型 / 臉頰 / 舌頭)的分數(每張影格一次)。
  SessionEvent onFaceScore(double score) {
    final tracker = _tracker;
    if (!_acceptsInput || tracker == null) return SessionEvent.none;

    final before = tracker.completions;
    tracker.update(score);
    if (tracker.completions == before) return SessionEvent.none;

    subIndex++;
    if (step.mode == StepMode.face && subIndex < step.shapes.length) {
      // 換下一段的目標,計時器歸零重來。
      tracker.reset();
      return SessionEvent.partial;
    }
    subIndex = 0;
    return _countRep();
  }

  /// 同一個音在這麼短的時間內再出現,當成同一次發音,不重複計次。
  ///
  /// 兩種情況都會發生:一聲「踏」被模型吐成 "ta Ta" 兩個詞(熱詞加分調高時
  /// 特別明顯),或是使用者一口氣連念好幾聲。不擋的話一次發音就算好幾次,
  /// 長輩還沒做滿就顯示做完了 —— 這個動作等於白做。
  ///
  /// 400 毫秒是取捨:模型的重複輸出多半落在 100~300 毫秒內,而長輩一次一次
  /// 清楚地念大約隔 0.7 秒以上。想念得更快的人會被吃掉幾次,但「少算」只是
  /// 多念幾次,「多算」卻是整個動作沒練到。
  static const repCooldown = Duration(milliseconds: 400);

  /// 上一次真的算進次數的時間(用發音起點,不是收到結果的時間)。
  DateTime? _lastCountedAt;

  /// 麥克風聽到一個音節。只有目標音節才算數。
  ///
  /// [at] 是這個音**開始發出來**的時間 —— 用它而不是「現在」,因為串流辨識
  /// 本來就慢半拍,用收到結果的時間去量間隔會失真。
  SessionEvent onSyllable(Syllable syllable, {required DateTime at}) {
    if (!_acceptsInput || step.mode != StepMode.speech) return SessionEvent.none;
    if (syllable != step.syllable) return SessionEvent.none;
    // 這裡已經確定是目標音,所以只要看時間就夠,不必再比對是不是同一個音。
    final last = _lastCountedAt;
    if (last != null && at.difference(last) < repCooldown) {
      return SessionEvent.none;
    }
    _lastCountedAt = at;
    return _countRep();
  }

  /// 引導步驟倒數結束,或使用者按了「做完了」。
  SessionEvent completeGuided() {
    if (!_acceptsInput || step.mode != StepMode.guided) return SessionEvent.none;
    return _complete();
  }

  /// 語音辨識不可用時,由使用者自己按一下算一次。
  SessionEvent countManually() {
    if (!_acceptsInput || step.mode != StepMode.speech) return SessionEvent.none;
    return _countRep();
  }

  /// 偵測不到(臉頰、舌頭的判定還不夠準)時,由使用者自己宣告做完。
  /// 跟 [skip] 不同,這算完成。
  SessionEvent completeManually() {
    if (!_acceptsInput) return SessionEvent.none;
    return _complete();
  }

  /// 跳過目前的動作。
  SessionEvent skip() {
    if (!_acceptsInput) return SessionEvent.none;
    skippedSteps++;
    stepComplete = true;
    return SessionEvent.stepDone;
  }

  /// 進到下一個動作;最後一個做完就結束整套。
  void advance() {
    if (_finished) return;
    if (_index + 1 >= steps.length) {
      _finished = true;
      return;
    }
    _index++;
    _enterStep();
  }

  SessionEvent _countRep() {
    reps++;
    if (reps >= step.reps) return _complete();
    return SessionEvent.rep;
  }

  SessionEvent _complete() {
    stepComplete = true;
    completedSteps++;
    return SessionEvent.stepDone;
  }
}
