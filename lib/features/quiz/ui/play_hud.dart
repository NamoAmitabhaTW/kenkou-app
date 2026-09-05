import 'dart:io';

import 'package:face_mesh/face_mesh.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/overlays.dart';
import '../domain/question.dart';
import 'play_page.dart' show QuizPhase;

/// 作答中的畫面:題目、鏡子、兩顆選項。
///
/// 這裡沒有任何狀態 —— 所有東西都由 [QuizPlayPage] 傳進來。答題規則在那邊,
/// 這邊只負責畫,兩者才不會攪在一起。
class QuizQuestionView extends StatelessWidget {
  const QuizQuestionView({
    super.key,
    required this.question,
    required this.index,
    required this.phase,
    required this.directory,
    required this.cameraReady,
    required this.isRecording,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.selected,
    required this.onAnswer,
  });

  final QuizQuestion question;
  final int index;
  final QuizPhase phase;

  /// 題目圖片所在的資料夾。還沒解析出來時是 null。
  final String? directory;

  final bool cameraReady;
  final bool isRecording;
  final int remainingSeconds;
  final int totalSeconds;

  /// 使用者選了哪一個;null = 還沒選,或逾時沒作答。
  final int? selected;

  final ValueChanged<int> onAnswer;

  bool get _isCorrect => selected == question.correctOption;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 12),
            Center(child: _promptBox()),
            const SizedBox(height: 12),
            Expanded(child: _cameraArea()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  _optionButton(1, question.optionA),
                  const SizedBox(height: 14),
                  _optionButton(2, question.optionB),
                ],
              ),
            ),
          ],
        ),
        if (isRecording)
          const Positioned(top: 12, right: 24, child: RecordingBadge()),
      ],
    );
  }

  /// 題目本體。圖片題和文字題共用同一個尺寸的方框,
  /// 版面不會因為題型不同而跳動。
  Widget _promptBox() {
    final fileName = question.imageFile;
    final hasImage = fileName != null && directory != null;

    return Container(
      width: 260,
      height: 200,
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.file(File('$directory/$fileName'), fit: BoxFit.cover)
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Center(
                child: Text(
                  question.hasText ? question.questionText : '第 ${index + 1} 題',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
    );
  }

  /// 圖片與選項之間的即時鏡像畫面。
  ///
  /// 臉會落在這塊區域的正中間,所以倒數和回饋一律靠邊放,
  /// 中間永遠留給使用者自己 —— 這也是錄影裡唯一值得留下來的東西。
  Widget _cameraArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cameraReady)
              const FaceMeshPreview()
            else
              const ColoredBox(color: kSurfaceDark),
            const ScrimGradient(
              topAlpha: 0.34,
              bottomAlpha: 0.34,
              stops: [0.0, 0.3, 0.85],
            ),
            if (phase == QuizPhase.answering)
              Positioned(top: 10, left: 10, child: _countdownBadge()),
            if (phase == QuizPhase.feedback)
              Positioned(left: 0, right: 0, bottom: 0, child: _feedbackBand()),
          ],
        ),
      ),
    );
  }

  /// 倒數。除了數字也畫一圈進度環 —— 長輩不必真的讀數字,
  /// 看環剩多少就知道還有多久。
  Widget _countdownBadge() {
    final urgent = remainingSeconds <= 5;
    final color = urgent ? kAlertRed : Colors.white;

    return Container(
      width: 66,
      height: 66,
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(
              value: totalSeconds == 0 ? 0 : remainingSeconds / totalSeconds,
              strokeWidth: 5,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '$remainingSeconds',
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  /// 答題回饋。做成貼齊底部的橫幅而不是全螢幕覆蓋層,臉才不會被蓋掉。
  Widget _feedbackBand() {
    final correct = _isCorrect;

    return TweenAnimationBuilder<double>(
      key: ValueKey('$index-$selected'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final t = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 40),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        color: (correct ? kSuccessGreen : kWrongRed).withValues(alpha: 0.92),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(correct ? Icons.thumb_up : Icons.lightbulb_outline,
                size: 34, color: Colors.white),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                correct ? '答對了' : '正確答案是 ${question.correctOption}',
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionButton(int number, String text) {
    final isCorrectOption = number == question.correctOption;
    final showingAnswer = phase == QuizPhase.feedback && !_isCorrect;

    // 答錯時只把正解那顆點亮,其餘壓暗 —— 視線自然被帶到正確選項上。
    final Color background;
    final Color foreground;
    if (showingAnswer && isCorrectOption) {
      background = kBrandGreen;
      foreground = Colors.white;
    } else if (showingAnswer) {
      background = kSurfaceDark;
      foreground = Colors.white24;
    } else {
      background = kSurfaceDarkRaised;
      foreground = Colors.white;
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed:
            phase == QuizPhase.answering ? () => onAnswer(number) : null,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          disabledBackgroundColor: background,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: showingAnswer && isCorrectOption
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Text('$number',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: foreground)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
