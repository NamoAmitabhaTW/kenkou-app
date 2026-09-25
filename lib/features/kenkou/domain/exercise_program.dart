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

class GuidedCue {
  const GuidedCue(this.text, {required this.seconds}) : assert(seconds > 0);

  final String text;
  final int seconds;
}

class ExerciseStep {
  const ExerciseStep({
    required this.id,
    required this.section,
    required this.mode,
    this.shapes = const [],
    this.syllable,
    this.side,
    this.marker = FaceMarker.none,
    this.reps = 1,
    this.hold,
    this.pauseOnDrop = false,
    this.rest,
    this.cues = const [],
    this.detail,
    this.caution,
  }) : assert(mode != StepMode.face || shapes.length > 0),
       assert(mode != StepMode.speech || syllable != null),
       assert(marker != FaceMarker.cheek || side != null),
       assert(rest == null || mode == StepMode.face),
       assert(mode == StepMode.guided || cues.length == 0);

  final String id;

  final String section;
  final StepMode mode;

  final List<MouthShape> shapes;

  final Syllable? syllable;

  final FaceSide? side;

  final FaceMarker marker;

  final int reps;

  final Duration? hold;

  final bool pauseOnDrop;

  final Duration? rest;

  final List<GuidedCue> cues;

  final String? detail;

  final String? caution;

  bool get usesFaceScore => mode == StepMode.face;

  List<GuidedCue> get guidedCues => [for (var i = 0; i < reps; i++) ...cues];
}

List<ExerciseStep> buildProgram(KenkouSettings s) {
  const lips = '口唇體操';
  const cheeks = '嘴唇與臉頰體操';
  const tonguePress = '舌壓訓練';
  const pataka = '發音體操';

  return [
    ExerciseStep(
      id: 'lips_u_i',
      section: lips,
      mode: StepMode.face,
      shapes: const [MouthShape.u, MouthShape.i],
      reps: s.faceReps,
    ),
    ExerciseStep(
      id: 'mouth_open',
      section: lips,
      mode: StepMode.face,
      shapes: const [MouthShape.a],
      reps: s.faceReps,
    ),
    ExerciseStep(
      id: 'cheek_puff_suck',
      section: cheeks,
      mode: StepMode.guided,
      cues: const [
        GuidedCue('鼓起臉頰', seconds: 5),
        GuidedCue('縮起臉頰', seconds: 5),
      ],
      reps: s.faceReps,
    ),
    const ExerciseStep(
      id: 'tongue_press_left',
      section: tonguePress,
      mode: StepMode.guided,
      side: FaceSide.left,
      marker: FaceMarker.cheek,
      cues: [GuidedCue('舌頭用力頂住左邊臉頰', seconds: 20)],
      detail: '手指從外面按住抵抗,慢慢頂 10 次',
    ),
    const ExerciseStep(
      id: 'tongue_press_right',
      section: tonguePress,
      mode: StepMode.guided,
      side: FaceSide.right,
      marker: FaceMarker.cheek,
      cues: [GuidedCue('舌頭用力頂住右邊臉頰', seconds: 20)],
      detail: '手指從外面按住抵抗,慢慢頂 10 次',
    ),
    for (final syllable in Syllable.values)
      ExerciseStep(
        id: 'pataka_${syllable.name}_1',
        section: pataka,
        mode: StepMode.speech,
        syllable: syllable,
        reps: s.patakaReps,
        detail: switch (syllable) {
          Syllable.pa => '嘴唇先閉緊,再用力彈開',
          Syllable.ta => '舌尖抵住上排門牙後面,再彈開',
          Syllable.ka => '舌根抵住上顎後方,再放開',
          Syllable.ra => '舌頭往上捲,再放下來',
        },
      ),
  ];
}
