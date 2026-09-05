import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';

/// 健口操做完之後分享用的獎狀。
///
/// 不分享影片:整套做下來影片好幾分鐘,分享前要先合成,長輩會看到轉圈轉很久。
/// 獎狀是一張 PNG,幾百毫秒就畫好。全部用 Canvas 畫,不需要圖片素材;
/// 之後要換成設計好的背景圖,把 [_drawBackground] 換成畫圖片就好。
class Certificate {
  static const _width = 1080.0;
  static const _height = 1350.0;

  static const _paper = Color(0xFFFFF8E7);
  static const _gold = Color(0xFFD4A947);
  static const _ink = Color(0xFF2B2B2B);

  /// 畫好並存成檔案,回傳路徑。
  static Future<String> render({
    required int completed,
    required int total,
    required DateTime at,
    required Directory directory,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, _width, _height));

    _drawBackground(canvas);
    _drawContent(canvas, completed: completed, total: total, at: at);

    final image = await recorder.endRecording().toImage(_width.toInt(), _height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    final stamp = at.millisecondsSinceEpoch;
    final file = File('${directory.path}/kenkou_certificate_$stamp.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    return file.path;
  }

  static void _drawBackground(Canvas canvas) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, _width, _height), Paint()..color = _paper);

    // 雙框:外粗內細,獎狀的老規矩。
    final outer = const Rect.fromLTWH(40, 40, _width - 80, _height - 80);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, const Radius.circular(24)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = kSuccessGreen,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer.deflate(22), const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _gold,
    );

    // 四個角落的小花飾。
    for (final corner in [
      outer.topLeft + const Offset(48, 48),
      outer.topRight + const Offset(-48, 48),
      outer.bottomLeft + const Offset(48, -48),
      outer.bottomRight + const Offset(-48, -48),
    ]) {
      _drawFlourish(canvas, corner);
    }
  }

  static void _drawFlourish(Canvas canvas, Offset center) {
    final paint = Paint()..color = _gold;
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawCircle(center + Offset(math.cos(angle), math.sin(angle)) * 14, 5, paint);
    }
    canvas.drawCircle(center, 7, Paint()..color = kSuccessGreen);
  }

  static void _drawContent(
    Canvas canvas, {
    required int completed,
    required int total,
    required DateTime at,
  }) {
    _text(canvas, '健口操', 120, const TextStyle(fontSize: 54, fontWeight: FontWeight.w800, color: kBrandGreen, letterSpacing: 12));
    _text(canvas, '完 成 證 書', 200, const TextStyle(fontSize: 96, fontWeight: FontWeight.w900, color: kSuccessGreen));

    // 標題底下一條金線。
    canvas.drawLine(
      const Offset(240, 340),
      const Offset(_width - 240, 340),
      Paint()
        ..color = _gold
        ..strokeWidth = 4,
    );

    // 獎章:大圓 + 完成數。
    const medalCenter = Offset(_width / 2, 600);
    canvas.drawCircle(medalCenter, 190, Paint()..color = kSuccessGreen);
    canvas.drawCircle(
      medalCenter,
      170,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = _gold,
    );
    _text(canvas, '$completed', 500, const TextStyle(fontSize: 170, fontWeight: FontWeight.w900, color: Colors.white, height: 1));
    _text(canvas, '個動作', 690, const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Colors.white));

    _text(canvas, '今天完成了 $completed / $total 個口腔體操動作', 850,
        const TextStyle(fontSize: 46, fontWeight: FontWeight.w800, color: _ink));
    _text(canvas, '嘴巴、舌頭、臉頰都動過了', 920, const TextStyle(fontSize: 36, color: Color(0xFF666666)));

    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${at.year} 年 ${at.month} 月 ${at.day} 日  ${two(at.hour)}:${two(at.minute)}';
    _text(canvas, date, 1060, const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: _ink));

    _text(canvas, '今天的我也健康', 1170, const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: kBrandGreen, letterSpacing: 6));
  }

  static void _text(Canvas canvas, String text, double top, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: _width - 160);
    painter.paint(canvas, Offset((_width - painter.width) / 2, top));
  }
}
