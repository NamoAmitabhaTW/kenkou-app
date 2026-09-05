import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:futuremode2026/features/quiz/domain/question.dart';
import 'package:futuremode2026/features/quiz/domain/bank.dart';
import 'package:futuremode2026/core/media/recording_store.dart';

void main() {
  /// 可以出題的一題要湊齊:題目本體(圖或文字)加兩個選項。
  QuizQuestion q(String id, {int asked = 0, bool complete = true}) =>
      QuizQuestion(
        id: id,
        questionText: complete ? '$id 的題目' : '',
        optionA: complete ? '$id-甲' : '',
        optionB: complete ? '$id-乙' : '',
        askedCount: asked,
      );

  QuizBank bankOf(int n, {int round = 5}) => QuizBank(
        questions: [for (var i = 0; i < n; i++) q('q$i')],
        questionsPerRound: round,
      );

  group('抽題', () {
    test('抽出設定的題數,而且不重複', () {
      final round = bankOf(10, round: 5).drawRound(random: Random(1));

      expect(round, hasLength(5));
      expect(round.map((e) => e.id).toSet(), hasLength(5));
    });

    test('題庫不夠時有幾題出幾題', () {
      final bank = bankOf(3, round: 5);

      expect(bank.roundSize, 3);
      expect(bank.drawRound(random: Random(1)), hasLength(3));
    });

    test('沒填完的題目不會被抽到', () {
      final bank = QuizBank(
        questions: [q('a'), q('b', complete: false), q('c')],
        questionsPerRound: 5,
      );

      // drawRound 會洗牌,所以比對集合而不是順序。
      expect(bank.drawRound(random: Random(1)).map((e) => e.id).toSet(),
          {'a', 'c'});
    });

    test('出過最少次的優先被抽中', () {
      final bank = QuizBank(
        questions: [
          q('熱門', asked: 9),
          q('冷門甲', asked: 0),
          q('冷門乙', asked: 0),
        ],
        questionsPerRound: 2,
      );

      final round = bank.drawRound(random: Random(7));

      expect(round.map((e) => e.id).toSet(), {'冷門甲', '冷門乙'});
    });

    // 這條是整個演算法的重點:純隨機會讓某幾題長期抽不到。
    test('連續出很多輪之後,任兩題的出題次數差不超過 1', () {
      var bank = bankOf(7, round: 3);
      final rng = Random(42);

      for (var i = 0; i < 50; i++) {
        final round = bank.drawRound(random: rng);
        bank = bank.markAsked([for (final e in round) e.id]);
      }

      final counts = [for (final e in bank.questions) e.askedCount];
      expect(counts.reduce(max) - counts.reduce(min), lessThanOrEqualTo(1));
      expect(counts.reduce((a, b) => a + b), 50 * 3);
    });

    test('同一批題目每輪的順序不會固定', () {
      final bank = bankOf(4, round: 4);
      final rng = Random(3);

      final orders = {
        for (var i = 0; i < 12; i++)
          bank.drawRound(random: rng).map((e) => e.id).join(),
      };

      expect(orders.length, greaterThan(1));
    });

    test('空題庫抽出空的一輪', () {
      expect(QuizBank.empty().drawRound(random: Random(1)), isEmpty);
      expect(QuizBank.empty().canPlay, isFalse);
    });
  });

  group('題庫', () {
    test('存檔會寫入格式版本,不認得的版本會被擋下來', () {
      final encoded =
          jsonDecode(bankOf(1).encode()) as Map<String, Object?>;
      expect(encoded['version'], kBankSchemaVersion);

      // 未來改格式時,這裡就是加升級分支的地方;在那之前寧可讀不到
      // 也不要拿舊欄位硬解出一份錯的題庫。
      expect(
        () => QuizBank.fromJson({...encoded, 'version': 99}),
        throwsFormatException,
      );
      expect(
        () => QuizBank.fromJson({'questions': []}),
        throwsFormatException,
      );
    });

    test('編碼再解碼會拿回一樣的內容', () {
      final bank = QuizBank(
        questions: [q('a', asked: 3), q('b')],
        secondsPerQuestion: 20,
        questionsPerRound: 8,
      );

      final restored = QuizBank.decode(bank.encode());

      expect(restored.questions.map((e) => e.id), ['a', 'b']);
      expect(restored.questions.first.askedCount, 3);
      expect(restored.secondsPerQuestion, 20);
      expect(restored.questionsPerRound, 8);
    });

    test('markAsked 只加到出過的那幾題', () {
      final bank = bankOf(3).markAsked(['q0', 'q2']);

      expect([for (final e in bank.questions) e.askedCount], [1, 0, 1]);
    });

    test('刪題會從清單消失', () {
      expect(bankOf(3).removing('q1').questions.map((e) => e.id), ['q0', 'q2']);
    });

    test('mediaFiles 只收實際有引用到的檔名', () {
      const question = QuizQuestion(id: 'x', imageFile: 'x.jpg');
      expect(question.mediaFiles, ['x.jpg']);
    });
  });

  group('可以出題的條件', () {
    const base = QuizQuestion(
      id: 'x',
      questionText: '這是題目',
      optionA: '甲',
      optionB: '乙',
    );

    test('題目本體加兩個選項就算完成', () {
      expect(base.isComplete, isTrue);
    });

    test('錄音是選配,沒錄也能出題', () {
      expect(base.hasAudio, isFalse);
      expect(base.isComplete, isTrue);
      expect(base.copyWith(audioFile: 'x.m4a').isComplete, isTrue);
    });

    test('圖片題和文字題二選一,有一個就算有題目本體', () {
      const imageOnly = QuizQuestion(
        id: 'y',
        imageFile: 'y.jpg',
        optionA: '甲',
        optionB: '乙',
      );

      expect(imageOnly.hasPrompt, isTrue);
      expect(imageOnly.isComplete, isTrue);
      expect(base.copyWith(questionText: '').isComplete, isFalse);
    });

    test('少一個選項不能出題', () {
      expect(base.copyWith(optionB: '  ').isComplete, isFalse);
    });
  });

  group('SessionRecording', () {
    test('編碼再解碼會拿回一樣的內容', () {
      final recording = SessionRecording(
        fileName: 'quiz_1.mp4',
        recordedAt: DateTime(2026, 9, 5, 10, 30),
        correctCount: 4,
        total: 5,
      );

      final restored = SessionRecording.fromJson(
          jsonDecode(jsonEncode(recording.toJson())) as Map<String, Object?>);

      expect(restored.fileName, 'quiz_1.mp4');
      expect(restored.dateLabel, '2026/09/05 10:30');
      expect(restored.scoreLabel, '答對 4 / 5 題');
    });
  });
}
