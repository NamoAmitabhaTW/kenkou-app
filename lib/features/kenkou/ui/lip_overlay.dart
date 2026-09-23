import 'package:face_mesh/face_mesh.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';

class LipOverlayPainter extends CustomPainter {
  const LipOverlayPainter({required this.frame, required this.matched});

  final FaceFrame frame;

  final bool matched;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = frame.outerLip;
    if (!frame.hasFace || outer.isEmpty) return;

    final projection = FaceMeshProjection(imageSize: frame.imageSize, viewSize: size);
    final path = Path()..addPolygon(outer.map(projection.project).toList(growable: false), true);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = (matched ? kAccentGreen : Colors.white).withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(LipOverlayPainter old) => old.frame != frame || old.matched != matched;
}
