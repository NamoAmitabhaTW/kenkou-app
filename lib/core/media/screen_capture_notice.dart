import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ui/app_theme.dart';

class ScreenCaptureNotice {
  static bool _shownThisLaunch = false;

  static Future<void> showIfNeeded(BuildContext context) async {
    if (_shownThisLaunch) return;
    _shownThisLaunch = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _NoticeDialog(
        defaultTargetPlatform == TargetPlatform.android ? _android : _ios,
      ),
    );
  }

  @visibleForTesting
  static void debugReset() => _shownThisLaunch = false;
}

class _Copy {
  const _Copy({
    required this.headline,
    required this.alertTitle,
    required this.leftButton,
    required this.rightButton,
    required this.pressRight,
    required this.footer,
  });

  final String headline;
  final String alertTitle;
  final String leftButton;
  final String rightButton;

  final bool pressRight;

  final String footer;
}

const _ios = _Copy(
  headline: '請按左邊的\n「錄製螢幕」',
  alertTitle: '要允許螢幕擷取嗎?',
  leftButton: '錄製螢幕',
  rightButton: '不允許',
  pressRight: false,
  footer: '影片只保存在您的手機裡,\n您可以觀看回憶！',
);

const _android = _Copy(
  headline: '請按右邊的\n「開始」',
  alertTitle: '要開始錄製螢幕嗎?',
  leftButton: '取消',
  rightButton: '開始',
  pressRight: true,
  footer: '密碼、付款的提醒不用擔心,\n影片只保存在您的手機裡。',
);

class _NoticeDialog extends StatelessWidget {
  const _NoticeDialog(this.copy);

  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.videocam_outlined,
                        size: 44, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      copy.headline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.4,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _AlertSketch(copy),
                    const SizedBox(height: 20),
                    Text(
                      copy.footer,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16, height: 1.6, color: scheme.outline),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: kBigButtonStyle,
              child: const Text('知道了',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertSketch extends StatelessWidget {
  const _AlertSketch(this.copy);

  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final pointer = Expanded(
      child: Column(
        children: [
          Icon(Icons.arrow_upward, size: 22, color: scheme.primary),
          Text(
            '按這個',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Text(
            copy.alertTitle,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: scheme.outline),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SketchButton(copy.leftButton,
                    highlighted: !copy.pressRight),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SketchButton(copy.rightButton,
                    highlighted: copy.pressRight),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: copy.pressRight
                ? [const Spacer(), const SizedBox(width: 10), pointer]
                : [pointer, const SizedBox(width: 10), const Spacer()],
          ),
        ],
      ),
    );
  }
}

class _SketchButton extends StatelessWidget {
  const _SketchButton(this.label, {required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
        border: highlighted
            ? Border.all(color: scheme.primary, width: 2.5)
            : null,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: highlighted
            ? TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              )
            : TextStyle(fontSize: 16, color: scheme.outline),
      ),
    );
  }
}
