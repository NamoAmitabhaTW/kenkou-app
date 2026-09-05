import 'dart:math' as math;

import 'package:face_mesh/face_mesh.dart';

/// 健口操要判的目標嘴型。
///
/// 用 IPA 的母音來命名而不是用顯示的那個字,因為命名要穩定:/a/ 這個嘴型
/// 不管畫面上寫成哪個字都是同一個判定樣板。
///
/// 只列「靠嘴唇與下顎就看得出來」的動作。パタカラ 的 タ / カ / ラ
/// 是舌頭動作,face mesh 沒有舌頭的幾何,視覺上判不出來 — 那三個
/// 要靠麥克風,不要在這裡假裝測得到。
///
/// 同樣的理由,ㄩ 這個音也刻意沒有納入:它跟 ㄨ 的差別在舌位不在唇形,
/// 兩者的 blendshape 幾乎一樣,當成兩個可分辨的目標只會製造假陽性。
enum MouthShape {
  neutral(label: '閉口'),
  a(label: '啊'),
  i(label: '衣'),
  u(label: '嗚'),
  e(label: '耶'),
  o(label: '喔'),
  pa(label: '趴'),
  cheekPuff(label: '鼓起臉頰'),
  cheekSuck(label: '收縮臉頰');

  const MouthShape({required this.label});

  /// 畫面上顯示的字。
  final String label;
}

/// 把左右成對的 blendshape 併成一個特徵。
///
/// 健口操看的是整體嘴型,左右分開只會讓樣板多一倍維度卻沒有多資訊;
/// 之後若要做顏面神經麻痺的左右不對稱評估,再拆開。
const _symmetricPairs = <String, List<String>>{
  'mouthSmile': ['mouthSmileLeft', 'mouthSmileRight'],
  'mouthStretch': ['mouthStretchLeft', 'mouthStretchRight'],
  'mouthUpperUp': ['mouthUpperUpLeft', 'mouthUpperUpRight'],
  'mouthLowerDown': ['mouthLowerDownLeft', 'mouthLowerDownRight'],
  'mouthPress': ['mouthPressLeft', 'mouthPressRight'],
  'mouthFrown': ['mouthFrownLeft', 'mouthFrownRight'],
};

/// 判定時實際用到的特徵。UI 的長條圖也用這組順序。
const kFeatureKeys = <String>[
  'jawOpen',
  'mouthPucker',
  'mouthFunnel',
  'mouthSmile',
  'mouthStretch',
  'mouthClose',
  'cheekPuff',
];

/// 每個嘴型的目標特徵向量與權重。
///
/// 這些數字是「起手值」,不是定論。實際要拿目標族群(長者、可能戴假牙)
/// 錄一批資料回來校,或乾脆換成吃這幾維特徵的 logistic regression。
class _Template {
  const _Template(this.targets, this.weights);
  final Map<String, double> targets;
  final Map<String, double> weights;
}

