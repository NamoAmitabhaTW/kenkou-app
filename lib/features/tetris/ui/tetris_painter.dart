import 'package:flutter/material.dart';

import '../domain/tetris_game.dart';

const kTetrisBackground = Color(0xFF0B0E14);
const kTetrisGrid = Color(0xFF1B2130);

/// 七種方塊各一個顏色。
///
/// 挑的是彼此差很多、在深色底上都夠亮的顏色 —— 長輩要一眼看出「這一塊是什麼形狀」,
/// 相鄰兩塊顏色像的話,堆起來就看不出接縫在哪。
const kPieceColors = <Tetromino, Color>{
  Tetromino.i: Color(0xFF4DD0E1),
  Tetromino.o: Color(0xFFFFD54F),
  Tetromino.t: Color(0xFFBA68C8),
  Tetromino.s: Color(0xFF81C784),
  Tetromino.z: Color(0xFFE57373),
  Tetromino.j: Color(0xFF7986CB),
  Tetromino.l: Color(0xFFFFB74D),
};

/// 把盤面畫出來。已經落地的格子、正在掉的那一塊,畫法一樣。
class TetrisPainter extends CustomPainter {
  const TetrisPainter({required this.game});

  final TetrisGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = _cellSize(size);
    final board = Size(cell * game.columns, cell * game.rows);
    canvas.save();
    // 盤面置中,左右留白平均。
    canvas.translate((size.width - board.width) / 2,
        (size.height - board.height) / 2);

    canvas.drawRect(
        Offset.zero & board, Paint()..color = kTetrisBackground);
    _paintGrid(canvas, cell);

    final clearing = game.clearingRows.toSet();
    for (var row = 0; row < game.rows; row++) {
      // 正在消掉的那幾列改畫動畫,原本的格子不畫。
      if (clearing.contains(row)) continue;
      for (var col = 0; col < game.columns; col++) {
        final piece = game.settledAt(col, row);
        if (piece != null) _paintCell(canvas, cell, col, row, piece);
      }
    }
    for (final row in clearing) {
      _paintClearing(canvas, cell, row, game.clearProgress);
    }
    for (final (col, row) in game.activeCells) {
      // 剛出生時方塊會有一部分在盤面上方,那幾格不用畫。
      if (row < 0) continue;
      _paintCell(canvas, cell, col, row, game.piece);
    }
    canvas.restore();
  }

  double _cellSize(Size size) {
    final byWidth = size.width / game.columns;
    final byHeight = size.height / game.rows;
    return byWidth < byHeight ? byWidth : byHeight;
  }

  void _paintGrid(Canvas canvas, double cell) {
    final paint = Paint()
      ..color = kTetrisGrid
      ..strokeWidth = 1;
    for (var c = 1; c < game.columns; c++) {
      canvas.drawLine(Offset(c * cell, 0), Offset(c * cell, cell * game.rows),
          paint);
    }
    for (var r = 1; r < game.rows; r++) {
      canvas.drawLine(Offset(0, r * cell), Offset(cell * game.columns, r * cell),
          paint);
    }
  }

  /// 消行動畫:整列閃成白色,同時往中線收合再淡出。
  ///
  /// 用「收合」而不是單純淡出 —— 收合看得出「這一列不見了、上面要掉下來」,
  /// 淡出只看得出「顏色變淡」。長輩要能看懂發生了什麼事。
  void _paintClearing(Canvas canvas, double cell, int row, double t) {
    final height = cell * (1 - t);
    if (height <= 0) return;
    final rect = Rect.fromLTWH(
      0,
      row * cell + (cell - height) / 2,
      cell * game.columns,
      height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1.5), Radius.circular(cell * 0.18)),
      Paint()..color = Colors.white.withValues(alpha: 0.9 * (1 - t * 0.4)),
    );
  }

  void _paintCell(
      Canvas canvas, double cell, int col, int row, Tetromino piece) {
    final color = kPieceColors[piece]!;
    final rect = Rect.fromLTWH(col * cell, row * cell, cell, cell).deflate(1.5);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18));
    canvas.drawRRect(rrect, Paint()..color = color);
    // 內側再畫一圈亮邊,格子跟格子之間才分得出來。
    canvas.drawRRect(
      rrect.deflate(cell * 0.14),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(TetrisPainter old) => true;
}
