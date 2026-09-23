import 'dart:math' as math;

import 'package:face_mesh/face_mesh.dart';

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

  final String label;
}

const _symmetricPairs = <String, List<String>>{
  'mouthSmile': ['mouthSmileLeft', 'mouthSmileRight'],
  'mouthStretch': ['mouthStretchLeft', 'mouthStretchRight'],
  'mouthUpperUp': ['mouthUpperUpLeft', 'mouthUpperUpRight'],
  'mouthLowerDown': ['mouthLowerDownLeft', 'mouthLowerDownRight'],
  'mouthPress': ['mouthPressLeft', 'mouthPressRight'],
  'mouthFrown': ['mouthFrownLeft', 'mouthFrownRight'],
};

const kFeatureKeys = <String>[
  'jawOpen',
  'mouthPucker',
  'mouthFunnel',
  'mouthSmile',
  'mouthStretch',
  'mouthClose',
  'cheekPuff',
];

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
  MouthShape.a: _Template(
    {'jawOpen': 0.75, 'mouthPucker': 0.05, 'mouthFunnel': 0.10, 'mouthSmile': 0.10, 'mouthStretch': 0.15},
    {'jawOpen': 3.0, 'mouthPucker': 1.5, 'mouthFunnel': 1.0, 'mouthSmile': 1.0, 'mouthStretch': 0.5},
  ),
  MouthShape.i: _Template(
    {'jawOpen': 0.12, 'mouthPucker': 0.03, 'mouthFunnel': 0.03, 'mouthSmile': 0.60, 'mouthStretch': 0.50},
    {'jawOpen': 2.0, 'mouthPucker': 2.0, 'mouthFunnel': 1.0, 'mouthSmile': 2.5, 'mouthStretch': 2.0},
  ),
  MouthShape.u: _Template(
    {'jawOpen': 0.15, 'mouthPucker': 0.62, 'mouthFunnel': 0.30, 'mouthSmile': 0.03, 'mouthStretch': 0.05},
    {'jawOpen': 2.0, 'mouthPucker': 3.0, 'mouthFunnel': 1.5, 'mouthSmile': 1.5, 'mouthStretch': 1.0},
  ),
  MouthShape.e: _Template(
    {'jawOpen': 0.40, 'mouthPucker': 0.05, 'mouthFunnel': 0.08, 'mouthSmile': 0.32, 'mouthStretch': 0.35},
    {'jawOpen': 2.0, 'mouthPucker': 1.5, 'mouthFunnel': 1.0, 'mouthSmile': 2.0, 'mouthStretch': 1.5},
  ),
  MouthShape.o: _Template(
    {'jawOpen': 0.45, 'mouthPucker': 0.30, 'mouthFunnel': 0.58, 'mouthSmile': 0.03, 'mouthStretch': 0.05},
    {'jawOpen': 2.0, 'mouthPucker': 1.5, 'mouthFunnel': 3.0, 'mouthSmile': 1.5, 'mouthStretch': 1.0},
  ),
  MouthShape.pa: _Template(
    {'jawOpen': 0.02, 'mouthPucker': 0.10, 'mouthFunnel': 0.05, 'mouthClose': 0.55, 'mouthSmile': 0.05},
    {'jawOpen': 3.0, 'mouthPucker': 1.0, 'mouthFunnel': 1.0, 'mouthClose': 2.5, 'mouthSmile': 1.0},
  ),
  MouthShape.cheekPuff: _Template(
    {'cheekPuff': 0.40, 'jawOpen': 0.05, 'mouthPucker': 0.10},
    {'cheekPuff': 4.0, 'jawOpen': 1.5, 'mouthPucker': 0.5},
  ),
  MouthShape.cheekSuck: _Template(
    {'mouthPucker': 0.70, 'mouthFunnel': 0.15, 'cheekPuff': 0.0, 'jawOpen': 0.10, 'mouthSmile': 0.03},
    {'mouthPucker': 3.0, 'mouthFunnel': 1.0, 'cheekPuff': 3.0, 'jawOpen': 1.5, 'mouthSmile': 1.0},
  ),
};

class MouthGuide {
  const MouthGuide({required this.widthRatio, required this.openRatio});

  final double widthRatio;

  final double openRatio;
}

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

class ShapeScore {
  const ShapeScore(this.shape, this.confidence);
  final MouthShape shape;
  final double confidence;
}

class MouthShapeClassifier {
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

enum HoldState { idle, entering, holding, completed }

class HoldTracker {
  HoldTracker({
    this.enterThreshold = 0.80,
    this.exitThreshold = 0.70,
    this.requiredHold = const Duration(milliseconds: 1500),
  });

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
        if (score < exitThreshold) {
          state = HoldState.idle;
          held = Duration.zero;
        }
    }
  }

  double get progress => math.min(1.0, held.inMilliseconds / requiredHold.inMilliseconds);
}
