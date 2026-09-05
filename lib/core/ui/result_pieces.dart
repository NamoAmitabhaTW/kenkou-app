import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 「答對 **8** 題」這種一個大數字夾在句子中間的成績。
///
/// 數字放到 56pt 而句子留在 30pt —— 長輩掃一眼只會看到那個數字,
/// 這正是我們希望他記住的東西。
class ScoreHeadline extends StatelessWidget {
  const ScoreHeadline({
    super.key,
    required this.prefix,
    required this.value,
    required this.suffix,
  });

  final String prefix;
  final int value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
            fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: '$value',
            style: const TextStyle(fontSize: 56, color: kAccentGreen),
          ),
          TextSpan(text: suffix),
        ],
      ),
    );
  }
}

/// 影片還在合成 / 已存好 / 沒錄到,三種狀態的那一行小字。
///
/// 三種都要講出來。沒錄到卻不說,使用者只會看到一顆按了沒有影片的分享鍵,
/// 搞不清楚是自己按錯還是壞掉。
class VideoStatusLine extends StatelessWidget {
  const VideoStatusLine({
    super.key,
    required this.saving,
    required this.videoPath,
    required this.savedText,
  });

  final bool saving;
  final String? videoPath;

  /// 存好之後要說的話,例如「答題影片已存到「影片記錄」」。
  final String savedText;

  @override
  Widget build(BuildContext context) {
    // 還在合成時什麼都不說 —— 那句話只會讓人以為要等它跑完才能離開。
    if (saving) return const SizedBox.shrink();
    final text = videoPath != null ? savedText : '這次沒有錄到影片';

    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 20, color: Colors.white54),
    );
  }
}

/// 結算畫面的分享鍵。合成中會轉圈圈並且按不下去。
class ShareResultButton extends StatelessWidget {
  const ShareResultButton({
    super.key,
    required this.busy,
    required this.label,
    required this.onPressed,
  });

  /// 影片還在合成、或獎狀還在畫。按下去也沒東西可分享,所以擋著。
  final bool busy;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: kBigButtonStyle,
        icon: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5))
            : const Icon(Icons.ios_share, size: 26),
        label: Text(label,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// 「今天的我也健康,分享這分健康的喜悅!」—— 兩個結算畫面共用的收尾。
class ShareEncouragement extends StatelessWidget {
  const ShareEncouragement({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      '今天的我也健康,分享這分健康的喜悅!',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 17, color: Colors.white60, height: 1.5),
    );
  }
}

/// 結算畫面底部的「回首頁」。
class BackHomeButton extends StatelessWidget {
  const BackHomeButton({super.key, this.label = '回首頁'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(64)),
      child: Text(label,
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}
