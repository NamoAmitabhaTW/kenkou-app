import 'package:flutter/material.dart';

import 'core/ui/app_theme.dart';
import 'features/pacman/data/settings_store.dart';
import 'features/pacman/domain/settings.dart';
import 'features/pacman/ui/game_page.dart';
import 'features/pacman/ui/settings_sheet.dart';
import 'features/tetris/ui/tetris_page.dart';

/// 小遊戲首頁:選要玩哪一個,設定收在右上角的齒輪。
///
/// 放在組合層(跟 app.dart 同一層)而不是任何一個 feature 底下 —— 它同時要開
/// 吃金幣和俄羅斯方塊,擺進其中一邊就會讓那個 feature 認識另一個,架構測試
/// 「feature 之間不互相 import」會紅燈。串接多個 feature 本來就是這一層的事。
class GamesHomePage extends StatefulWidget {
  const GamesHomePage({super.key});

  @override
  State<GamesHomePage> createState() => _GamesHomePageState();
}

class _GamesHomePageState extends State<GamesHomePage> {
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

  Future<void> _startTetris() async {
    final settings = _settings;
    if (settings == null) return;
    // 語音靈敏度跟吃金幣共用一份設定 —— 同一顆模型、同一個刻度,
    // 兩個遊戲的手感才會一致。
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
          builder: (_) => TetrisPage(blankPenalty: settings.blankPenalty)),
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
    final settings = _settings;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '語音控制玩遊戲',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 40),
                    FilledButton(
                      onPressed: settings == null ? null : _start,
                      style: kBigButtonStyle.copyWith(
                        minimumSize:
                            const WidgetStatePropertyAll(Size.fromHeight(88)),
                      ),
                      child: const Text(
                        '小精靈吃金幣',
                        style:
                            TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: settings == null ? null : _startTetris,
                      style: kBigButtonStyle.copyWith(
                        minimumSize:
                            const WidgetStatePropertyAll(Size.fromHeight(88)),
                      ),
                      child: const Text(
                        '俄羅斯方塊',
                        style:
                            TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
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
