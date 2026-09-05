import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'recording_store.dart';

/// 過往答題影片列表。
class RecordingGalleryPage extends StatefulWidget {
  const RecordingGalleryPage({super.key});

  @override
  State<RecordingGalleryPage> createState() => _RecordingGalleryPageState();
}

class _RecordingGalleryPageState extends State<RecordingGalleryPage> {
  final _store = RecordingStore();

  List<SessionRecording>? _recordings;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final recordings = await _store.load();
    if (mounted) setState(() => _recordings = recordings);
  }

  Future<void> _play(SessionRecording recording) async {
    final path = await _store.resolve(recording.fileName);
    if (!mounted) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _PlayerPage(path: path, title: recording.dateLabel),
      ),
    );
  }

  Future<void> _share(SessionRecording recording) async {
    final path = await _store.resolve(recording.fileName);
    await SharePlus.instance.share(
      ShareParams(
        text: recording.shareText,
        files: [XFile(path)],
      ),
    );
  }

  Future<void> _confirmDelete(SessionRecording recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除這段影片?', style: TextStyle(fontSize: 22)),
        content: Text('${recording.dateLabel} 的紀錄,刪除後無法復原。',
            style: const TextStyle(fontSize: 17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('刪除', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _store.delete(recording);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final recordings = _recordings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('影片記錄',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      ),
      body: switch (recordings) {
        null => const Center(child: CircularProgressIndicator()),
        [] => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                '還沒有影片\n做完一輪健口操或快問快答就會出現在這裡',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, height: 1.6),
              ),
            ),
          ),
        _ => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: recordings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _tile(recordings[index]),
          ),
      },
    );
  }

  Widget _tile(SessionRecording recording) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Icon(
          recording.kind == RecordingKind.kenkou
              ? Icons.face_retouching_natural
              : Icons.play_circle_fill,
          size: 44,
        ),
        title: Text(recording.dateLabel,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        subtitle:
            Text(recording.scoreLabel, style: const TextStyle(fontSize: 16)),
        onTap: () => _play(recording),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 26),
          onSelected: (value) {
            if (value == 'share') _share(recording);
            if (value == 'delete') _confirmDelete(recording);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'share', child: Text('分享', style: TextStyle(fontSize: 18))),
            PopupMenuItem(value: 'delete', child: Text('刪除', style: TextStyle(fontSize: 18))),
          ],
        ),
      ),
    );
  }
}

class _PlayerPage extends StatefulWidget {
  const _PlayerPage({required this.path, required this.title});

  final String path;
  final String title;

  @override
  State<_PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<_PlayerPage> {
  late final VideoPlayerController _controller =
      VideoPlayerController.file(File(widget.path));

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title, style: const TextStyle(fontSize: 18)),
      ),
      body: Center(
        child: _ready
            ? GestureDetector(
                onTap: () => setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                }),
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller),
                      if (!_controller.value.isPlaying)
                        const Icon(Icons.play_arrow, size: 80, color: Colors.white70),
                    ],
                  ),
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
