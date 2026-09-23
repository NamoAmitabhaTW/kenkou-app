import 'dart:math';

enum QuizAutoQuestion {
  weekday;

  String get label => switch (this) {
        QuizAutoQuestion.weekday => '星期幾(出題時自動產生)',
      };

  ({String optionA, String optionB, int correctOption}) generate(
    DateTime now,
    Random random,
  ) {
    final answer = _answer(now);
    final distractor = _distractor(now, random);

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

  String _distractor(DateTime now, Random random) => switch (this) {
        QuizAutoQuestion.weekday => () {
            final others = [
              for (var day = 1; day <= 7; day++)
                if (day != now.weekday) _weekdayNames[day - 1],
            ];
            return others[random.nextInt(others.length)];
          }(),
      };

  static QuizAutoQuestion? byName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

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
