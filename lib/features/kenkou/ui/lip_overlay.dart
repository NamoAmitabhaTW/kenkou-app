import 'package:face_mesh/face_mesh.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';

/// 疊在相機預覽上的嘴唇輪廓。
///
/// 只畫使用者自己的外唇一條線,做對時轉綠。原本還有一個「目標框」橢圓,
/// 對長者來說兩條線疊在一起反而看不懂哪條是自己的嘴,拿掉了。
class LipOverlayPainter extends CustomPainter {
  const LipOverlayPainter({required this.frame, required this.matched});

  final FaceFrame frame;

  /// 目前是否已達標。達標時輪廓轉綠。
  final bool matched;


  @override
  void paint(Canvas canvas, Size size) {
    final outer = frame.outerLip;
    if (!frame.hasFace || outer.isEmpty) return;

    final projection = FaceMeshProjection(imageSize: frame.imageSize, viewSize: size);
    final path = Path()..addPolygon(outer.map(projection.project).toList(growable: false), true);

    // 外圈描一層半透明黑,不然淺色背景(牆壁、窗戶)下亮色線會整條消失。
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
