import 'package:flutter/material.dart';

import '../ui/app_theme.dart';

/// 螢幕錄影開始前的說明。
///
/// 系統的同意框長什麼樣、按鈕怎麼排、哪一顆是預設,全部由 iOS 決定,
/// app 連一個字都改不了 —— 而 Apple 刻意把「不允許」做成醒目的那顆。
/// 唯一能做的是在它出現之前,先用我們自己的畫面講清楚要按哪一邊。
class ScreenCaptureNotice {
  /// 每次開 app 只說明一次。
  ///
  /// 系統的同意框也是每次啟動才問一次,每輪答題都跳一次說明,
  /// 對天天在用的人只是干擾。
  static bool _shownThisLaunch = false;

  static Future<void> showIfNeeded(BuildContext context) async {
    if (_shownThisLaunch) return;
    _shownThisLaunch = true;

    await showDialog<void>(
      context: context,
      // 這頁的重點是「等一下要按左邊那顆」,滑掉就白講了。
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
                // 寫死斷行,不然會折成「錄製螢 / 幕」。
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
                // 寫死斷行位置,不要讓它自己折出「影 / 片。」這種收尾。
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

/// 系統同意框的示意圖。
///
/// 刻意畫成灰階的簡圖而不是擬真複製品 —— 目的是指出「左邊那顆」的位置,
/// 不是讓人以為系統框已經出現而搶著按。
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
