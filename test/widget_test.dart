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
      // 這個人放鬆時 jawOpen 天生就有 0.2
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
      tracker.update(0.75); // 低於 enter 但高於 exit
      expect(tracker.state, HoldState.holding);
      tracker.update(0.60); // 低於 exit 才中斷
      expect(tracker.state, HoldState.idle);
    });

    test('維持足夠久後計為一次,且要放鬆才能再計下一次', () async {
      final tracker = HoldTracker(requiredHold: const Duration(milliseconds: 50));
      tracker.update(0.9);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      tracker.update(0.9);
      expect(tracker.completions, 1);
      expect(tracker.state, HoldState.completed);

      // 沒放鬆就繼續維持,不該一直加次數
      await Future<void>.delayed(const Duration(milliseconds: 80));
      tracker.update(0.9);
      expect(tracker.completions, 1);

      tracker.update(0.1); // 放鬆
      expect(tracker.state, HoldState.idle);
    });
  });
}
