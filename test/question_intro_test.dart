import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremode2026/features/quiz/ui/question_intro.dart';
import 'package:futuremode2026/core/ui/chinese_numerals.dart';

void main() {
  group('中文數字', () {
    test('一位數', () {
      expect(chineseNumeral(1), '一');
      expect(chineseNumeral(5), '五');
      expect(chineseNumeral(9), '九');
    });

    test('十位數不說「一十」', () {
      expect(chineseNumeral(10), '十');
      expect(chineseNumeral(12), '十二');
      expect(chineseNumeral(19), '十九');
    });

    test('二十以上', () {
      expect(chineseNumeral(20), '二十');
      expect(chineseNumeral(30), '三十');
      expect(chineseNumeral(28), '二十八');
    });
  });

  group('題號動畫', () {
    // 這是一個真的當掉過的 bug:題號的中文數字以前是一個只有五個元素的
    // const list,而「每輪出題」可以設到 30 題 —— 家人把題數調到 6,
    // 第六題的題號動畫就會陣列越界。
    testWidgets('題數超過五題也畫得出題號', (tester) async {
      for (final index in [0, 4, 5, 11, 29]) {
        await tester.pumpWidget(MaterialApp(
          home: QuestionIntro(
            key: ValueKey(index),
            index: index,
            onComplete: () {},
          ),
        ));
        await tester.pump();

        expect(find.text('第'), findsOneWidget, reason: '第 ${index + 1} 題');
        expect(find.text('題'), findsOneWidget, reason: '第 ${index + 1} 題');
        expect(find.text(chineseNumeral(index + 1)), findsOneWidget,
            reason: '第 ${index + 1} 題');
      }
    });
  });
}
