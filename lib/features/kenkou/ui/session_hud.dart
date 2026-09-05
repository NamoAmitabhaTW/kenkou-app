import 'package:face_mesh/face_mesh.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/overlays.dart';
import '../domain/exercise_program.dart';
import '../domain/face_geometry.dart';
import '../domain/mouth_shape.dart';
import '../domain/session_runner.dart';
import '../domain/settings.dart';

/// 疊在相機畫面上的所有文字與控制項。
///
/// 這裡沒有任何狀態,也沒有任何判定邏輯 —— 全部由 [KenkouSessionPage] 傳進來。
/// 「現在該顯示什麼」讀這個檔案,「什麼時候算做對」讀 `session_runner.dart`。
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
    required this.hint,
    required this.guidedRemaining,
    required this.lastHeard,
    required this.lastHeardDebug,
    required this.onExit,
    required this.onSkip,
    required this.onCountManually,
    required this.onCompleteGuided,
  });

  final KenkouSession session;
  final KenkouSettings settings;

  /// 目前的動作;還在準備 / 校正時是 null,那時候只顯示上方那一條。
  final ExerciseStep? step;

  final FaceFrame frame;
  final MouthShapeClassifier classifier;
  final LipsClosedDetector lips;
  final double targetScore;
  final bool isRecording;

  /// 語音辨識有沒有起來。沒有的話 パタカラ 要多給一顆 +1 鍵。
  final bool voiceReady;

  final String? hint;
  final int guidedRemaining;

  /// 除錯面板用。
  final String? lastHeard;
  final String lastHeardDebug;

  final VoidCallback onExit;
  final VoidCallback onSkip;
  final VoidCallback onCountManually;
  final VoidCallback onCompleteGuided;

  @override
  Widget build(BuildContext context) {
    final step = this.step;
    return Column(
      children: [
        _topBar(),
        if (step != null) _stepCard(step),
        const Spacer(),
        if (hint != null) _hintPill(),
        if (settings.showDebug && step != null) _debugPanel(),
        if (step != null) _bottomPanel(step),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '第 ${session.index + 1} / ${session.steps.length} 個動作',
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const Spacer(),
          if (isRecording) const RecordingBadge(),
        ],
      ),
    );
  }

  /// 動作名稱與說明。
  Widget _stepCard(ExerciseStep step) {
    final caution = step.caution;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.section,
              style: const TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 2),
          Text(step.title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(step.instruction,
              style: const TextStyle(
                  color: Colors.white, fontSize: 17, height: 1.4)),
          if (caution != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: Colors.orangeAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(caution,
                      style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 14)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _hintPill() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        hint!,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// 底下的計數與狀態,依動作類型長得不一樣。
  Widget _bottomPanel(ExerciseStep step) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          switch (step.mode) {
            StepMode.face => _facePanel(step),
            StepMode.speech => _speechPanel(step),
            StepMode.guided => _guidedPanel(step),
          },
          const SizedBox(height: 4),
          TextButton(
            onPressed: session.stepComplete ? null : onSkip,
            child: const Text('跳過這個動作',
                style: TextStyle(color: Colors.white54, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _counter(int done, int total) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$done',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w900,
                height: 1)),
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Text('/ $total 次',
              style: const TextStyle(color: Colors.white54, fontSize: 16)),
        ),
      ],
    );
  }

  /// 嘴型:靠相機分數計次的步驟。
  Widget _facePanel(ExerciseStep step) {
    final (poseLabel, poseColor) = switch (frame) {
      FaceFrame(hasFace: false) => ('沒有偵測到臉', Colors.redAccent),
      FaceFrame(isPoseUsable: false) => ('請正對鏡頭', Colors.orangeAccent),
      _ => ('偵測中', kAccentGreen),
    };

    final holdSeconds = (step.hold ?? settings.hold).inMilliseconds / 1000;
    final label = session.targetShape?.label ?? '';
    final stateText = switch (session.tracker?.state) {
      null || HoldState.idle => '做出「$label」',
      HoldState.entering => '再用力一點',
      HoldState.holding => '維持住…',
      HoldState.completed => '很好,放鬆',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: poseColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(poseLabel,
                style: TextStyle(
                    color: poseColor, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (holdSeconds >= 3)
              Text('每次保持 ${holdSeconds.toStringAsFixed(0)} 秒',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _counter(session.reps, step.reps),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stateText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: session.holdProgress,
                      minHeight: 10,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                          session.isHolding ? kAccentGreen : Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// パタカラ:靠麥克風聽音節計次的步驟。
  Widget _speechPanel(ExerciseStep step) {
    final label = step.syllable!.label;

    return Row(
      children: [
        _counter(session.reps, step.reps),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('請大聲說',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text(label,
                  style: const TextStyle(
                      color: kAccentGreen,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      height: 1.1)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(voiceReady ? Icons.mic : Icons.mic_off,
                      size: 16, color: Colors.white54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      voiceReady ? '一次一次清楚地說' : '語音辨識無法使用,說一次按一下',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 語音辨識起不來時的備援:自己按一下算一次,總比做不下去好。
        if (!voiceReady)
          FilledButton(
            onPressed: session.stepComplete ? null : onCountManually,
            style: FilledButton.styleFrom(
              minimumSize: const Size(72, 72),
              shape: const CircleBorder(),
            ),
            child: const Text('+1',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          ),
      ],
    );
  }

  /// 相機和麥克風都判不出來的步驟(舌頭頂臉頰):倒數計時引導。
  Widget _guidedPanel(ExerciseStep step) {
    final total = step.guidedSeconds;
    return Row(
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: total == 0 ? 0 : guidedRemaining / total,
                  strokeWidth: 6,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(kAccentGreen),
                ),
              ),
              Text('$guidedRemaining',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            onPressed: session.stepComplete ? null : onCompleteGuided,
            style: kBigButtonStyle.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(64)),
            ),
            icon: const Icon(Icons.check, size: 28),
            label: const Text('做完了,下一個',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  /// 調參數時真正在看的東西。設定裡的「顯示判定數值」打開才出現。
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
