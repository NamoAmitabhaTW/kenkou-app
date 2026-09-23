import 'package:flutter/material.dart';

import 'app_theme.dart';

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

class VideoStatusLine extends StatelessWidget {
  const VideoStatusLine({
    super.key,
    required this.saving,
    required this.videoPath,
    required this.savedText,
  });

  final bool saving;
  final String? videoPath;

  final String savedText;

  @override
  Widget build(BuildContext context) {
    if (saving) return const SizedBox.shrink();
    final text = videoPath != null ? savedText : '這次沒有錄到影片';

    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 20, color: Colors.white54),
    );
  }
}

class ShareResultButton extends StatelessWidget {
  const ShareResultButton({
    super.key,
    required this.busy,
    required this.label,
    required this.onPressed,
  });

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
