import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/ui/result_pieces.dart';

/// 一輪答完的結算畫面。
class QuizResultView extends StatelessWidget {
  const QuizResultView({
    super.key,
    required this.correctCount,
    required this.total,
    required this.savingVideo,
    required this.videoPath,
  });

  final int correctCount;
  final int total;

  /// 影片還在背景合成。分享要等它做完,不然分享出去的會是沒有影片的純文字。
  final bool savingVideo;

  /// 合成好的影片;錄製失敗時是 null。
  final String? videoPath;

  Future<void> _share() async {
    final text = '今天的我也健康!快問快答答對了 $correctCount/$total 題 🎉';
    final path = videoPath;

    await SharePlus.instance.share(
      path == null
          ? ShareParams(text: text)
          : ShareParams(text: text, files: [XFile(path)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text('最終成績',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70)),
          const SizedBox(height: 24),
          const Text('恭喜你!',
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 12),
          ScoreHeadline(prefix: '答對 ', value: correctCount, suffix: ' 題'),
          const SizedBox(height: 20),
          VideoStatusLine(
            saving: savingVideo,
            videoPath: videoPath,
            savedText: '答題影片已存到「影片記錄」',
          ),
          const SizedBox(height: 24),
          ShareResultButton(
            busy: savingVideo,
            label: videoPath != null ? '分享影片' : '分享成績',
            onPressed: _share,
          ),
          const SizedBox(height: 16),
          const ShareEncouragement(),
          const SizedBox(height: 28),
          const BackHomeButton(label: '回到首頁'),
        ],
      ),
    );
  }
}
