import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremode2026/features/pacman/domain/maze.dart';
import 'package:futuremode2026/features/pacman/ui/game_page.dart';
import 'package:futuremode2026/core/game_settings.dart';

void main() {
  Future<void> pumpFor(WidgetTester tester, double seconds) async {
    const frame = Duration(milliseconds: 16);
    for (var i = 0; i < (seconds * 1000 / frame.inMilliseconds).ceil(); i++) {
      await tester.pump(frame);
    }
  }

  Future<void> boot(WidgetTester tester, {int gameSeconds = 30}) async {
    await tester.pumpWidget(MaterialApp(
      home: PacmanGamePage(settings: GameSettings(gameSeconds: gameSeconds)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('倒數完會自己開始,不會停在「3」', (tester) async {
    await boot(tester);
    expect(find.text('要開始囉！'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await pumpFor(tester, 1.1);
    expect(find.text('2'), findsOneWidget, reason: '倒數要真的在動');

    await pumpFor(tester, 2.2);
    expect(find.text('要開始囉！'), findsNothing, reason: '倒數完就直接開始');
  });

  testWidgets('開場倒數的時候,遊戲計時還不能開始扣', (tester) async {
    await boot(tester);
    expect(find.text('30'), findsOneWidget);
    await pumpFor(tester, 2.0);
    expect(find.text('要開始囉！'), findsOneWidget);
    expect(find.text('30'), findsOneWidget, reason: '還沒開始玩就不該扣秒數');
  });

  testWidgets('開始之後倒數計時會往下跑', (tester) async {
    await boot(tester);
    await pumpFor(tester, 3.1);
    expect(find.text('30'), findsOneWidget);
    await pumpFor(tester, 2.0);
    expect(find.text('28'), findsOneWidget);
  });

  testWidgets('時間到會跳出結算', (tester) async {
    await boot(tester, gameSeconds: 10);
    await pumpFor(tester, 3.1 + 10.2);
    expect(find.text('時間到!'), findsOneWidget);
    expect(find.text('再玩一次'), findsOneWidget);
  });

  testWidgets('窄螢幕上四個方向的提示都在,而且沒有被擠爆', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await boot(tester);
    for (final direction in MoveDirection.values) {
      expect(find.text(direction.word), findsOneWidget);
      expect(find.text(direction.short), findsOneWidget);
    }
    expect(tester.takeException(), isNull, reason: '排版不能溢出');

    for (final direction in MoveDirection.values) {
      final box = tester.getRect(find.text(direction.short));
      expect(box.right, lessThanOrEqualTo(390),
          reason: '${direction.short} 被切掉了');
      expect(box.left, greaterThanOrEqualTo(0));
    }
  });
}
