import 'package:flutter/material.dart';

import 'features/kenkou/ui/home_page.dart';
import 'games_home_page.dart';
import 'features/quiz/ui/home_page.dart';
import 'core/ui/app_theme.dart';

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
