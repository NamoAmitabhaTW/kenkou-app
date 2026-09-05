import '../label_system.dart';

/// パタカラ 的四個音節。
///
/// 這是**語音辨識的輸出詞彙**,不是健口操專屬的東西:健口操拿它當「要說哪個音」
/// 的目標,吃金幣拿同樣四個音當方向鍵。兩邊共用同一顆模型、同一套對照表,
/// 判定行為才會完全一致 —— 所以它放在 shared 而不是任何一個 feature 裡。
///
/// 標籤跟嘴型一樣分三套寫法([LabelSystem])。國字照台灣健口操教材常用的
/// 「啪、踏、咖、啦」;送氣不送氣都算(辨識端 ㄅ/ㄉ/ㄍ 開頭的字也收),
/// 練的是嘴唇和舌頭的動作,不是聲母。哪些字算哪個音節見 `syllable_map.dart`。
enum Syllable {
  pa(zhuyin: 'ㄆㄚ', hanzi: '啪', kana: 'パ'),
  ta(zhuyin: 'ㄊㄚ', hanzi: '踏', kana: 'タ'),
  ka(zhuyin: 'ㄎㄚ', hanzi: '咖', kana: 'カ'),
  // 國語沒有 r + a 的音節,日文ラ行本來就接近 [ɾa],用 ㄌㄚ 最貼近。
  ra(zhuyin: 'ㄌㄚ', hanzi: '啦', kana: 'ラ');

  const Syllable({
    required this.zhuyin,
    required this.hanzi,
    required this.kana,
  });

  final String zhuyin;
  final String hanzi;
  final String kana;

  String labelIn(LabelSystem system) => switch (system) {
        LabelSystem.zhuyin => zhuyin,
        LabelSystem.hanzi => hanzi,
        LabelSystem.kana => kana,
      };
}
