const kSyllableByGermanWord = <String, String>{
  'pa': 'pa', 'p': 'pa', 'ah': 'pa', 'pap': 'pa', 'papp': 'pa', 'paar': 'pa', 'pah': 'pa', 'par': 'pa', 'ba': 'pa', 'bah': 'pa', 'bar': 'pa', 'papa': 'pa',
  'ta': 'ta', 't': 'ta', 'tag': 'ta', 'tah': 'ta', 'tar': 'ta', 'da': 'ta', 'dah': 'ta', 'dar': 'ta', 'tata': 'ta',
  'ka': 'ka', 'k': 'ka', 'kah': 'ka', 'kar': 'ka', 'ga': 'ka', 'gah': 'ka', 'gar': 'ka', 'kaka': 'ka',
  'ra': 'la', 'l': 'la', 'na': 'la', 'rah': 'la', 'raa': 'la', 'rar': 'la', 'la': 'la', 'lah': 'la', 'rara': 'la',
};

String? germanSyllable(String word) {
  final cleaned = word.toLowerCase().replaceAll(RegExp(r'[^a-zäöüß]'), '');
  if (cleaned.isEmpty) return null;
  return kSyllableByGermanWord[cleaned];
}

class ParsedSyllable {
  const ParsedSyllable(this.text, this.label, {this.unknown = false});
  final String text;
  final String label;
  final bool unknown;
}

(List<ParsedSyllable>, int) parseGermanIncrement(String text, int seen) {
  final words = text.split(RegExp(r'[\s,.!?;:]+')).where((w) => w.isNotEmpty).toList();
  if (words.length < seen) seen = 0;
  final out = <ParsedSyllable>[];
  for (var i = seen; i < words.length; i++) {
    out.add(ParsedSyllable(words[i], germanSyllable(words[i]) ?? ''));
  }
  return (out, words.length);
}
