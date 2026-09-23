import '../../../core/voice/syllable.dart';
import 'face_geometry.dart';
import 'mouth_shape.dart';
import 'settings.dart';

enum StepMode {
  face,

  speech,

  guided,
}

enum FaceMarker {
  none,

  cheek,
}

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

  final String section;
  final String title;
  final String instruction;
  final StepMode mode;

  final List<MouthShape> shapes;

  final Syllable? syllable;

  final FaceSide? side;

  final FaceMarker marker;

  final int reps;

  final Duration? hold;

  final int guidedSeconds;

  final String? caution;

  bool get usesFaceScore => mode == StepMode.face;
}

/// https://www.jda.or.jp/oral_frail/gymnastics/
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
