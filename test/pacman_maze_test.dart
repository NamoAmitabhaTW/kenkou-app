import 'package:flutter_test/flutter_test.dart';
import 'package:futuremode2026/core/voice/syllable.dart';
import 'package:futuremode2026/features/pacman/domain/maze.dart';

void main() {
  group('迷宮地圖', () {
    test('每一列一樣長,而且左右對稱', () {
      final width = kDefaultMaze.first.length;
      for (final line in kDefaultMaze) {
        expect(line.length, width);
        expect(line.split('').reversed.join(), line, reason: line);
      }
    });

    test('四周是牆,走不出去', () {
      final game = MazeGame();
      for (var col = 0; col < game.width; col++) {
        expect(game.isWall(col, 0), isTrue);
        expect(game.isWall(col, game.height - 1), isTrue);
      }
      for (var row = 0; row < game.height; row++) {
        expect(game.isWall(0, row), isTrue);
        expect(game.isWall(game.width - 1, row), isTrue);
      }
    });

    test('每一顆金幣都從起點走得到', () {
      final game = MazeGame();
      final reachable = <int>{};
      final stack = <int>[_key(game, game.x.toInt(), game.y.toInt())];
      reachable.add(stack.first);
      while (stack.isNotEmpty) {
        final at = stack.removeLast();
        final col = at % game.width;
        final row = at ~/ game.width;
        for (final direction in MoveDirection.values) {
          final nextCol = col + direction.dx;
          final nextRow = row + direction.dy;
          if (game.isWall(nextCol, nextRow)) continue;
          final key = _key(game, nextCol, nextRow);
          if (reachable.add(key)) stack.add(key);
        }
      }

      for (var row = 0; row < game.height; row++) {
        for (var col = 0; col < game.width; col++) {
          final tile = game.tileAt(col, row);
          if (tile != Tile.coin && tile != Tile.power) continue;
          expect(reachable.contains(_key(game, col, row)), isTrue,
              reason: '($col, $row) 的金幣走不到');
        }
      }
    });

    test('起點站得住,而且金幣數量跟地圖上畫的一樣', () {
      final game = MazeGame();
      expect(game.isWall(game.x.toInt(), game.y.toInt()), isFalse);
      final drawn = kDefaultMaze
          .expand((line) => line.split(''))
          .where((c) => c == '.' || c == 'o')
          .length;
      expect(game.coinsLeft, drawn);
    });
  });

  group('走位', () {
    const corridor = [
      '#####',
      '#...#',
      '#.#.#',
      '#...#',
      '#####',
    ];
    MazeGame corridorGame({int cellsPerCommand = 2}) => MazeGame(
        layout: corridor, cellsPerSecond: 1, cellsPerCommand: cellsPerCommand);

    test('停著不動的時候不會自己走', () {
      final game = corridorGame();
      final (x, y) = (game.x, game.y);
      game.update(5);
      expect(game.x, x);
      expect(game.y, y);
      expect(game.isMoving, isFalse);
    });

    test('念一次走設定的格數就停', () {
      final game = corridorGame()..turn(MoveDirection.right);
      game.update(10);
      expect(game.x, 3);
      expect(game.y, 1);
      expect(game.isMoving, isFalse);
    });

    test('一格模式念一次只走一格', () {
      final game = corridorGame(cellsPerCommand: 1)..turn(MoveDirection.right);
      game.update(10);
      expect(game.x, 2);
      expect(game.isMoving, isFalse);
    });

    test('格數還沒走完就撞牆的話,撞到就停', () {
      final game = corridorGame(cellsPerCommand: 3)..turn(MoveDirection.right);
      game.update(10);
      expect(game.x, 3);
      expect(game.isMoving, isFalse);
    });

    test('走過去的路上金幣會被吃掉,而且只算一次', () {
      final game = corridorGame();
      final total = game.coinsLeft + game.coinsEaten;
      game.turn(MoveDirection.right);
      game.update(10);
      expect(game.coinsEaten, 3);
      expect(game.coinsLeft, total - 3);
      expect(game.score, 3 * kCoinScore);

      game.turn(MoveDirection.left);
      game.update(10);
      expect(game.coinsEaten, 3);
    });

    test('轉不過去的指令會排隊,到得了的路口才轉', () {
      final game = corridorGame()..turn(MoveDirection.right);
      game.update(0.5);
      game.turn(MoveDirection.down);
      expect(game.queued, MoveDirection.down);
      game.update(10);
      expect(game.x, 3);
      expect(game.y, 3);
      expect(game.queued, isNull);
    });

    test('迴轉不用等到路口,當場掉頭', () {
      final game = corridorGame()..turn(MoveDirection.right);
      game.update(0.25);
      expect(game.x, closeTo(1.25, 1e-9));
      game.turn(MoveDirection.left);
      expect(game.x, closeTo(1.25, 1e-9), reason: '掉頭不該讓位置跳掉');
      expect(game.facing, MoveDirection.left);
      game.update(0.25);
      expect(game.x, closeTo(1, 1e-9));
    });

    test('撞牆停下來之後還面著原來的方向', () {
      final game = corridorGame()..turn(MoveDirection.right);
      game.update(10);
      expect(game.isMoving, isFalse);
      expect(game.facing, MoveDirection.right);
    });

    test('往牆裡走不會動', () {
      final game = corridorGame()..turn(MoveDirection.up);
      game.update(10);
      expect(game.x, 1);
      expect(game.y, 1);
    });

    test('吃完全部金幣就算破關', () {
      final game = corridorGame();
      expect(game.cleared, isFalse);
      for (final direction in const [
        MoveDirection.right,
        MoveDirection.down,
        MoveDirection.left,
        MoveDirection.up,
      ]) {
        game.turn(direction);
        game.update(10);
      }
      expect(game.coinsEaten, 8);
      expect(game.cleared, isTrue);
    });
  });

  test('四個音節各對到一個方向,沒有重複', () {
    expect(kDirectionBySyllable.keys.toSet(), Syllable.values.toSet());
    expect(kDirectionBySyllable.values.toSet(), MoveDirection.values.toSet());
    expect(kDirectionBySyllable[Syllable.pa], MoveDirection.left);
    expect(kDirectionBySyllable[Syllable.ta], MoveDirection.right);
    expect(kDirectionBySyllable[Syllable.ka], MoveDirection.down);
    expect(kDirectionBySyllable[Syllable.ra], MoveDirection.up);
  });

  test('念的字都對得回同一個音節', () {
    for (final entry in kDirectionBySyllable.entries) {
      expect(entry.value.word, isNotEmpty);
    }
    expect(MoveDirection.left.word, '怕');
    expect(MoveDirection.right.word, '踏');
    expect(MoveDirection.down.word, '卡');
    expect(MoveDirection.up.word, '啦');
  });
}

int _key(MazeGame game, int col, int row) => row * game.width + col;
