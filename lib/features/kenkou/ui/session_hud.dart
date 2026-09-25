import 'package:face_mesh/face_mesh.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/overlays.dart';
import '../domain/exercise_program.dart';
import '../domain/face_geometry.dart';
import '../domain/mouth_shape.dart';
import '../domain/session_runner.dart';
import '../domain/settings.dart';
import 'feedback.dart';
import 'feedback_badge.dart';

class SessionHud extends StatelessWidget {
  const SessionHud({
    super.key,
    required this.session,
    required this.settings,
    required this.step,
    required this.frame,
    required this.classifier,
    required this.lips,
    required this.targetScore,
    required this.isRecording,
    required this.voiceReady,
    required this.feedback,
    required this.countdown,
    required this.lastHeard,
    required this.lastHeardDebug,
    required this.onExit,
    required this.onSkip,
    required this.onCountManually,
  });

  final KenkouSession session;
  final KenkouSettings settings;

  final ExerciseStep? step;

  final FaceFrame frame;
  final MouthShapeClassifier classifier;
  final LipsClosedDetector lips;
  final double targetScore;
  final bool isRecording;

  final bool voiceReady;

  final FeedbackMessage? feedback;

  final int countdown;

  final String? lastHeard;
  final String lastHeardDebug;

  final VoidCallback onExit;
  final VoidCallback onSkip;
  final VoidCallback onCountManually;

  static const _showSecondsFrom = Duration(seconds: 5);

