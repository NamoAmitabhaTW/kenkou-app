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

  /// 現在要做什麼。整個畫面只有這一塊在講這件事。
  ///
  /// 原本上下各一塊提示框:上面放名稱與說明、下面放次數與狀態。兩塊互相搶
  /// 注意力,而且長輩要在一公尺外看,兩邊的字都不夠大。合併成一塊之後只留
  /// 三件事 —— 標題、次數、現在該做什麼 —— 字全部放大。
  Widget _stepCard(ExerciseStep step) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
      ),
      child: switch (step.mode) {
        StepMode.face => _faceCard(step),
        StepMode.speech => _speechCard(step),
        StepMode.guided => _guidedCard(step),
      },
    );
  }

  Widget _title(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 52,
            fontWeight: FontWeight.w900,
            height: 1.1),
      );

  Widget _status(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w800,
            height: 1.2),
      );

  Widget _counter(int done, int total) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$done',
            style: const TextStyle(
                color: kAccentGreen,
                fontSize: 68,
                fontWeight: FontWeight.w900,
                height: 1)),
        Text(' / $total 次',
            style: const TextStyle(color: Colors.white70, fontSize: 28)),
      ],
    );
  }

  /// 嘴型:靠相機分數計次的步驟。
  Widget _faceCard(ExerciseStep step) {
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
        _title(step.title),
        const SizedBox(height: 10),
        _counter(session.reps, step.reps),
        const SizedBox(height: 10),
        _status(stateText),
        const SizedBox(height: 14),
        // 「維持住…」還要維持多久,只靠文字看不出來。
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: session.holdProgress,
            minHeight: 12,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(
                session.isHolding ? kAccentGreen : Colors.white70),
          ),
        ),
      ],
    );
  }

  /// 怕踏卡啦:靠麥克風聽音節計次的步驟。
  Widget _speechCard(ExerciseStep step) {
    final label = step.syllable!.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(step.title),
        const SizedBox(height: 10),
        _counter(session.reps, step.reps),
        const SizedBox(height: 10),
        _status(voiceReady ? '大聲說「$label」' : '說一次,按一下 +1'),
      ],
    );
  }

  /// 相機和麥克風都判不出來的步驟(舌頭頂臉頰):只有倒數計時引導。
  ///
  /// 倒數歸零就自動算做完,所以不需要「做完了」按鈕。
  Widget _guidedCard(ExerciseStep step) {
    // 標題跟倒數同一列,動作指示獨佔一整行 —— 指示字最長,擠在倒數圈旁邊會折行。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _title('舌壓訓練')),
            const SizedBox(width: 12),
            _countdownRing(step),
          ],
        ),
        const SizedBox(height: 10),
        _status(step.title),
      ],
    );
  }

  Widget _countdownRing(ExerciseStep step) {
    final total = step.guidedSeconds;
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: total == 0 ? 0 : guidedRemaining / total,
              strokeWidth: 7,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(kAccentGreen),
            ),
          ),
          Text('$guidedRemaining',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _hintPill() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        hint!,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// 畫面最下面的操作列。動作卡專心講「要做什麼」,按鈕放這裡才不會互相搶位置。
  Widget _actionBar(ExerciseStep step) {
    // 語音辨識起不來時的備援:自己按一下算一次,總比做不下去好。
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
