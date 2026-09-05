import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';
import 'game_page.dart';
import '../domain/maze.dart';
import 'maze_painter.dart';
import '../domain/settings.dart';
import '../data/settings_store.dart';
import 'settings_sheet.dart';
import 'voice_hint_row.dart';

/// 吃金幣首頁:一顆「開始遊戲」,設定收在右上角的齒輪。
class PacmanHomePage extends StatefulWidget {
  const PacmanHomePage({super.key});

  @override
  State<PacmanHomePage> createState() => _PacmanHomePageState();
}

class _PacmanHomePageState extends State<PacmanHomePage> {
  final _store = PacmanSettingsStore();
  PacmanSettings? _settings;

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
      MaterialPageRoute(builder: (_) => PacmanGamePage(settings: settings)),
    );
  }

  Future<void> _openSettings() async {
    final settings = _settings;
    if (settings == null) return;
    await showPacmanSettingsSheet(context, settings: settings, store: _store);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = _settings;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(
                    height: 84,
                    child: CustomPaint(painter: _TitlePainter()),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '小精靈吃金幣',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 24),
                  _VoiceGuide(scheme: scheme),
                  const SizedBox(height: 16),
                  Text(
                    settings == null
                        ? ''
                        : '限時 ${settings.gameSeconds} 秒,吃到越多金幣分數越高',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, color: scheme.outline),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: settings == null ? null : _start,
                    style: kBigButtonStyle.copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(80)),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 36),
                    label: const Text(
                      '開始遊戲',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
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

/// 四個方向各一列:念什麼字、往哪走。
///
/// 原本的文案是四句「語音控制:念「怕」,往上移動。」,排成表格之後
/// 「念的字」和「方向」對齊,長輩掃一眼就找得到,不用讀完整句。
class _VoiceGuide extends StatelessWidget {
  const _VoiceGuide({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.mic, size: 22, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                '語音控制',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final direction in MoveDirection.values)
            VoiceHintRow(direction: direction, scheme: scheme),
        ],
      ),
    );
  }
}

/// 首頁上方的小裝飾:一隻小精靈跟著三顆金幣。
class _TitlePainter extends CustomPainter {
  const _TitlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.height / 2;
    final center = Offset(size.width / 2 - radius * 1.6, size.height / 2);

    const half = 0.22 * math.pi;
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), half,
          2 * math.pi - 2 * half, false)
      ..close();
    canvas.drawPath(path, Paint()..color = kPacmanColor);

    final coin = Paint()..color = kCoinColor;
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        Offset(center.dx + radius * (0.9 + i * 0.85), center.dy),
        i == 3 ? radius * 0.26 : radius * 0.13,
        coin,
      );
    }
  }

  @override
  bool shouldRepaint(_TitlePainter oldDelegate) => false;
}
