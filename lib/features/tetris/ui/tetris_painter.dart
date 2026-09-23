import 'package:flutter/material.dart';

import '../domain/tetris_game.dart';

const kTetrisBackground = Color(0xFF0B0E14);
const kTetrisGrid = Color(0xFF1B2130);

const kPieceColors = <Tetromino, Color>{
  Tetromino.i: Color(0xFF4DD0E1),
  Tetromino.o: Color(0xFFFFD54F),
  Tetromino.t: Color(0xFFBA68C8),
  Tetromino.s: Color(0xFF81C784),
  Tetromino.z: Color(0xFFE57373),
  Tetromino.j: Color(0xFF7986CB),
  Tetromino.l: Color(0xFFFFB74D),
};

class TetrisPainter extends CustomPainter {
  const TetrisPainter({required this.game});

  final TetrisGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = _cellSize(size);
    final board = Size(cell * game.columns, cell * game.rows);
    canvas.save();
    canvas.translate((size.width - board.width) / 2,
        (size.height - board.height) / 2);

    canvas.drawRect(
        Offset.zero & board, Paint()..color = kTetrisBackground);
    _paintGrid(canvas, cell);

    final clearing = game.clearingRows.toSet();
    for (var row = 0; row < game.rows; row++) {
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
    canvas.drawRRect(
      rrect.deflate(cell * 0.14),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(TetrisPainter old) => true;
}
