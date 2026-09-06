import 'dart:math';

/// 選項與正解要在**出題當下**才算得出來的題目。
///
/// 一般題目的答案寫死在題庫裡,「今天星期幾」這種不行 —— 存下來的
/// 答案隔天就變成錯的。這種題目在題庫裡只記「要問什麼」,選項與正解
/// 每次抽到時重新產生一組。
enum QuizAutoQuestion {
  /// 今天星期幾。
  weekday;

  /// 題庫清單上代替選項顯示的說明 —— 這一題的選項在清單上還不存在。
  String get label => switch (this) {
        QuizAutoQuestion.weekday => '星期幾(出題時自動產生)',
      };

  /// 產生這一次要用的兩個選項與正解。
  ///
  /// 正解放 A 還是放 B 是隨機的 —— 固定放同一邊的話,連玩兩輪就被記住
  /// 位置了,考的就不是「今天星期幾」而是「按哪一邊」。
  ({String optionA, String optionB, int correctOption}) generate(
    DateTime now,
    Random random,
  ) {
    final answer = _answer(now);
    final distractor = _distractor(now, random);

    // nextBool 決定正解落在哪一邊,兩個選項再照這個順序擺進去。
    final correctOption = random.nextBool() ? 1 : 2;
    return (
      optionA: correctOption == 1 ? answer : distractor,
      optionB: correctOption == 1 ? distractor : answer,
      correctOption: correctOption,
    );
  }

  String _answer(DateTime now) => switch (this) {
        QuizAutoQuestion.weekday => _weekdayNames[now.weekday - 1],
      };

  /// 錯的那個選項。挑的是「不是今天」的某一天,所以永遠跟正解不一樣。
  String _distractor(DateTime now, Random random) => switch (this) {
        QuizAutoQuestion.weekday => () {
            final others = [
              for (var day = 1; day <= 7; day++)
                if (day != now.weekday) _weekdayNames[day - 1],
            ];
            return others[random.nextInt(others.length)];
          }(),
      };

  /// 存進 JSON 的字串轉回列舉。認不得就當作沒有(普通題目)。
  static QuizAutoQuestion? byName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  /// [DateTime.weekday] 是 1(週一)到 7(週日)。
  static const _weekdayNames = [
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];
}
