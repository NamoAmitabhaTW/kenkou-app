import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/debug_log.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/result_pieces.dart';
import 'certificate.dart';

class SessionResultView extends StatefulWidget {
  const SessionResultView({
    super.key,
    required this.completed,
    required this.total,
    required this.savingVideo,
    required this.videoPath,
  });

  final int completed;
  final int total;

  final bool savingVideo;

  final String? videoPath;

  @override
  State<SessionResultView> createState() => _SessionResultViewState();
}

class _SessionResultViewState extends State<SessionResultView> {
  bool _renderingCertificate = false;

  Future<void> _shareCertificate() async {
    setState(() => _renderingCertificate = true);
    try {
      final path = await Certificate.render(
        completed: widget.completed,
        total: widget.total,
        at: DateTime.now(),
        directory: await getTemporaryDirectory(),
      );
      await SharePlus.instance.share(
        ShareParams(
          text: '今天的我也健康!健口操做完 ${widget.completed} 個動作 🎉',
          files: [XFile(path, mimeType: 'image/png')],
        ),
      );
    } catch (e) {
      debugLog('KENKOU', '獎狀產生失敗:$e');
    } finally {
      if (mounted) setState(() => _renderingCertificate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.emoji_events, size: 72, color: kAccentGreen),
          const SizedBox(height: 16),
          const Text('全部做完了!',
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 12),
          ScoreHeadline(
            prefix: '完成 ',
            value: widget.completed,
            suffix: ' / ${widget.total} 個動作',
          ),
          const SizedBox(height: 28),
          ShareResultButton(
            busy: _renderingCertificate,
            label: '分享健口操成果',
            onPressed: _shareCertificate,
          ),
          const SizedBox(height: 20),
          VideoStatusLine(
            saving: widget.savingVideo,
            videoPath: widget.videoPath,
            savedText: '練習影片已存到「影片記錄」',
          ),
          const SizedBox(height: 28),
          const BackHomeButton(),
        ],
      ),
    );
  }
}
