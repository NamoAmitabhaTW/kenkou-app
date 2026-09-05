import 'package:flutter/material.dart';

import '../../../core/media/recording_gallery_page.dart';
import '../../../core/ui/app_theme.dart';
import 'session_page.dart';
import '../domain/settings.dart';
import '../data/settings_store.dart';
import 'settings_sheet.dart';

/// 健口操首頁:一顆「開始」,其他全部收在右上角的齒輪。
class KenkouHomePage extends StatefulWidget {
  const KenkouHomePage({super.key});

  @override
  State<KenkouHomePage> createState() => _KenkouHomePageState();
}

class _KenkouHomePageState extends State<KenkouHomePage> {
  final _store = KenkouSettingsStore();
  KenkouSettings? _settings;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final settings = await _store.load();
    if (mounted) setState(() => _settings = settings);
  }

  Future<void> _start() async {
    final settings = _settings;
    if (settings == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => KenkouSessionPage(settings: settings),
      ),
    );
  }

  Future<void> _openSettings() async {
    final settings = _settings;
    if (settings == null) return;

    final action = await showKenkouSettingsSheet(
      context,
      settings: settings,
      store: _store,
    );
    await _reload();
    if (action == null || !mounted) return;

    switch (action) {
      case KenkouMenuAction.recordings:
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const RecordingGalleryPage()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = _settings != null;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.face_retouching_natural, size: 96, color: scheme.primary),
                  const SizedBox(height: 20),
                  const Text(
                    '健口操',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 48),
                  FilledButton.icon(
                    onPressed: ready ? _start : null,
                    style: kBigButtonStyle.copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(80)),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 36),
                    label: const Text(
                      '開始',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 8,
              child: IconButton(
                onPressed: _openSettings,
                iconSize: 34,
                tooltip: '設定',
                icon: const Icon(Icons.settings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
