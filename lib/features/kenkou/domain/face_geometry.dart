import 'dart:ui';

import 'package:face_mesh/face_mesh.dart';

import '../../../core/voice/syllable.dart';

enum FaceSide { left, right }

class FaceGeometry {
  static Offset? mouthCornerOf(FaceFrame frame, FaceSide side) {
    final outer = frame.outerLip;
    if (outer.length < 11) return null;
    final aIsLeft = outer[0].dx > outer[10].dx;
    return (side == FaceSide.left) == aIsLeft ? outer[0] : outer[10];
  }

  static List<Offset> parotidPoints(FaceFrame frame) {
    final outer = frame.outerLip;
    final ears = [frame.earA, frame.earB];
    if (outer.length < 11 || ears.contains(null)) return const [];
    return [
      for (final ear in ears.cast<Offset>())
        Offset.lerp(ear, _nearer(ear, outer[0], outer[10]), 0.2)!,
    ];
  }

  static List<List<Offset>> submandibularPoints(FaceFrame frame) {
    final chin = frame.chin;
    final nose = frame.noseTip;
    final jaws = [frame.jawA, frame.jawB];
    if (chin == null || nose == null || jaws.contains(null)) return const [];
    final down = (chin - nose) * 0.08;
    return [
      for (final jaw in jaws.cast<Offset>())
        [
          for (final t in const [0.1, 0.3, 0.5, 0.7])
            Offset.lerp(jaw, chin, t)! + down,
        ],
    ];
  }

  static Offset? sublingualPoint(FaceFrame frame) {
    final chin = frame.chin;
    final nose = frame.noseTip;
    if (chin == null || nose == null) return null;
    return chin + (chin - nose) * 0.15;
  }

  static Offset _nearer(Offset from, Offset a, Offset b) =>
      (a - from).distanceSquared <= (b - from).distanceSquared ? a : b;
}

class LipsClosedDetector {
  static const _margin = 0.006;

  double _baseline = 0.008;

  void calibrate(List<FaceFrame> neutralFrames) {
    final withFace = neutralFrames.where((f) => f.hasFace).toList();
    if (withFace.isEmpty) return;
    _baseline = withFace.map((f) => f.mouthOpenRatio).reduce((a, b) => a + b) /
        withFace.length;
  }

  double get threshold => _baseline + _margin;

  bool isClosed(FaceFrame frame) =>
      frame.hasFace && frame.mouthOpenRatio < threshold;
}

Syllable? resolveSyllable({
  required Syllable heard,
  required Syllable target,
  required bool lipsClosed,
}) {
  if (heard == target) return heard;
  if (target == Syllable.pa && lipsClosed && heard != Syllable.ra) {
    return Syllable.pa;
  }
  return heard;
}
