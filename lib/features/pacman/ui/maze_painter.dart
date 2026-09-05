import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/maze.dart';

/// 街機的配色,直接照原版:牆是藍色、金幣是米色、小精靈是黃色。
const kMazeWall = Color(0xFF2121DE);
const kMazeBackground = Color(0xFF000000);
const kCoinColor = Color(0xFFFFB8AE);
const kPacmanColor = Color(0xFFFFE600);

/// 把迷宮畫出來。沒有怪物 —— 這個遊戲只有吃金幣。
class MazePainter extends CustomPainter {
  const MazePainter({
    required this.game,
    required this.mouth,
    required this.pulse,
  });

  final MazeGame game;

  /// 嘴巴張多開,0(閉起來)~1(張到最大)。
  final double mouth;

  /// 大金幣的呼吸,0~1。
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width / game.width, size.height / game.height);
    final origin = Offset(
      (size.width - cell * game.width) / 2,
      (size.height - cell * game.height) / 2,
    );

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    _paintWalls(canvas, cell);
    _paintCoins(canvas, cell);
    _paintPacman(canvas, cell);
    canvas.restore();
  }

  /// 牆畫成「管線」:把相鄰的牆格中心連起來,先描一條粗的藍線,
  /// 再用背景色描一條細的蓋在正中間,就變成原版那種雙線外框。
  void _paintWalls(Canvas canvas, double cell) {
    final path = Path();
    for (var row = 0; row < game.height; row++) {
      for (var col = 0; col < game.width; col++) {
        if (!game.isWall(col, row)) continue;
        final center = Offset((col + 0.5) * cell, (row + 0.5) * cell);
        var joined = false;
        // 只看右邊和下面,每條邊才不會畫兩次。界外不算牆 ——
        // `isWall` 對界外回傳 true(給走位判定用的),照著連會把線畫到畫布外面。
        for (final step in const [Offset(1, 0), Offset(0, 1)]) {
          final nextCol = col + step.dx.toInt();
          final nextRow = row + step.dy.toInt();
          if (!_inside(nextCol, nextRow) || !game.isWall(nextCol, nextRow)) continue;
          path.moveTo(center.dx, center.dy);
          path.lineTo(center.dx + step.dx * cell, center.dy + step.dy * cell);
          joined = true;
        }
        if (joined) continue;
        // 孤零零一格的牆,連不到任何鄰居,自己畫成一個點。
        if (_wallInside(col - 1, row) || _wallInside(col, row - 1)) continue;
        path.moveTo(center.dx, center.dy);
        path.lineTo(center.dx, center.dy);
      }
    }

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = kMazeWall
      ..strokeWidth = cell * 0.62;
    final hollow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = kMazeBackground
      ..strokeWidth = cell * 0.30;

    canvas.drawPath(path, outline);
    canvas.drawPath(path, hollow);
  }

  bool _inside(int col, int row) =>
      col >= 0 && col < game.width && row >= 0 && row < game.height;

  bool _wallInside(int col, int row) => _inside(col, row) && game.isWall(col, row);

  void _paintCoins(Canvas canvas, double cell) {
    final paint = Paint()..color = kCoinColor;
    for (var row = 0; row < game.height; row++) {
      for (var col = 0; col < game.width; col++) {
        final tile = game.tileAt(col, row);
        if (tile != Tile.coin && tile != Tile.power) continue;
        final center = Offset((col + 0.5) * cell, (row + 0.5) * cell);
        final radius = tile == Tile.power
            ? cell * (0.20 + 0.05 * pulse)
            : cell * 0.10;
        canvas.drawCircle(center, radius, paint);
      }
    }
  }

  void _paintPacman(Canvas canvas, double cell) {
    final center = Offset((game.x + 0.5) * cell, (game.y + 0.5) * cell);
    final radius = cell * 0.44;

    // 嘴巴的半角。張到最大約 40 度,再大就不像圓的了。
    final half = mouth * 0.22 * math.pi;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(game.facing.angle);
    if (half < 0.01) {
      canvas.drawCircle(Offset.zero, radius, Paint()..color = kPacmanColor);
    } else {
      final path = Path()
        ..moveTo(0, 0)
        ..arcTo(
          Rect.fromCircle(center: Offset.zero, radius: radius),
          half,
          2 * math.pi - 2 * half,
          false,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = kPacmanColor);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MazePainter oldDelegate) => true;
}
