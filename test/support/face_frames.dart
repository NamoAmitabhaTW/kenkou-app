import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:face_mesh/face_mesh.dart';

FaceFrame contourFrame({
  double faceWidth = 0.5,
  double cheekWidth = 0.4,
  Offset earA = const Offset(0.25, 0.45),
  Offset earB = const Offset(0.75, 0.45),
  bool hasFace = true,
}) {
  final contour = Float32List(87 * 2);
  void put(int index, Offset p) {
    contour[index * 2] = p.dx;
    contour[index * 2 + 1] = p.dy;
  }

  for (var i = 0; i < 87; i++) {
    put(i, const Offset(0.5, 0.5));
  }
  for (var i = 0; i < 20; i++) {
    final angle = i / 20 * 2 * math.pi;
    put(i, Offset(0.5 - 0.08 * math.cos(angle), 0.62 + 0.03 * math.sin(angle)));
  }
  put(40, Offset(0.5 - faceWidth / 2, 0.42));
  put(41, Offset(0.5 + faceWidth / 2, 0.42));
  put(72, const Offset(0.5, 0.52));
  put(73, const Offset(0.5, 0.42));
  put(74, const Offset(0.5, 0.75));
  put(75, earA);
  put(76, earB);
  put(77, const Offset(0.3, 0.64));
  put(78, const Offset(0.7, 0.64));
  for (var i = 0; i < 4; i++) {
    put(79 + i, Offset(0.5 - cheekWidth / 2, 0.55 + i * 0.04));
    put(83 + i, Offset(0.5 + cheekWidth / 2, 0.55 + i * 0.04));
  }
  return FaceFrame(hasFace: hasFace, contour: contour);
}
