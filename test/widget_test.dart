import 'package:face_mesh/face_mesh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremode2026/features/kenkou/domain/mouth_shape.dart';

FaceFrame frameWith(Map<String, double> shapes) =>
    FaceFrame(hasFace: true, blendshapes: shapes);

void main() {
  group('MouthShapeClassifier', () {
    test('大開口判成「あ」', () {
      final result = MouthShapeClassifier().classify(frameWith({'jawOpen': 0.78}));
      expect(result.shape, MouthShape.a);
    });

    test('嘟嘴判成「う」而不是「お」', () {
      final result = MouthShapeClassifier().classify(
        frameWith({'mouthPucker': 0.65, 'mouthFunnel': 0.28, 'jawOpen': 0.14}),
      );
      expect(result.shape, MouthShape.u);
    });

    test('圓唇加開口判成「お」', () {
      final result = MouthShapeClassifier().classify(
        frameWith({'mouthFunnel': 0.60, 'mouthPucker': 0.30, 'jawOpen': 0.45}),
      );
      expect(result.shape, MouthShape.o);
    });

    test('校正會扣掉靜止時的基準值', () {
      final classifier = MouthShapeClassifier();
      classifier.calibrate(List.generate(10, (_) => frameWith({'jawOpen': 0.2})));
      final features = classifier.extractFeatures(frameWith({'jawOpen': 0.2}));
      expect(features['jawOpen'], closeTo(0, 0.001));
    });
  });

  group('HoldTracker', () {
    test('分數不足不會累積次數', () {
      final tracker = HoldTracker();
      for (var i = 0; i < 10; i++) {
        tracker.update(0.5);
      }
      expect(tracker.completions, 0);
      expect(tracker.state, HoldState.idle);
    });

    test('遲滯:落在進出門檻之間時維持 holding 不會中斷', () {
      final tracker = HoldTracker();
      tracker.update(0.85);
      expect(tracker.state, HoldState.holding);
      tracker.update(0.75);
      expect(tracker.state, HoldState.holding);
      tracker.update(0.60);
      expect(tracker.state, HoldState.idle);
    });

    test('維持足夠久後計為一次,且要放鬆才能再計下一次', () async {
      final tracker = HoldTracker(requiredHold: const Duration(milliseconds: 50));
      tracker.update(0.9);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      tracker.update(0.9);
      expect(tracker.completions, 1);
      expect(tracker.state, HoldState.completed);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      tracker.update(0.9);
      expect(tracker.completions, 1);

      tracker.update(0.1);
      expect(tracker.state, HoldState.idle);
    });

    test('暫停模式:維持到一半掉下去,計時停住,做回來接著數', () async {
      final tracker = HoldTracker(
          requiredHold: const Duration(milliseconds: 400), pauseOnDrop: true);
      tracker.update(0.9);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      tracker.update(0.9);
      final before = tracker.held;
      expect(before, greaterThan(Duration.zero));

      tracker.update(0.1);
      expect(tracker.state, HoldState.idle);
      expect(tracker.held, before, reason: '計時停住,不歸零');

      await Future<void>.delayed(const Duration(milliseconds: 300));
      tracker.update(0.9);
      expect(tracker.state, HoldState.holding);
      expect(tracker.held, before);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      tracker.update(0.9);
      expect(tracker.completions, 1, reason: '前後兩段加起來超過 400 毫秒');
    });

    test('預設模式:掉下去就歸零重來', () async {
      final tracker =
          HoldTracker(requiredHold: const Duration(milliseconds: 400));
      tracker.update(0.9);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      tracker.update(0.9);
      tracker.update(0.1);
      expect(tracker.held, Duration.zero);

      tracker.update(0.9);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      tracker.update(0.9);
      expect(tracker.completions, 0, reason: '只算得到後面那一段');
    });

    test('還要維持多久', () {
      final tracker = HoldTracker(requiredHold: const Duration(seconds: 10));
      expect(tracker.remaining, const Duration(seconds: 10));
    });
  });
}