const _templates = <MouthShape, _Template>{
  MouthShape.neutral: _Template(
    {'jawOpen': 0.03, 'mouthPucker': 0.05, 'mouthFunnel': 0.03, 'mouthSmile': 0.05, 'mouthStretch': 0.05, 'cheekPuff': 0.02},
    {'jawOpen': 2.0, 'mouthPucker': 1.0, 'mouthFunnel': 1.0, 'mouthSmile': 1.0, 'mouthStretch': 1.0, 'cheekPuff': 1.0},
  ),
  // あ:下顎大開,嘴唇不做任何形狀。
  MouthShape.a: _Template(
    {'jawOpen': 0.75, 'mouthPucker': 0.05, 'mouthFunnel': 0.10, 'mouthSmile': 0.10, 'mouthStretch': 0.15},
    {'jawOpen': 3.0, 'mouthPucker': 1.5, 'mouthFunnel': 1.0, 'mouthSmile': 1.0, 'mouthStretch': 0.5},
  ),
  // い:嘴角橫向拉開,下顎幾乎不動。
  MouthShape.i: _Template(
    {'jawOpen': 0.12, 'mouthPucker': 0.03, 'mouthFunnel': 0.03, 'mouthSmile': 0.60, 'mouthStretch': 0.50},
    {'jawOpen': 2.0, 'mouthPucker': 2.0, 'mouthFunnel': 1.0, 'mouthSmile': 2.5, 'mouthStretch': 2.0},
  ),
  // う / ㄨ:嘟嘴前突。與 お 最容易混淆,靠 funnel / jawOpen 區分。
  //
  // 注意:日文的 う 其實是「壓唇不圓唇」([ɯ]),國語的 ㄨ 才是真正的圓唇後元音。
  // 同一個使用者念 ㄨ 的 mouthPucker 會明顯高於念 う。如果你的教材走國語,
  // 這裡的 0.62 要往上調到 0.70 上下。
  MouthShape.u: _Template(
    {'jawOpen': 0.15, 'mouthPucker': 0.62, 'mouthFunnel': 0.30, 'mouthSmile': 0.03, 'mouthStretch': 0.05},
    {'jawOpen': 2.0, 'mouthPucker': 3.0, 'mouthFunnel': 1.5, 'mouthSmile': 1.5, 'mouthStretch': 1.0},
  ),
  MouthShape.e: _Template(
    {'jawOpen': 0.40, 'mouthPucker': 0.05, 'mouthFunnel': 0.08, 'mouthSmile': 0.32, 'mouthStretch': 0.35},
    {'jawOpen': 2.0, 'mouthPucker': 1.5, 'mouthFunnel': 1.0, 'mouthSmile': 2.0, 'mouthStretch': 1.5},
  ),
  // お:圓唇但開口比 う 大,funnel 明顯高於 pucker。
  MouthShape.o: _Template(
    {'jawOpen': 0.45, 'mouthPucker': 0.30, 'mouthFunnel': 0.58, 'mouthSmile': 0.03, 'mouthStretch': 0.05},
    {'jawOpen': 2.0, 'mouthPucker': 1.5, 'mouthFunnel': 3.0, 'mouthSmile': 1.5, 'mouthStretch': 1.0},
  ),
  // パ 的閉唇準備動作。真正的 /pa/ 是「閉緊 → 突然爆開」的轉換,
  // 單幀只能判到閉唇這一半,爆破那半要看時序或聽聲音。
  MouthShape.pa: _Template(
    {'jawOpen': 0.02, 'mouthPucker': 0.10, 'mouthFunnel': 0.05, 'mouthClose': 0.55, 'mouthSmile': 0.05},
    {'jawOpen': 3.0, 'mouthPucker': 1.0, 'mouthFunnel': 1.0, 'mouthClose': 2.5, 'mouthSmile': 1.0},
  ),
  // 鼓起臉頰。MediaPipe 的 cheekPuff 實測用力鼓也常常只到 0.4 上下,
  // 目標放 0.65 會永遠到不了門檻,所以壓到 0.40。
  MouthShape.cheekPuff: _Template(
    {'cheekPuff': 0.40, 'jawOpen': 0.05, 'mouthPucker': 0.10},
    {'cheekPuff': 4.0, 'jawOpen': 1.5, 'mouthPucker': 0.5},
  ),
  // 收縮臉頰(ほほをすぼめる):把兩頰往內吸、嘴唇縮起來。
  // face mesh 沒有「吸臉頰」的 blendshape,只能靠嘟嘴 + 臉頰完全沒鼓來抓;
  // 與 う 的差別在 pucker 更高、funnel 更低。
  MouthShape.cheekSuck: _Template(
    {'mouthPucker': 0.70, 'mouthFunnel': 0.15, 'cheekPuff': 0.0, 'jawOpen': 0.10, 'mouthSmile': 0.03},
    {'mouthPucker': 3.0, 'mouthFunnel': 1.0, 'cheekPuff': 3.0, 'jawOpen': 1.5, 'mouthSmile': 1.0},
  ),
};

/// 目標框的尺寸,單位是「臉寬的幾倍」。
///
/// 用臉寬當單位而不是像素,使用者往前靠或往後退時框才會跟著縮放。
/// 這兩個數字跟 blendshape 樣板是獨立的兩套東西:樣板決定「算不算對」,
/// 目標框只是畫給使用者看的提示,兩者要各自校。
class MouthGuide {
  const MouthGuide({required this.widthRatio, required this.openRatio});

  /// 嘴角到嘴角,相對臉寬。
  final double widthRatio;

  /// 內唇上下開口,相對臉寬。
  final double openRatio;
}

/// 起手值,同樣需要拿真人量過再調。
///
/// 最快的校法:打開除錯面板,自己做一次該嘴型,把面板上顯示的
/// 實際 width / open 讀數填回來。
const _guides = <MouthShape, MouthGuide>{
  MouthShape.neutral: MouthGuide(widthRatio: 0.33, openRatio: 0.01),
  MouthShape.a: MouthGuide(widthRatio: 0.30, openRatio: 0.30),
  MouthShape.i: MouthGuide(widthRatio: 0.42, openRatio: 0.04),
  MouthShape.u: MouthGuide(widthRatio: 0.17, openRatio: 0.08),
  MouthShape.e: MouthGuide(widthRatio: 0.36, openRatio: 0.16),
  MouthShape.o: MouthGuide(widthRatio: 0.24, openRatio: 0.22),
  MouthShape.pa: MouthGuide(widthRatio: 0.32, openRatio: 0.005),
  MouthShape.cheekPuff: MouthGuide(widthRatio: 0.30, openRatio: 0.01),
  MouthShape.cheekSuck: MouthGuide(widthRatio: 0.16, openRatio: 0.03),
};

extension MouthShapeGuide on MouthShape {
  MouthGuide get guide =>
      _guides[this] ?? const MouthGuide(widthRatio: 0.33, openRatio: 0.01);
}

