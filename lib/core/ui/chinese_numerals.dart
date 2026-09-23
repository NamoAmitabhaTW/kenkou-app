String chineseNumeral(int n) {
  const digits = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  if (n < 0) return '$n';
  if (n < 10) return digits[n];
  if (n > 99) return '$n';

  final tens = n ~/ 10;
  final ones = n % 10;
  final tensPart = tens == 1 ? '十' : '${digits[tens]}十';
  return ones == 0 ? tensPart : '$tensPart${digits[ones]}';
}
