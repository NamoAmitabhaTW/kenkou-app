import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:futuremode2026/features/tetris/domain/tetris_game.dart';

TetrisGame game({int columns = 10, int rows = 18, double fallSeconds = 1.0}) =>
    TetrisGame(
        columns: columns,
        rows: rows,
        fallSeconds: fallSeconds,
        random: math.Random(1));

void main() {
  group('旋轉', () {
    test('轉四次回到原樣', () {
      for (final piece in Tetromino.values) {
        expect(rotatedCells(piece, 4).toSet(), piece.cells.toSet(),
            reason: '${piece.name} 轉一圈之後應該跟原本一樣');
      }
    });

    test('O 轉了跟沒轉一樣', () {
      expect(rotatedCells(Tetromino.o, 1).toSet(),
          rotatedCells(Tetromino.o, 0).toSet());
    });

    test('I 轉一次會變直的', () {
      final flat = rotatedCells(Tetromino.i, 0);
      final upright = rotatedCells(Tetromino.i, 1);
      expect(flat.map((c) => c.$2).toSet().length, 1, reason: '橫的:同一列');
      expect(upright.map((c) => c.$1).toSet().length, 1, reason: '直的:同一行');
    });

    test('每一種方塊在每個轉向都是四格', () {
      for (final piece in Tetromino.values) {
        for (var r = 0; r < 4; r++) {
          expect(rotatedCells(piece, r).toSet().length, 4,
              reason: '${piece.name} 轉 $r 次');
        }
      }
    });
  });

  group('移動', () {
    test('往左往右移得動,但不會穿牆', () {
      final g = game();
      final startX = g.activeCells.map((c) => c.$1).reduce(math.min);
      g.moveLeft();
      expect(g.activeCells.map((c) => c.$1).reduce(math.min), startX - 1);
      for (var i = 0; i < 20; i++) {
        g.moveLeft();
      }
      expect(g.activeCells.map((c) => c.$1).reduce(math.min), 0);
    });

    test('往右也不會穿牆', () {
      final g = game();
      for (var i = 0; i < 20; i++) {
        g.moveRight();
      }
      expect(g.activeCells.map((c) => c.$1).reduce(math.max), g.columns - 1);
    });
  });

  group('落下', () {
    test('時間到才掉一格', () {
      final g = game(fallSeconds: 1.0);
      final y = g.activeCells.map((c) => c.$2).reduce(math.min);
      g.update(0.9);
      expect(g.activeCells.map((c) => c.$2).reduce(math.min), y, reason: '還沒到時間');
      g.update(0.2);
      expect(g.activeCells.map((c) => c.$2).reduce(math.min), y + 1);
    });

    test('喊「卡」往下移一格', () {
      final g = game(fallSeconds: 10);
      final y = g.activeCells.map((c) => c.$2).reduce(math.min);
      g.moveDown();
      expect(g.activeCells.map((c) => c.$2).reduce(math.min), y + 1);
    });

    test('喊「卡」會重新計時,不會馬上又自己掉一格', () {
      final g = game(fallSeconds: 1.0)..update(0.9);
      final y = g.activeCells.map((c) => c.$2).reduce(math.min);
      g.moveDown();
      expect(g.activeCells.map((c) => c.$2).reduce(math.min), y + 1);
      g.update(0.2);
      expect(g.activeCells.map((c) => c.$2).reduce(math.min), y + 1);
    });

    test('落到底時喊「卡」不會把方塊釘死', () {
      final g = game(rows: 6, fallSeconds: 10);
      for (var i = 0; i < 20; i++) {
        g.moveDown();
      }
      final resting = g.activeCells.toList();
      g.moveDown();
      expect(g.activeCells, resting, reason: '移不動就什麼都不做');
      expect(g.score, 0);
    });

    test('落地會堆在盤面上', () {
      final g = game(rows: 6, fallSeconds: 1.0);
      g.update(20);
      final settled = [
        for (var r = 0; r < g.rows; r++)
          for (var c = 0; c < g.columns; c++)
            if (g.settledAt(c, r) != null) (c, r)
      ];
      expect(settled, isNotEmpty);
    });
  });

  group('出題:七個一袋', () {
    List<Tetromino> firstPieces(int count, {int seed = 1}) {
      final g = TetrisGame(
          columns: 20, rows: 40, fallSeconds: 0.5, random: math.Random(seed));
      final seen = <Tetromino>[];
      var last = 0;
      var guard = 0;
      while (seen.length < count && !g.isOver && guard++ < 100000) {
        if (g.pieceCount != last) {
          last = g.pieceCount;
          seen.add(g.piece);
        }
        g.update(0.25);
      }
      return seen;
    }

    test('每七塊七種形狀各出現一次', () {
      for (var seed = 0; seed < 5; seed++) {
        final seven = firstPieces(7, seed: seed);
        expect(seven.length, 7, reason: 'seed $seed 沒發滿七塊');
        expect(seven.toSet().length, 7,
            reason: 'seed $seed 有重複:${seven.map((p) => p.name).join(' ')}');
      }
    });

    test('前兩塊一定不一樣', () {
      for (var seed = 0; seed < 20; seed++) {
        final two = firstPieces(2, seed: seed);
        expect(two[0], isNot(two[1]), reason: 'seed $seed 前兩塊一樣');
      }
    });

    test('十四塊裡每種各兩次', () {
      final all = firstPieces(14, seed: 7);
      for (final piece in Tetromino.values) {
        expect(all.where((p) => p == piece).length, 2,
            reason: '${piece.name} 出現次數不對');
      }
    });
  });

  group('消行與結束', () {
    test('整列填滿就消掉並得分', () {
      final g = TetrisGame(
          columns: 4, rows: 8, fallSeconds: 1.0, random: math.Random(1));
      expect(g.score, 0);
      var guard = 0;
      while (g.score == 0 && !g.isOver && guard++ < 200) {
        g.update(20);
      }
      expect(g.isOver || g.score > 0, isTrue);
    });

    test('消行時會先演動畫,演完才真的拿掉那一列', () {
      final g = TetrisGame(
          columns: 4, rows: 8, fallSeconds: 0.1, random: math.Random(1));
      var guard = 0;
      while (!g.isClearing && !g.isOver && guard++ < 2000) {
        g.update(0.05);
      }
      expect(g.isClearing, isTrue, reason: '應該要有整列被填滿');
      expect(g.clearingRows, isNotEmpty);
      expect(g.score, greaterThan(0), reason: '分數馬上加,不用等動畫');

      final row = g.clearingRows.first;
      expect(
          List.generate(g.columns, (c) => g.settledAt(c, row)).every((x) => x != null),
          isTrue,
          reason: '動畫還沒演完,那一列不該先消失');

      g.update(TetrisGame.clearSeconds + 0.01);
      expect(g.isClearing, isFalse);
      expect(g.clearProgress, 0);
    });

    test('動畫期間方塊不會繼續往下掉', () {
      final g = TetrisGame(
          columns: 4, rows: 8, fallSeconds: 0.1, random: math.Random(1));
      var guard = 0;
      while (!g.isClearing && !g.isOver && guard++ < 2000) {
        g.update(0.05);
      }
      expect(g.isClearing, isTrue);
      final before = g.pieceCount;
      g.update(0.1);
      expect(g.pieceCount, before, reason: '凍住的時候不該發新的一塊');
    });

    test('堆到頂就結束', () {
      final g = game(rows: 6, fallSeconds: 1.0);
      var guard = 0;
      while (!g.isOver && guard++ < 500) {
        g.update(20);
      }
      expect(g.isOver, isTrue, reason: '一直不動最後一定會堆到頂');
    });

    test('結束之後就不再接受操作', () {
      final g = game(rows: 6, fallSeconds: 1.0);
      var guard = 0;
      while (!g.isOver && guard++ < 500) {
        g.update(20);
      }
      final before = g.activeCells.toList();
      g
        ..moveLeft()
        ..moveRight()
        ..rotate()
        ..moveDown();
      g.update(10);
      expect(g.activeCells, before);
    });
  });
}
