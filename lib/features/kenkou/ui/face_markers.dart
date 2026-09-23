import 'dart:math' as math;

import 'package:face_mesh/face_mesh.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';
import '../domain/exercise_program.dart';
import '../domain/face_geometry.dart';

class FaceMarkerPainter extends CustomPainter {
  const FaceMarkerPainter({
    required this.frame,
    required this.marker,
    this.side,
    this.matched = false,
    this.pulse = 0,
  });

  final FaceFrame frame;
  final FaceMarker marker;
  final FaceSide? side;

  final bool matched;

  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (!frame.hasFace ||
        marker == FaceMarker.none ||
        !frame.hasExtendedContour) {
      return;
    }
    final edges = frame.faceEdges;
    if (edges.length < 2) return;

    final projection =
        FaceMeshProjection(imageSize: frame.imageSize, viewSize: size);
    final faceWidth =
        (projection.project(edges[0]) - projection.project(edges[1])).distance;

    switch (marker) {
      case FaceMarker.none:
        return;

      case FaceMarker.cheek:
        final side = this.side ?? FaceSide.left;
        final corner = FaceGeometry.mouthCornerOf(frame, side);
        if (corner == null) return;
        final dir = side == FaceSide.left ? -1.0 : 1.0;
        _arrow(
          canvas,
          projection.project(corner) +
              Offset(dir * faceWidth * 0.08, -faceWidth * 0.02),
          dir > 0 ? 0 : math.pi,
          faceWidth * 0.22,
          '舌頭往這裡頂',
        );
    }
  }

  void _arrow(
      Canvas canvas, Offset tail, double angle, double length, String label) {
    final dir = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-dir.dy, dir.dx);
    final bob = 0.06 * length * math.sin(pulse * 2 * math.pi);
    final start = tail + dir * bob;
    final tip = start + dir * length;
    final headLen = length * 0.42;
    final headHalf = length * 0.26;
    final shaftHalf = length * 0.10;
    final neck = tip - dir * headLen;

    final path = Path()
      ..moveTo(start.dx + normal.dx * shaftHalf, start.dy + normal.dy * shaftHalf)
      ..lineTo(neck.dx + normal.dx * shaftHalf, neck.dy + normal.dy * shaftHalf)
      ..lineTo(neck.dx + normal.dx * headHalf, neck.dy + normal.dy * headHalf)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(neck.dx - normal.dx * headHalf, neck.dy - normal.dy * headHalf)
      ..lineTo(neck.dx - normal.dx * shaftHalf, neck.dy - normal.dy * shaftHalf)
      ..lineTo(start.dx - normal.dx * shaftHalf, start.dy - normal.dy * shaftHalf)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: 0.4),
    );
    canvas.drawPath(path, Paint()..color = kAccentGreen);

    _label(canvas, start - dir * (length * 0.15) + Offset(0, length * 0.55),
        label);
  }

  void _label(Canvas canvas, Offset at, String text) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at + Offset(-painter.width / 2, 0));
  }

  @override
  bool shouldRepaint(FaceMarkerPainter old) =>
      old.frame != frame ||
      old.marker != marker ||
      old.side != side ||
      old.matched != matched ||
      old.pulse != pulse;
}
