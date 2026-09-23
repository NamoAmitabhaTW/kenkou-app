import '../../../core/voice/syllable.dart';
import 'exercise_program.dart';
import 'mouth_shape.dart';

enum SessionEvent {
  none,

  partial,

  rep,

  stepDone,
}

class KenkouSession {
  KenkouSession({
    required this.steps,
    required this.defaultHold,
    this.enterThreshold = 0.80,
  }) : assert(steps.isNotEmpty) {
    _enterStep();
  }

  final List<ExerciseStep> steps;

  final Duration defaultHold;
  final double enterThreshold;

  int _index = 0;
  bool _finished = false;

  int reps = 0;

  int subIndex = 0;

  bool stepComplete = false;

  int completedSteps = 0;
  int skippedSteps = 0;

  HoldTracker? _tracker;

  bool get isFinished => _finished;
  int get index => _index;
  ExerciseStep get step => steps[_index];
  HoldTracker? get tracker => _tracker;

  MouthShape? get targetShape =>
      step.mode == StepMode.face ? step.shapes[subIndex] : null;

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
            exitThreshold: enterThreshold - 0.10,
            requiredHold: step.hold ?? defaultHold,
          )
        : null;
  }

  bool get _acceptsInput => !_finished && !stepComplete;

  SessionEvent onFaceScore(double score) {
    final tracker = _tracker;
    if (!_acceptsInput || tracker == null) return SessionEvent.none;

    final before = tracker.completions;
    tracker.update(score);
    if (tracker.completions == before) return SessionEvent.none;

    subIndex++;
    if (step.mode == StepMode.face && subIndex < step.shapes.length) {
      tracker.reset();
      return SessionEvent.partial;
    }
    subIndex = 0;
    return _countRep();
  }

  static const repCooldown = Duration(milliseconds: 400);

  DateTime? _lastCountedAt;

  SessionEvent onSyllable(Syllable syllable, {required DateTime at}) {
    if (!_acceptsInput || step.mode != StepMode.speech) return SessionEvent.none;
    if (syllable != step.syllable) return SessionEvent.none;
    final last = _lastCountedAt;
    if (last != null && at.difference(last) < repCooldown) {
      return SessionEvent.none;
    }
    _lastCountedAt = at;
    return _countRep();
  }

  SessionEvent completeGuided() {
    if (!_acceptsInput || step.mode != StepMode.guided) return SessionEvent.none;
    return _complete();
  }

  SessionEvent countManually() {
    if (!_acceptsInput || step.mode != StepMode.speech) return SessionEvent.none;
    return _countRep();
  }

  SessionEvent completeManually() {
    if (!_acceptsInput) return SessionEvent.none;
    return _complete();
  }

  SessionEvent skip() {
    if (!_acceptsInput) return SessionEvent.none;
    skippedSteps++;
    stepComplete = true;
    return SessionEvent.stepDone;
  }

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
