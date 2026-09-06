import '../../../core/voice/syllable.dart';
import 'face_geometry.dart';
import 'mouth_shape.dart';
import 'settings.dart';

/// 一個步驟怎麼判定「做到了」。
enum StepMode {
  /// 相機看嘴型:做到位並維持住,算一次。
  face,

  /// 麥克風聽音節(加上嘴唇有沒有閉合的輔助判斷),辨識到目標音節,算一次。
  speech,

  /// 相機和麥克風都判不出來(舌頭、按摩、吞嚥),倒數計時引導。
  /// 畫面上可以配 [FaceMarker] 提示位置或方向。
  guided,
}

/// 要在臉上標出來的位置。
enum FaceMarker {
  none,

  /// 某一邊臉頰(搭配 [ExerciseStep.side]):舌頭要往這裡頂。
  cheek,
}

/// 健口操裡的一個動作。
class ExerciseStep {
  const ExerciseStep({
    required this.id,
    required this.section,
    required this.title,
    required this.instruction,
    required this.mode,
    this.shapes = const [],
    this.syllable,
    this.side,
    this.marker = FaceMarker.none,
    this.reps = 1,
    this.hold,
    this.guidedSeconds = 20,
    this.caution,
  }) : assert(mode != StepMode.face || shapes.length > 0),
       assert(mode != StepMode.speech || syllable != null),
       assert(marker != FaceMarker.cheek || side != null);

  final String id;

  /// 所屬的體操名稱,顯示在動作標題上方。
  final String section;
  final String title;
  final String instruction;
  final StepMode mode;

  /// [StepMode.face] 的目標嘴型。長度大於 1 時是一組要輪流做的動作
  /// (例如鼓起臉頰 → 收縮臉頰),整組做完才算一次。
  final List<MouthShape> shapes;

  /// [StepMode.speech] 的目標音節。
  final Syllable? syllable;

  /// [FaceMarker.cheek] 要頂哪一邊。
  final FaceSide? side;

  /// 畫面上要標出來的位置。
  final FaceMarker marker;

  /// 要做幾次。
  final int reps;

  /// 每次要維持多久;null 表示用設定裡的預設值。
  final Duration? hold;

  /// [StepMode.guided] 每一輪的倒數秒數。
  final int guidedSeconds;

  /// 注意事項,例如「脖子會痛的人請跳過」。
  final String? caution;

  /// 這個步驟是不是靠相機分數(嘴型)計次。
  bool get usesFaceScore => mode == StepMode.face;
}

/// 依照日本牙醫師會「オーラルフレイル対策のための口腔体操」的順序組出整套。
///
/// https://www.jda.or.jp/oral_frail/gymnastics/
///
/// 目前只做第一大類「お口・舌の動きをスムーズにする体操」裡相機和麥克風
/// 判得出來的部分:嘟嘴、張大嘴巴、「衣～」、舌頭頂臉頰(引導)、パタカラ。
/// 鼓頰、唾液腺按摩、吞嚥體操、舌頭訓練、咀嚼、早口言葉都拿掉了 ——
/// 判不準的動作留在流程裡只會讓長輩卡住。
List<ExerciseStep> buildProgram(KenkouSettings s) {
  const mouth = '嘴巴的體操';
  const tongue = '舌頭的體操(舌壓訓練)';
  const pataka = '怕踏卡啦體操';

  return [
    ExerciseStep(
      id: 'mouth_pucker',
      section: mouth,
      title: '① 嘟嘴',
      instruction: '嘴唇往前噘起來,像要親一下,用力維持住',
      mode: StepMode.face,
      shapes: const [MouthShape.u],
      reps: s.faceReps,
    ),
    ExerciseStep(
      id: 'mouth_open',
      section: mouth,
      title: '② 張大嘴巴',
      instruction: '嘴巴張到最大,像要說「啊～」,用力維持住',
      mode: StepMode.face,
      shapes: const [MouthShape.a],
      reps: s.faceReps,
    ),
    ExerciseStep(
      id: 'mouth_ii',
      section: mouth,
      title: '③ 唸「衣～」橫向拉開',
      instruction: '嘴角往兩邊用力拉開,發出「衣～」',
      mode: StepMode.face,
      shapes: const [MouthShape.i],
      reps: s.faceReps,
    ),
    // 舌頭頂臉頰:試過用臉頰輪廓偵測,鏡頭一近就不穩,改成跟舌頭訓練
    // 一樣用畫面標記 + 倒數。
    const ExerciseStep(
      id: 'tongue_press_left',
      section: tongue,
      title: '舌頭頂左邊臉頰',
      instruction:
          '舌頭用力頂住畫面圈起來的那一邊臉頰內側,把臉頰頂出來。'
          '可以用手指從外面壓住,讓舌頭抵抗,慢慢頂 10 次',
      mode: StepMode.guided,
      side: FaceSide.left,
      marker: FaceMarker.cheek,
      guidedSeconds: 20,
    ),
    const ExerciseStep(
      id: 'tongue_press_right',
      section: tongue,
      title: '舌頭頂右邊臉頰',
      instruction: '換另一邊,同樣把圈起來的那一邊臉頰頂出來,慢慢頂 10 次',
      mode: StepMode.guided,
      side: FaceSide.right,
      marker: FaceMarker.cheek,
      guidedSeconds: 20,
    ),
    // 固定一組。官網是兩組,但一組八個音做完已經不短,而且設定檔裡若殘留
    // 舊的組數,會多出一整輪。id 保留 _1 的尾碼,跟舊紀錄相容。
    for (final syllable in Syllable.values)
      ExerciseStep(
        id: 'pataka_${syllable.name}_1',
        section: pataka,
        title: '${switch (syllable) {
          Syllable.pa => '①',
          Syllable.ta => '②',
          Syllable.ka => '③',
          Syllable.ra => '④',
        }} ${syllable.label}',
        instruction: switch (syllable) {
          Syllable.pa => '嘴唇先閉緊,再用力彈開,清楚地說出來',
          Syllable.ta => '舌尖抵住上排門牙後面,再彈開',
          Syllable.ka => '舌根抵住上顎後方,再放開',
          Syllable.ra => '舌頭往上捲,再放下來',
        },
        mode: StepMode.speech,
        syllable: syllable,
        reps: s.patakaReps,
      ),
  ];
}
