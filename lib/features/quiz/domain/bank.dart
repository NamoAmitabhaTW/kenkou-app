import 'dart:convert';
import 'dart:math';

import 'question.dart';
import 'seed_questions.dart';

const kBankSchemaVersion = 1;

const kDefaultQuestionsPerRound = 5;
const kMinQuestionsPerRound = 1;
const kMaxQuestionsPerRound = 30;

const kDefaultSecondsPerQuestion = 15;

const kMinSecondsPerQuestion = 5;
const kMaxSecondsPerQuestion = 120;

class QuizBank {
  const QuizBank({
    required this.questions,
    this.secondsPerQuestion = kDefaultSecondsPerQuestion,
    this.questionsPerRound = kDefaultQuestionsPerRound,
    this.seededVersion = 0,
  });

  final List<QuizQuestion> questions;
  final int secondsPerQuestion;
  final int questionsPerRound;

  final int seededVersion;

  factory QuizBank.empty() => const QuizBank(questions: []);

  bool get isEmpty => questions.isEmpty;

  List<QuizQuestion> get playable =>
      [for (final q in questions) if (q.isComplete) q];

  bool get canPlay => playable.isNotEmpty;

  int get roundSize => min(questionsPerRound, playable.length);

  List<QuizQuestion> drawRound({Random? random, DateTime? now}) {
    final rng = random ?? Random();
    final today = now ?? DateTime.now();
    final pool = playable;
    if (pool.isEmpty) return const [];

    final keyed = [for (final q in pool) (q, rng.nextDouble())];
    keyed.sort((a, b) {
      final byCount = a.$1.askedCount.compareTo(b.$1.askedCount);
      return byCount != 0 ? byCount : a.$2.compareTo(b.$2);
    });

    final picked = [for (final e in keyed.take(roundSize)) e.$1];

    picked.shuffle(rng);

    return [for (final q in picked) q.resolved(now: today, random: rng)];
  }

  QuizBank adding(QuizQuestion question) =>
      _copy(questions: [...questions, question]);

  QuizBank replacing(QuizQuestion question) => _copy(
        questions: [
          for (final q in questions) q.id == question.id ? question : q,
        ],
      );

  QuizBank removing(String id) =>
      _copy(questions: [for (final q in questions) if (q.id != id) q]);

  QuizBank markAsked(Iterable<String> ids) {
    final asked = ids.toSet();
    return _copy(
      questions: [
        for (final q in questions)
          asked.contains(q.id) ? q.copyWith(askedCount: q.askedCount + 1) : q,
      ],
    );
  }

  QuizBank withSeconds(int seconds) => _copy(secondsPerQuestion: seconds);

  QuizBank withRoundSize(int count) => _copy(questionsPerRound: count);

  List<QuizQuestion> missingSeeds() {
    if (seededVersion >= kSeedVersion) return const [];
    final existing = {for (final q in questions) q.id};
    return [for (final q in kSeedQuestions) if (!existing.contains(q.id)) q];
  }

  QuizBank withSeeds(List<QuizQuestion> seeds) => _copy(
        questions: [...questions, ...seeds],
        seededVersion: kSeedVersion,
      );

  QuizBank _copy({
    List<QuizQuestion>? questions,
    int? secondsPerQuestion,
    int? questionsPerRound,
    int? seededVersion,
  }) =>
      QuizBank(
        questions: questions ?? this.questions,
        secondsPerQuestion: secondsPerQuestion ?? this.secondsPerQuestion,
        questionsPerRound: questionsPerRound ?? this.questionsPerRound,
        seededVersion: seededVersion ?? this.seededVersion,
      );

  String encode() => jsonEncode({
        'version': kBankSchemaVersion,
        'secondsPerQuestion': secondsPerQuestion,
        'questionsPerRound': questionsPerRound,
        'seededVersion': seededVersion,
        'questions': questions.map((q) => q.toJson()).toList(),
      });

  factory QuizBank.decode(String source) =>
      QuizBank.fromJson(jsonDecode(source) as Map<String, Object?>);

  factory QuizBank.fromJson(Map<String, Object?> json) {
    final version = (json['version'] as num?)?.toInt();
    if (version != kBankSchemaVersion) {
      throw FormatException('不認得的題庫格式版本:$version');
    }

    final raw = (json['questions'] as List?) ?? const [];
    return QuizBank(
      questions: [
        for (final item in raw) QuizQuestion.fromJson(item as Map<String, Object?>),
      ],
      secondsPerQuestion: (json['secondsPerQuestion'] as num?)?.toInt() ??
          kDefaultSecondsPerQuestion,
      questionsPerRound: (json['questionsPerRound'] as num?)?.toInt() ??
          kDefaultQuestionsPerRound,
      seededVersion: (json['seededVersion'] as num?)?.toInt() ?? 0,
    );
  }

}
