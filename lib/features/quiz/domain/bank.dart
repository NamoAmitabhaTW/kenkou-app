import 'dart:convert';
import 'dart:math';

import 'question.dart';
import 'seed_questions.dart';

/// `bank.json` 的格式版本。
///
/// 存這個欄位是為了讓「以後改資料結構」有個明確的下手處:讀到不認得的
/// 版本就當作讀不到,而不是拿舊欄位硬解出一份錯的題庫。真的要做升級時,
/// [QuizBank.fromJson] 就是加分支的地方。
///
/// 這是目前唯一為了相容性做的準備 —— 一個整數。不預先寫任何用不到的
/// 升級邏輯,那是等真的有第 2 版時才知道要怎麼寫的事。
const kBankSchemaVersion = 1;

/// 每輪出題數的預設值與範圍。
const kDefaultQuestionsPerRound = 5;
const kMinQuestionsPerRound = 1;
const kMaxQuestionsPerRound = 30;

/// 預設每題作答秒數。
const kDefaultSecondsPerQuestion = 15;

/// 每題作答秒數的上下限。太短長輩來不及開口,太長整輪會拖到失去節奏。
const kMinSecondsPerQuestion = 5;
const kMaxSecondsPerQuestion = 120;

/// 整個題庫:所有題目,加上每輪出幾題、每題幾秒。
///
/// 題目彼此獨立,沒有分組 —— 每次開始答題都從題庫裡抽。
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

  /// 這份題庫已經補到第幾版的預設題目。0 代表一題都還沒補過。
  ///
  /// 記在題庫裡而不是另外開一個旗標檔:補題目跟寫題庫是同一次寫入,
  /// 不會有「題目補進去了但旗標沒寫成功」的中間狀態。
  final int seededVersion;

  factory QuizBank.empty() => const QuizBank(questions: []);

  bool get isEmpty => questions.isEmpty;

  /// 兩個選項都填好、可以拿來出題的題目。
  List<QuizQuestion> get playable =>
      [for (final q in questions) if (q.isComplete) q];

  bool get canPlay => playable.isNotEmpty;

  /// 這一輪實際會出幾題。題庫不夠就有幾題出幾題。
  int get roundSize => min(questionsPerRound, playable.length);

  /// 抽出這一輪要出的題目,自動題的選項也一併產生好。
  ///
  /// 純隨機會讓某些題目長期抽不到,所以改成**依出題次數分層**:
  /// 先把出過最少次的題目排前面,同樣次數的彼此隨機,再取前 N 題。
  ///
  /// 這樣任兩題的出題次數永遠不會差超過 1 —— 全部題目都出過一輪,
  /// 才會有題目出到第二次。次數相同的順序是隨機的,所以每輪的組合
  /// 跟順序都還是新鮮的,不會變成固定循環。
  List<QuizQuestion> drawRound({Random? random, DateTime? now}) {
    final rng = random ?? Random();
    final today = now ?? DateTime.now();
    final pool = playable;
    if (pool.isEmpty) return const [];

    // 給每題一個隨機鍵當同層內的排序依據 —— Dart 的 sort 不保證穩定,
    // 不能先 shuffle 再排序就當作同層是隨機的。
    final keyed = [for (final q in pool) (q, rng.nextDouble())];
    keyed.sort((a, b) {
      final byCount = a.$1.askedCount.compareTo(b.$1.askedCount);
      return byCount != 0 ? byCount : a.$2.compareTo(b.$2);
    });

    final picked = [for (final e in keyed.take(roundSize)) e.$1];

    // 抽完再打散一次:上面是照出題次數排的,不洗牌的話出題順序
    // 會固定是「最少出過的排第一題」。
    picked.shuffle(rng);

    // 「今天星期幾」這種題目的選項在這裡才生出來,出題流程拿到的
    // 每一題都已經是填好選項與正解的普通題目。
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

  /// 一輪結束後把這些題目的出題次數加一。
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

  /// 還缺哪幾題預設題目。已經有的(或被家人刪掉之後又補過的)不再補,
  /// 所以刪掉的預設題目不會自己長回來 —— 補完就把 [seededVersion] 記上。
  List<QuizQuestion> missingSeeds() {
    if (seededVersion >= kSeedVersion) return const [];
    final existing = {for (final q in questions) q.id};
    return [for (final q in kSeedQuestions) if (!existing.contains(q.id)) q];
  }

  /// 補完預設題目之後把版本記上,下次開啟就不會再補一次。
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
      // 舊的存檔沒有這個欄位,當作 0 —— 一開啟就會把預設題目補上。
      // 多一個欄位不必動 [kBankSchemaVersion]:舊版程式讀到會忽略它,
      // 新版程式讀舊檔會拿到預設值,兩邊都不會解出一份錯的題庫。
      seededVersion: (json['seededVersion'] as num?)?.toInt() ?? 0,
    );
  }

}
