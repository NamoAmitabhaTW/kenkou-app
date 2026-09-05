/// 提示文字要用哪套標示系統。
///
/// 純粹是顯示層的事 —— 嘴型的判定樣板是用發音時的唇形與開口幾何定義的,
/// 音節的判定是用聲音,兩者都跟寫成哪套文字無關,換系統不會動到任何門檻。
///
/// 長輩的識字習慣差很多:有人只認注音,有人受日治教育反而看假名最快,
/// 所以三套都留著讓家人挑。
enum LabelSystem {
  zhuyin('注音'),
  hanzi('國字'),
  kana('日文');

  const LabelSystem(this.displayName);
  final String displayName;
}
