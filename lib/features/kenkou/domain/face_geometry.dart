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