  @override
  Widget build(BuildContext context) {
    final step = this.step;
    final feedback = this.feedback;
    return Column(
      children: [
        _topBar(),
        if (step != null) _stepCard(step),
        if (step != null && feedback != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: FeedbackBadge(
                message: feedback, seconds: _holdSeconds(feedback)),
          ),
        const Spacer(),
        if (settings.showDebug && step != null) _debugPanel(),
        if (step != null) _actionBar(step),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onExit,
            iconSize: 28,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '第 ${session.index + 1} / ${session.steps.length} 個動作',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (isRecording) const RecordingBadge(),
        ],
      ),
    );
  }

  Widget _stepCard(ExerciseStep step) {
    final detail = session.resting ? null : step.detail;
    final caution = step.caution;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(step),
          const SizedBox(height: 6),
          _action(step),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, height: 1.35),
            ),
          ],
          if (_showsHoldBar(step)) ...[
            const SizedBox(height: 12),
            _holdBar(),
          ],
          if (caution != null) ...[
            const SizedBox(height: 12),
            _caution(caution),
          ],
        ],
      ),
    );
  }

  Widget _header(ExerciseStep step) {
    final round = _round(step);
    final ring = _ring(step);
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              step.section,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (round != null) ...[
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: FittedBox(fit: BoxFit.scaleDown, child: round),
          ),
        ],
        if (ring != null) ...[const SizedBox(width: 12), ring],
      ],
    );
  }

  Widget? _round(ExerciseStep step) {
    switch (step.mode) {
      case StepMode.speech:
        return _count('', session.reps, ' / ${step.reps} 次');
      case StepMode.face:
        final unit = step.shapes.length > 1 ? '組' : '次';
        return _count('第 ', session.currentRound, ' / ${step.reps} $unit');
      case StepMode.guided:
        if (step.reps <= 1) return null;
        return _count('第 ', session.currentRound, ' / ${step.reps} 組');
    }
  }

  Widget _count(String prefix, int value, String suffix) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: prefix),
        TextSpan(
          text: '$value',
          style: const TextStyle(
              color: kAccentGreen, fontSize: 36, fontWeight: FontWeight.w900),
        ),
        TextSpan(text: suffix),
      ]),
      style: const TextStyle(
          color: Colors.white70, fontSize: 22, fontWeight: FontWeight.w700),
    );
  }

  Widget? _ring(ExerciseStep step) {
    if (step.mode == StepMode.guided) {
      return _countdownRing(countdown, session.currentCue?.seconds ?? 0);
    }
    if (session.resting) {
      return _countdownRing(countdown, step.rest?.inSeconds ?? 0);
    }
    return null;
  }

  int? _holdSeconds(FeedbackMessage feedback) {
    final tracker = session.tracker;
    if (feedback.tone != FeedbackTone.hold ||
        tracker == null ||
        tracker.requiredHold < _showSecondsFrom) {
      return null;
    }
    return (tracker.remaining.inMilliseconds / 1000).ceil();
  }

  Widget _action(ExerciseStep step) {
    if (step.mode == StepMode.speech) return _speechAction(step);

    final shape = session.targetShape;
    final (String prompt, String? sound) = switch (step.mode) {
      StepMode.face when session.resting => ('嘴巴閉起來休息', null),
      StepMode.face => (shape?.prompt ?? '', shape?.sound),
      _ => (session.currentCue?.text ?? '', null),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt, style: _promptStyle),
        if (sound != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              sound,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 76,
                  fontWeight: FontWeight.w900,
                  height: 1.1),
            ),
          ),
      ],
    );
  }

  Widget _speechAction(ExerciseStep step) {
    return Row(
      children: [
        Expanded(
          child: Text(voiceReady ? '大聲說' : '說一次,再按 +1',
              style: _promptStyle),
        ),
        const SizedBox(width: 12),
        Text(
          step.syllable!.label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 112,
              fontWeight: FontWeight.w900,
              height: 1.05),
        ),
      ],
    );
  }

  static const _promptStyle = TextStyle(
      color: Colors.white,
      fontSize: 40,
      fontWeight: FontWeight.w900,
      height: 1.2);

  bool _showsHoldBar(ExerciseStep step) =>
      step.mode == StepMode.face &&
      !session.resting &&
      (session.tracker?.requiredHold ?? Duration.zero) < _showSecondsFrom;

  Widget _holdBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: session.holdProgress,
        minHeight: 12,
        backgroundColor: Colors.white12,
        valueColor: AlwaysStoppedAnimation(
            session.isHolding ? kAccentGreen : Colors.white70),
      ),
    );
  }

  Widget _countdownRing(int remaining, int total) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: total == 0 ? 0 : remaining / total,
              strokeWidth: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(kAccentGreen),
            ),
          ),
          Text('$remaining',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _caution(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.warning_amber_rounded,
              color: kCautionAmber, size: 24),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                color: kCautionAmber,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.3),
          ),
        ),
      ],
    );
  }

  Widget _actionBar(ExerciseStep step) {
    final manual = step.mode == StepMode.speech && !voiceReady;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: session.stepComplete ? null : onSkip,
              style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: const Text('跳過這個動作',
                  style: TextStyle(color: Colors.white70, fontSize: 18)),
            ),
          ),
          if (manual) ...[
            const SizedBox(width: 12),
            FilledButton(
              onPressed: session.stepComplete ? null : onCountManually,
              style: FilledButton.styleFrom(
                minimumSize: const Size(84, 84),
                shape: const CircleBorder(),
              ),
              child: const Text('+1',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _debugPanel() {
    final detected = classifier.classify(frame);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '判定 ${detected.shape.label} '
        '${detected.confidence.toStringAsFixed(2)}   '
        '目標分數 ${targetScore.toStringAsFixed(2)} / 門檻 ${settings.enterThreshold}\n'
        'width ${frame.mouthWidthRatio.toStringAsFixed(3)}  '
        'open ${frame.mouthOpenRatio.toStringAsFixed(3)}  '
        'yaw ${frame.yaw.toStringAsFixed(2)}  roll ${frame.rollDegrees.toStringAsFixed(0)}°  '
        '閉唇門檻 ${lips.threshold.toStringAsFixed(3)}'
        '${frame.hasExtendedContour ? '' : '\n(原生端沒送臉頰座標)'}'
        '${lastHeard == null ? '' : '\n聽到 $lastHeard   $lastHeardDebug'}',
        style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.5),
      ),
    );
  }
}
