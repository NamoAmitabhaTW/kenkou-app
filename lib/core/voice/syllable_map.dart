/// 語音辨識吐出的字 → パタカラ 音節。
///
/// 純 Dart、不碰 Flutter,`tool/pataka_smoke.dart` 也直接用這一份。
/// 德文 ASR 吐出的字 → パタカラ 音節。
///
/// 德文模型的用處是 ラ:國語沒有 [ɾa],中文模型只會吐 `<unk>`,德文有 "ra"。
/// 它也會把連續的 pa 黏成 "paar",ta / ka 有時只吐一個 "t" / "k",這些都收成一個音節。
/// 比對前先轉小寫、去掉標點。
const kSyllableByGermanWord = <String, String>{
  'pa': 'pa', 'p': 'pa', 'ah': 'pa', 'pap': 'pa', 'papp': 'pa', 'paar': 'pa', 'pah': 'pa', 'par': 'pa', 'ba': 'pa', 'bah': 'pa', 'bar': 'pa', 'papa': 'pa',
  'ta': 'ta', 't': 'ta', 'tag': 'ta', 'tah': 'ta', 'tar': 'ta', 'da': 'ta', 'dah': 'ta', 'dar': 'ta', 'tata': 'ta',
  'ka': 'ka', 'k': 'ka', 'kah': 'ka', 'kar': 'ka', 'ga': 'ka', 'gah': 'ka', 'gar': 'ka', 'kaka': 'ka',
  'ra': 'la', 'l': 'la', 'na': 'la', 'rah': 'la', 'raa': 'la', 'rar': 'la', 'la': 'la', 'lah': 'la', 'rara': 'la',
};

/// 把德文模型的一個字對回音節;對不到回傳 null。
String? germanSyllable(String word) {
  final cleaned = word.toLowerCase().replaceAll(RegExp(r'[^a-zäöüß]'), '');
  if (cleaned.isEmpty) return null;
  return kSyllableByGermanWord[cleaned];
}

/// 增量解析的一筆結果:模型聽到的字 / 詞,對到的音節標籤,是不是 `<unk>`。
class ParsedSyllable {
  const ParsedSyllable(this.text, this.label, {this.unknown = false});
  final String text;
  final String label;
  final bool unknown;
}

/// 德文結果文字:用空白與標點切詞,從第 [seen] 個詞開始看。最後一個詞可能
/// 還在長("pa" → "paar"),先照現在的樣子算,之後長大了也不重算。
(List<ParsedSyllable>, int) parseGermanIncrement(String text, int seen) {
  final words = text.split(RegExp(r'[\s,.!?;:]+')).where((w) => w.isNotEmpty).toList();
  if (words.length < seen) seen = 0;
  final out = <ParsedSyllable>[];
  for (var i = seen; i < words.length; i++) {
    out.add(ParsedSyllable(words[i], germanSyllable(words[i]) ?? ''));
  }
  return (out, words.length);
}
