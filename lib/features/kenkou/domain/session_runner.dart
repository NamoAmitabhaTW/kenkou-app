import '../../../core/voice/syllable.dart';
import 'exercise_program.dart';
import 'mouth_shape.dart';

enum SessionEvent {
  none,

  partial,

  rep,

  rest,

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

  bool resting = false;

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

  GuidedCue? get currentCue =>
      step.mode == StepMode.guided ? step.guidedCues[subIndex] : null;

  int get currentRound {
    final round = switch (step.mode) {
      StepMode.guided => subIndex ~/ step.cues.length + 1,
      _ => resting ? reps : reps + 1,
    };
    return round.clamp(1, step.reps);
  }

  bool get isHolding =>
      _tracker?.state == HoldState.holding ||
      _tracker?.state == HoldState.completed;

  double get holdProgress => _tracker?.progress ?? 0;

  void _enterStep() {
    reps = 0;
    subIndex = 0;
    stepComplete = false;
    resting = false;
    _lastCountedAt = null;
    _tracker = step.usesFaceScore
        ? HoldTracker(
            enterThreshold: enterThreshold,
            exitThreshold: enterThreshold - 0.10,
            requiredHold: step.hold ?? defaultHold,
            pauseOnDrop: step.pauseOnDrop,
          )
        : null;
  }

  bool get _inStep => !_finished && !stepComplete;

  bool get _acceptsInput => _inStep && !resting;

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
    if (step.shapes.length > 1) tracker.reset();
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
    if (subIndex + 1 < step.guidedCues.length) {
      subIndex++;
      return SessionEvent.partial;
    }
    return _complete();
  }

  SessionEvent finishRest() {
    if (!_inStep || !resting) return SessionEvent.none;
    resting = false;
    _tracker?.reset();
    if (reps >= step.reps) return _complete();
    return SessionEvent.none;
  }

  SessionEvent countManually() {
    if (!_acceptsInput || step.mode != StepMode.speech) return SessionEvent.none;
    return _countRep();
  }

  SessionEvent completeManually() {
    if (!_inStep) return SessionEvent.none;
    resting = false;
    return _complete();
  }

  SessionEvent skip() {
    if (!_inStep) return SessionEvent.none;
    resting = false;
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
    if (step.rest != null) {
      resting = true;
      return SessionEvent.rest;
    }
    if (reps >= step.reps) return _complete();
    return SessionEvent.rep;
  }

  SessionEvent _complete() {
    stepComplete = true;
    completedSteps++;
    return SessionEvent.stepDone;
  }
}
