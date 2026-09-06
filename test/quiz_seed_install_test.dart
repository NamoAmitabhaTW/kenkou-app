import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremode2026/features/quiz/data/quiz_store.dart';
import 'package:futuremode2026/features/quiz/domain/seed_questions.dart';

/// 預設題目真的走一次檔案系統。
///
/// 純資料的規則在 quiz_bank_test.dart 裡;這一支測的是「題目有沒有真的
/// 進到沙盒」—— 之前預設題目沒出現在手機上,壞的就是這一段。
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('quiz_seed_test');
    // QuizStore 走 path_provider 拿 Documents,測試裡換成暫存資料夾。
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => documents.path,
    );
  });

  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (documents.existsSync()) await documents.delete(recursive: true);
  });

  test('第一次讀題庫就把預設題目與素材放進沙盒', () async {
    final bank = await QuizStore().load();

    expect(bank.questions.map((q) => q.id),
        containsAll(kSeedQuestions.map((q) => q.id)));
    expect(bank.canPlay, isTrue);

    for (final question in kSeedQuestions) {
      for (final fileName in question.mediaFiles) {
        final file = File('${documents.path}/quiz/$fileName');
        expect(file.existsSync(), isTrue, reason: '$fileName 沒有複製進沙盒');
        expect(file.lengthSync(), greaterThan(0), reason: '$fileName 是空的');
      }
    }
  });

  test('題庫寫回檔案,重開 app 不會再補一次', () async {
    await QuizStore().load();
    final again = await QuizStore().load();

    expect(again.seededVersion, kSeedVersion);
    expect(again.missingSeeds(), isEmpty);
    expect(again.questions, hasLength(kSeedQuestions.length));
  });

  test('已經有自己題目的舊裝置,預設題目是補進去而不是蓋掉', () async {
    // 先做出一份「更新前」的題庫:有一題家人自己出的,沒有 seededVersion。
    final store = QuizStore();
    await store.deleteQuestion('nobody'); // 先讓沙盒資料夾建起來
    final bankFile = File('${documents.path}/quiz/bank.json');
    await bankFile.writeAsString(
      '{"version":1,"secondsPerQuestion":15,"questionsPerRound":5,'
      '"questions":[{"id":"q1","questionText":"家人自己出的題",'
      '"optionA":"甲","optionB":"乙","correctOption":1,"askedCount":3}]}',
    );

    final bank = await QuizStore().load();

    expect(bank.questions, hasLength(1 + kSeedQuestions.length));
    expect(bank.questions.first.id, 'q1');
    expect(bank.questions.first.askedCount, 3);
  });

  test('刪掉的預設題目不會下次開啟又冒出來', () async {
    await QuizStore().load();
    await QuizStore().deleteQuestion('seed1');

    final reopened = await QuizStore().load();

    expect(reopened.questions.map((q) => q.id), isNot(contains('seed1')));
    expect(File('${documents.path}/quiz/seed1_image.jpg').existsSync(), isFalse);
  });
}
