import 'package:flutter/material.dart';

import 'features/kenkou/ui/home_page.dart';
import 'games_home_page.dart';
import 'features/quiz/ui/home_page.dart';
import 'core/ui/app_theme.dart';

/// 三個給長輩用的口腔與認知訓練:健口操、快問快答、小遊戲。
class FutureModeApp extends StatelessWidget {
  const FutureModeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '健康動一動',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kBrandGreen,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

/// 底部三個分頁。每個分頁就是一個功能的首頁。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 刻意不用 IndexedStack:每個分頁的子頁面離開時都要真的被 dispose,
      // 相機和麥克風才會關掉。留在背景開著既耗電,也會互相搶麥克風。
      body: switch (_tab) {
        0 => const KenkouHomePage(),
        1 => const QuizHomePage(),
        _ => const GamesHomePage(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.face_retouching_natural_outlined),
            selectedIcon: Icon(Icons.face_retouching_natural),
            label: '健口操',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: '快問快答',
          ),
          NavigationDestination(
            icon: Icon(Icons.videogame_asset_outlined),
            selectedIcon: Icon(Icons.videogame_asset),
            label: '小遊戲',
          ),
        ],
      ),
    );
  }
}
