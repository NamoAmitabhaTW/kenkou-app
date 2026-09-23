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
      builder: (context) => const _NoticeDialog(),
    );
  }
}

class _NoticeDialog extends StatelessWidget {
  const _NoticeDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.videocam_outlined, size: 44, color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                '請按左邊的\n「錄製螢幕」',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.4,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              const _AlertSketch(),
              const SizedBox(height: 20),
              Text(
                '影片只保存在您的手機裡,\n'
                '您可以觀看回憶！',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 16, height: 1.6, color: scheme.outline),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: kBigButtonStyle,
                child: const Text('知道了',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertSketch extends StatelessWidget {
  const _AlertSketch();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              Text(
                '要允許螢幕擷取嗎?',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.outline),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: scheme.primary, width: 2.5),
                      ),
                      child: Text(
                        '錄製螢幕',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        '不允許',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: scheme.outline),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.arrow_upward,
                            size: 22, color: scheme.primary),
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
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
