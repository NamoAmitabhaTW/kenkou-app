import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';
import 'feedback.dart';

class FeedbackBadge extends StatelessWidget {
  const FeedbackBadge({super.key, required this.message, this.seconds});

  final FeedbackMessage message;

  final int? seconds;

  @override
  Widget build(BuildContext context) {
    final seconds = this.seconds;
    final (Color background, Color foreground, IconData? icon) =
        switch (message.tone) {
      FeedbackTone.hold => (
          kSuccessGreen,
          Colors.white,
          seconds == null ? Icons.thumb_up : null,
        ),
      FeedbackTone.nudge => (kCautionAmber, Colors.black87, null),
    };
    final textStyle = TextStyle(
        color: foreground,
        fontSize: 38,
        fontWeight: FontWeight.w900,
        height: 1.15);

    return TweenAnimationBuilder<double>(
      key: ValueKey(message),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: 0.7 + 0.3 * value,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: background.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.35), blurRadius: 14),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 36, color: foreground),
                const SizedBox(width: 10),
              ],
              Text(message.text, style: textStyle),
              if (seconds != null) ...[
                const SizedBox(width: 14),
                Text('$seconds',
                    style: textStyle.copyWith(fontSize: 60, height: 1.0)),
                Text(' 秒', style: textStyle),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
