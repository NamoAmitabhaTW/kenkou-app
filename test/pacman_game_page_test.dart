import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremode2026/features/pacman/domain/maze.dart';
import 'package:futuremode2026/features/pacman/ui/game_page.dart';
import 'package:futuremode2026/core/game_settings.dart';

void main() {
  // 一格一格推,不能用 pumpAndSettle:ticker 永遠不會停,pumpAndSettle 會卡死。
  // 也不能用一次 pump(4 秒):那只有一格畫面,而 dt 有上限,時間只會走 50ms。
  Future<void> pumpFor(WidgetTester tester, double seconds) async {
    const frame = Duration(milliseconds: 16);
    for (var i = 0; i < (seconds * 1000 / frame.inMilliseconds).ceil(); i++) {
      await tester.pump(frame);
    }
  }

  // 語音辨識在測試環境載不起來(沒有原生 sherpa),頁面會走「語音失敗」那條路
  // 照樣把遊戲跑完 —— 這正好也順便驗到那條退路是通的。
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
    await pumpFor(tester, 2.0); // 還在開場倒數
    expect(find.text('要開始囉！'), findsOneWidget);
    expect(find.text('30'), findsOneWidget, reason: '還沒開始玩就不該扣秒數');
  });

  testWidgets('開始之後倒數計時會往下跑', (tester) async {
    await boot(tester);
    await pumpFor(tester, 3.1); // 撐過開場倒數
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

  // 測試預設的畫布是 800x600,比手機寬得多,排版擠不擠看不出來。
  // 這裡照 iPhone 的邏輯尺寸來,提示排成兩欄時就是在這個寬度被切掉的。
  testWidgets('窄螢幕上四個方向的提示都在,而且沒有被擠爆', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await boot(tester);
    for (final direction in MoveDirection.values) {
      expect(find.text(direction.word), findsOneWidget);
      expect(find.text(direction.short), findsOneWidget);
    }
    expect(tester.takeException(), isNull, reason: '排版不能溢出');

    // 提示要真的完整落在畫面裡,不是被畫到螢幕外面。
    for (final direction in MoveDirection.values) {
      final box = tester.getRect(find.text(direction.short));
      expect(box.right, lessThanOrEqualTo(390),
          reason: '${direction.short} 被切掉了');
      expect(box.left, greaterThanOrEqualTo(0));
    }
  });
}
