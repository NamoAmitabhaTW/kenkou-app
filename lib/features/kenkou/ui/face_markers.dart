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
        _cheek(canvas, projection, faceWidth);
      case FaceMarker.parotid:
        _parotid(canvas, projection, faceWidth);
      case FaceMarker.submandibular:
        _submandibular(canvas, projection, faceWidth);
      case FaceMarker.sublingual:
        _sublingual(canvas, projection, faceWidth);
      case FaceMarker.tongueDown ||
            FaceMarker.tongueUp ||
            FaceMarker.tongueSides ||
            FaceMarker.tongueCircleClockwise ||
            FaceMarker.tongueCircleCounterclockwise:
        _tongue(canvas, projection);
    }
  }

  void _cheek(Canvas canvas, FaceMeshProjection projection, double faceWidth) {
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

  void _parotid(Canvas canvas, FaceMeshProjection projection, double faceWidth) {
    final radius = faceWidth * 0.06;
    for (final point in FaceGeometry.parotidPoints(frame)) {
      final center = projection.project(point);
      _ring(canvas, center, radius);
      _orbit(
        canvas,
        Rect.fromCircle(center: center, radius: radius * 1.7),
        pulse * 2 * math.pi,
        strokeWidth: 3,
      );
      _label(canvas, center + Offset(0, radius * 2.1), '耳下腺');
    }
  }

  void _submandibular(
      Canvas canvas, FaceMeshProjection projection, double faceWidth) {
    final radius = faceWidth * 0.028;
    for (final row in FaceGeometry.submandibularPoints(frame)) {
      final active = (pulse * row.length).floor().clamp(0, row.length - 1);
      for (var i = 0; i < row.length; i++) {
        _dot(canvas, projection.project(row[i]), radius, active: i == active);
      }
      _label(canvas, projection.project(row[1]) + Offset(0, radius * 2.2),
          '顎下腺');
    }
  }

  void _sublingual(
      Canvas canvas, FaceMeshProjection projection, double faceWidth) {
    final point = FaceGeometry.sublingualPoint(frame);
    if (point == null) return;
    final center = projection.project(point);
    final radius = faceWidth * 0.05;
    _ring(canvas, center, radius);
    _arrow(canvas, center + Offset(0, radius * 3.6), -math.pi / 2,
        radius * 2, '');
    _label(canvas, center + Offset(radius * 3.4, -radius * 0.6), '舌下腺');
  }

  void _tongue(Canvas canvas, FaceMeshProjection projection) {
    final outer = frame.outerLip.map(projection.project).toList();
    if (outer.length < 20) return;
    final cornerA = outer[0];
    final cornerB = outer[10];
    final bottom = outer[5];
    final top = outer[15];
    final center = outer.reduce((a, b) => a + b) / outer.length.toDouble();
    final width = (cornerA - cornerB).distance;

    switch (marker) {
      case FaceMarker.tongueDown:
        _arrow(canvas, bottom + Offset(0, width * 0.12), math.pi / 2,
            width * 0.55, '');
        _label(canvas, bottom + Offset(width * 0.8, width * 0.25), '往下伸');
      case FaceMarker.tongueUp:
        _arrow(canvas, top - Offset(0, width * 0.1), -math.pi / 2,
            width * 0.35, '');
        _label(canvas, top + Offset(width * 0.8, -width * 0.45), '往上伸');
      case FaceMarker.tongueSides:
        final (screenLeft, screenRight) = cornerA.dx < cornerB.dx
            ? (cornerA, cornerB)
            : (cornerB, cornerA);
        _arrow(canvas, screenLeft - Offset(width * 0.1, 0), math.pi,
            width * 0.45, '');
        _arrow(canvas, screenRight + Offset(width * 0.1, 0), 0, width * 0.45,
            '');
        _label(canvas, center + Offset(0, width * 0.5), '往左右伸');
      case FaceMarker.tongueCircleClockwise ||
            FaceMarker.tongueCircleCounterclockwise:
        final clockwise = marker == FaceMarker.tongueCircleClockwise;
        final oval = Rect.fromCenter(
          center: center,
          width: width * 1.5,
          height: math.max((bottom - top).distance * 1.7, width * 0.8),
        );
        _orbit(canvas, oval, pulse * 2 * math.pi, clockwise: clockwise);
        _label(canvas, Offset(center.dx, oval.bottom + 10),
            clockwise ? '順時針' : '逆時針');
      default:
        return;
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

  void _ring(Canvas canvas, Offset center, double radius) {
    final r = radius * (1 + 0.12 * math.sin(pulse * 2 * math.pi));
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = Colors.black.withValues(alpha: 0.4),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = kAccentGreen,
    );
  }

  void _dot(Canvas canvas, Offset center, double radius, {required bool active}) {
    final r = active ? radius * 1.35 : radius;
    canvas.drawCircle(
        center, r + 2, Paint()..color = Colors.black.withValues(alpha: 0.4));
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = active ? kAccentGreen : Colors.white.withValues(alpha: 0.85),
    );
  }

  void _orbit(Canvas canvas, Rect oval, double phase,
      {double strokeWidth = 5, bool clockwise = true}) {
    final turn = clockwise ? 1.0 : -1.0;
    final start = phase * turn;
    final sweep = math.pi * 1.5 * turn;
    final arc = Path()..addArc(oval, start, sweep);
    canvas.drawPath(
      arc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 3
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.4),
    );
    canvas.drawPath(
      arc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = kAccentGreen,
    );

    final end = start + sweep;
    final rx = oval.width / 2;
    final ry = oval.height / 2;
    final tip = oval.center + Offset(rx * math.cos(end), ry * math.sin(end));
    final tangent =
        Offset(-rx * math.sin(end), ry * math.cos(end)) * turn;
    if (tangent.distance == 0) return;
    final dir = tangent / tangent.distance;
    final normal = Offset(-dir.dy, dir.dx);
    final head = strokeWidth * 3;
    final headPath = Path()
      ..moveTo(tip.dx + dir.dx * head, tip.dy + dir.dy * head)
      ..lineTo(tip.dx + normal.dx * head * 0.8, tip.dy + normal.dy * head * 0.8)
      ..lineTo(tip.dx - normal.dx * head * 0.8, tip.dy - normal.dy * head * 0.8)
      ..close();
    canvas.drawPath(
      headPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: 0.4),
    );
    canvas.drawPath(headPath, Paint()..color = kAccentGreen);
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
