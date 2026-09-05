/// 阿拉伯數字 → 中文數字。題號「第 十二 題」用。
///
/// 以前這裡是一個只有五個元素的 `const ['一'..'五']`,而「每輪出題」可以設到
/// 30 題 —— 家人一把題數調到 6,第六題就會陣列越界當掉。改成算的,
/// 範圍就跟著設定上限走,不會再有這種對不起來的事。
String chineseNumeral(int n) {
  const digits = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  if (n < 0) return '$n';
  if (n < 10) return digits[n];
  if (n > 99) return '$n';

  final tens = n ~/ 10;
  final ones = n % 10;
  // 十~十九 說「十二」不說「一十二」。
  final tensPart = tens == 1 ? '十' : '${digits[tens]}十';
  return ones == 0 ? tensPart : '$tensPart${digits[ones]}';
}
