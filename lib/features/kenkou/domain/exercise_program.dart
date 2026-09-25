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

  parotid,

  submandibular,

  sublingual,

  tongueDown,

  tongueUp,

  tongueSides,

  tongueCircleClockwise,

  tongueCircleCounterclockwise,
}

class GuidedCue {
  const GuidedCue(this.text, {required this.seconds, this.marker})
      : assert(seconds > 0);

  final String text;
  final int seconds;

  final FaceMarker? marker;
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

const kPatakaSets = 2;

List<ExerciseStep> buildProgram(KenkouSettings s) {
  const lips = '口唇體操';
  const cheeks = '嘴唇與臉頰體操';
  const tonguePress = '舌壓訓練';
  const saliva = '唾液腺按摩';
  const mouthOpen = '張口訓練';
  const tongueOut = '伸舌吞嚥體操';
  const forehead = '額頭體操';
  const swallow = '吞嚥體操';
  const tongue = '舌頭訓練';

  return [
    ExerciseStep(
      id: 'lips_u_i',
      section: lips,
      mode: StepMode.face,
      shapes: const [MouthShape.u, MouthShape.i],
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
    for (var set = 1; set <= kPatakaSets; set++)
      for (final syllable in Syllable.values)
        ExerciseStep(
          id: 'pataka_${syllable.name}_$set',
          section: '發音體操 第 $set 組',
          mode: StepMode.speech,
          syllable: syllable,
          reps: s.patakaReps,
        ),
    const ExerciseStep(
      id: 'saliva_parotid',
      section: saliva,
      mode: StepMode.guided,
      marker: FaceMarker.parotid,
      cues: [GuidedCue('手指放耳朵前面,畫圓按摩', seconds: 20)],
      detail: '大約在上排後牙的位置,按 10 圈',
    ),
    const ExerciseStep(
      id: 'saliva_submandibular',
      section: saliva,
      mode: StepMode.guided,
      marker: FaceMarker.submandibular,
      cues: [GuidedCue('按壓下巴骨內側的凹陷處', seconds: 25)],
      detail: '從耳朵下方往下巴,依序按 3～4 處,每處 5 下',
    ),
    const ExerciseStep(
      id: 'saliva_sublingual',
      section: saliva,
      mode: StepMode.guided,
      marker: FaceMarker.sublingual,
      cues: [GuidedCue('兩手拇指往上壓下巴下方', seconds: 20)],
      detail: '拇指併攏,抵住軟軟的地方,慢慢壓 10 次',
    ),

    ExerciseStep(
      id: 'mouth_open',
      section: mouthOpen,
      mode: StepMode.face,
      shapes: const [MouthShape.a],
      reps: 2,
      hold: const Duration(seconds: 10),
      pauseOnDrop: true,
      rest: const Duration(seconds: 10),
      detail: '張到最大,維持 10 秒',
      caution: '張口不要勉強,以不會痛為限',
    ),
    const ExerciseStep(
      id: 'tongue_out_swallow',
      section: tongueOut,
      mode: StepMode.guided,
      cues: [
        GuidedCue('舌頭稍微伸出來', seconds: 6),
        GuidedCue('閉上嘴巴吞口水', seconds: 14),
      ],
    ),
    const ExerciseStep(
      id: 'forehead_push',
      section: forehead,
      mode: StepMode.guided,
      cues: [
        GuidedCue('手掌和額頭互相推', seconds: 8),
        GuidedCue('低頭看肚臍,數到 5', seconds: 12),
      ],
      detail: '用手掌推額頭,額頭出力抵住手掌',
      caution: '脖子會痛或有高血壓的人,請跳過',
    ),
    const ExerciseStep(
      id: 'swallow_check',
      section: swallow,
      mode: StepMode.guided,
      cues: [GuidedCue('手放在喉結上,吞口水', seconds: 20)],
      detail: '確認喉結有往上抬',
    ),
    const ExerciseStep(
      id: 'swallow_hold',
      section: swallow,
      mode: StepMode.guided,
      cues: [
        GuidedCue('吞口水,喉結往上抬', seconds: 7),
        GuidedCue('喉結維持在上面', seconds: 5),
        GuidedCue('一口氣把氣吐完', seconds: 8),
      ],
      detail: '手放在喉嚨,下巴稍微往內收',
      caution: '維持不到 5 秒也沒關係,不要勉強',
    ),

    const ExerciseStep(
      id: 'tongue_down',
      section: tongue,
      mode: StepMode.guided,
      marker: FaceMarker.tongueDown,
      cues: [GuidedCue('舌頭往下伸', seconds: 20)],
      detail: '像要碰到下巴尖端一樣',
    ),
    const ExerciseStep(
      id: 'tongue_up',
      section: tongue,
      mode: StepMode.guided,
      marker: FaceMarker.tongueUp,
      cues: [GuidedCue('舌頭往上伸', seconds: 20)],
      detail: '像要碰到鼻尖一樣',
    ),
    const ExerciseStep(
      id: 'tongue_sides',
      section: tongue,
      mode: StepMode.guided,
      marker: FaceMarker.tongueSides,
      cues: [GuidedCue('舌頭往左、往右伸', seconds: 20)],
    ),
    const ExerciseStep(
      id: 'tongue_circle',
      section: tongue,
      mode: StepMode.guided,
      cues: [
        GuidedCue('舌頭順時針轉圈',
            seconds: 15, marker: FaceMarker.tongueCircleClockwise),
        GuidedCue('舌頭逆時針轉圈',
            seconds: 15, marker: FaceMarker.tongueCircleCounterclockwise),
      ],
      detail: '跟著綠色箭頭的方向轉',
    ),
  ];
}