/// 一次判定的結果。
class ShapeScore {
  const ShapeScore(this.shape, this.confidence);
  final MouthShape shape;
  final double confidence;
}

class MouthShapeClassifier {
  /// 靜止閉嘴時的特徵基準值。
  ///
  /// 每個人的臉在完全放鬆時 blendshape 也不會是全 0(嘴型、皺紋、假牙都會影響),
  /// 不扣掉這個底,判定門檻就得為每個人重調。
  Map<String, double> _baseline = const {};

  bool get isCalibrated => _baseline.isNotEmpty;

  void calibrate(List<FaceFrame> neutralFrames) {
    if (neutralFrames.isEmpty) return;
    final sums = <String, double>{};
    for (final frame in neutralFrames) {
      final features = extractFeatures(frame, applyBaseline: false);
      features.forEach((key, value) => sums[key] = (sums[key] ?? 0) + value);
    }
    _baseline = sums.map((k, v) => MapEntry(k, v / neutralFrames.length));
  }

  void clearCalibration() => _baseline = const {};

  /// 把原始 blendshape 收成判定用的特徵向量。
  Map<String, double> extractFeatures(FaceFrame frame, {bool applyBaseline = true}) {
    final features = <String, double>{};

    for (final key in kFeatureKeys) {
      final pair = _symmetricPairs[key];
      final raw = pair == null
          ? frame[key]
          : pair.map((k) => frame[k]).reduce((a, b) => a + b) / pair.length;

      final corrected = applyBaseline ? raw - (_baseline[key] ?? 0) : raw;
      features[key] = corrected.clamp(0.0, 1.0);
    }
    return features;
  }

  /// 對所有樣板評分,由高到低排序。
  ///
  /// 評分是加權平均絕對誤差的補數 — 刻意選了最好懂的形式,
  /// 因為這些權重你一定會手動調很多輪。
  List<ShapeScore> scoreAll(FaceFrame frame) {
    final features = extractFeatures(frame);
    final scores = <ShapeScore>[];

    for (final entry in _templates.entries) {
      final template = entry.value;
      double weightedError = 0;
      double totalWeight = 0;

      template.targets.forEach((key, target) {
        final weight = template.weights[key] ?? 1.0;
        weightedError += weight * (features[key]! - target).abs();
        totalWeight += weight;
      });

      final score = totalWeight == 0 ? 0.0 : 1.0 - (weightedError / totalWeight);
      scores.add(ShapeScore(entry.key, score.clamp(0.0, 1.0)));
    }

    scores.sort((a, b) => b.confidence.compareTo(a.confidence));
    return scores;
  }

  ShapeScore classify(FaceFrame frame) => scoreAll(frame).first;

  double scoreFor(FaceFrame frame, MouthShape shape) {
    return scoreAll(frame).firstWhere((s) => s.shape == shape).confidence;
  }
}

/// 練習單一嘴型的狀態機。
///
/// 健口操看的不是「某一幀對了」,而是「做到位並維持了幾秒,然後回到放鬆」。
/// 單幀判定會因為 landmark 抖動而瘋狂跳動,一定要走時序。
enum HoldState { idle, entering, holding, completed }

class HoldTracker {
  HoldTracker({
    this.enterThreshold = 0.80,
    this.exitThreshold = 0.70,
    this.requiredHold = const Duration(milliseconds: 1500),
  });

  /// 進入門檻高於離開門檻 — 遲滯(hysteresis)可以避免分數在門檻附近
  /// 來回抖動時狀態一直翻。
  final double enterThreshold;
  final double exitThreshold;
  final Duration requiredHold;

  HoldState state = HoldState.idle;
  Duration held = Duration.zero;
  int completions = 0;

  DateTime? _lastTick;

  void reset() {
    state = HoldState.idle;
    held = Duration.zero;
    _lastTick = null;
  }

  void resetSession() {
    reset();
    completions = 0;
  }

  void update(double score) {
    final now = DateTime.now();
    final delta = _lastTick == null ? Duration.zero : now.difference(_lastTick!);
    _lastTick = now;

    switch (state) {
      case HoldState.idle:
      case HoldState.entering:
        if (score >= enterThreshold) {
          state = HoldState.holding;
          held = Duration.zero;
        } else {
          state = score >= exitThreshold ? HoldState.entering : HoldState.idle;
          held = Duration.zero;
        }

      case HoldState.holding:
        if (score >= exitThreshold) {
          held += delta;
          if (held >= requiredHold) {
            state = HoldState.completed;
            completions++;
          }
        } else {
          state = HoldState.idle;
          held = Duration.zero;
        }

      case HoldState.completed:
        // 必須先放鬆回到低分,才能開始下一次 — 逼使用者真的做「一下一下」,
        // 而不是一直維持著同一個嘴型刷次數。
        if (score < exitThreshold) {
          state = HoldState.idle;
          held = Duration.zero;
        }
    }
  }

  double get progress => math.min(1.0, held.inMilliseconds / requiredHold.inMilliseconds);
}
