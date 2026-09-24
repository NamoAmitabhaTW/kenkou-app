import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremode2026/core/media/screen_capture_notice.dart';

void main() {
  tearDown(ScreenCaptureNotice.debugReset);

  Future<void> tapStart(WidgetTester tester) async {
    await tester.tap(find.text('開始錄影'));
    await tester.pumpAndSettle();
  }

  Future<void> openPage(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScreenCaptureNotice.showIfNeeded(context),
            child: const Text('開始錄影'),
          ),
        ),
      ),
    ));
  }

  testWidgets('iOS 教長輩按左邊的「錄製螢幕」', (tester) async {
    await openPage(tester);
    await tapStart(tester);

    expect(find.text('請按左邊的\n「錄製螢幕」'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android 教長輩按右邊', (tester) async {
    await openPage(tester);
    await tapStart(tester);

    expect(find.text('請按右邊的\n「開始」'), findsOneWidget);
    expect(find.textContaining('錄製螢幕」'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('同一次開 app 只說明一次', (tester) async {
    await openPage(tester);
    await tapStart(tester);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    await tapStart(tester);
    expect(find.text('知道了'), findsNothing);
  });
}
