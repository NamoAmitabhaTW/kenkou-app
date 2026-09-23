import 'dart:math' as math;

import '../../../core/voice/syllable.dart';

enum Tile { wall, floor, coin, power }

enum MoveDirection {
  up(dx: 0, dy: -1, syllable: Syllable.ra, label: '往上移動', short: '往上', arrow: '↑'),
  left(dx: -1, dy: 0, syllable: Syllable.pa, label: '往左移動', short: '往左', arrow: '←'),
  right(dx: 1, dy: 0, syllable: Syllable.ta, label: '往右移動', short: '往右', arrow: '→'),
  down(dx: 0, dy: 1, syllable: Syllable.ka, label: '往下移動', short: '往下', arrow: '↓');

  const MoveDirection({
    required this.dx,
    required this.dy,
    required this.syllable,
    required this.label,
    required this.short,
    required this.arrow,
  });

  final int dx;
  final int dy;

  final Syllable syllable;

  final String label;

  final String short;

  final String arrow;

  String get word => syllable.label;

  MoveDirection get opposite => switch (this) {
        MoveDirection.up => MoveDirection.down,
        MoveDirection.down => MoveDirection.up,
        MoveDirection.left => MoveDirection.right,
        MoveDirection.right => MoveDirection.left,
      };

  double get angle => switch (this) {
        MoveDirection.right => 0,
        MoveDirection.down => math.pi / 2,
        MoveDirection.left => math.pi,
        MoveDirection.up => -math.pi / 2,
      };
}

final kDirectionBySyllable = <Syllable, MoveDirection>{
  for (final direction in MoveDirection.values) direction.syllable: direction,
};

const kDefaultMaze = <String>[
  '###############',
  '#o....#.#....o#',
  '#.###.#.#.###.#',
  '#.............#',
  '#.###.###.###.#',
  '#...#.....#...#',
  '###.#.###.#.###',
  '#.....# #.....#',
  '###.#.###.#.###',
  '#...#.....#...#',
  '#.###.###.###.#',
  '#.............#',
  '#.###.#.#.###.#',
  '#o..#.#.#.#..o#',
  '###.#.#.#.#.###',
  '#......P......#',
  '###############',
];

const kCoinScore = 10;
const kPowerScore = 50;

class MazeGame {
  MazeGame({
    List<String> layout = kDefaultMaze,
    this.cellsPerSecond = 3,
    this.cellsPerCommand = 2,
  })  : width = layout.first.length,
        height = layout.length {
    var start = const _Point(1, 1);
    for (var row = 0; row < height; row++) {
      final line = layout[row];
      assert(line.length == width, '第 $row 列長度跟其他列不一樣');
      final tiles = <Tile>[];
      for (var col = 0; col < width; col++) {
        switch (line[col]) {
          case '#':
            tiles.add(Tile.wall);
          case '.':
            tiles.add(Tile.coin);
            _coinsLeft++;
          case 'o':
            tiles.add(Tile.power);
            _coinsLeft++;
          case 'P':
            tiles.add(Tile.floor);
            start = _Point(col, row);
          default:
            tiles.add(Tile.floor);
        }
      }
      _tiles.add(tiles);
    }
    _col = start.x;
    _row = start.y;
    _collect();
  }

  final int width;
  final int height;

  final double cellsPerSecond;

  final int cellsPerCommand;

  int _cellsLeft = 0;

  final _tiles = <List<Tile>>[];

  int _col = 1;
  int _row = 1;

  MoveDirection? _moving;

  MoveDirection? _queued;

  double _progress = 0;

  MoveDirection _facing = MoveDirection.right;

  int _coinsLeft = 0;
  int _coinsEaten = 0;
  int _score = 0;

  double get x => _col + (_moving?.dx ?? 0) * _progress;
  double get y => _row + (_moving?.dy ?? 0) * _progress;

  MoveDirection get facing => _facing;

  bool get isMoving => _moving != null;
  MoveDirection? get queued => _queued;

  int get coinsEaten => _coinsEaten;
  int get coinsLeft => _coinsLeft;
  int get score => _score;
  bool get cleared => _coinsLeft == 0;

  Tile tileAt(int col, int row) {
    if (col < 0 || col >= width || row < 0 || row >= height) return Tile.wall;
    return _tiles[row][col];
  }

  bool isWall(int col, int row) => tileAt(col, row) == Tile.wall;

  void turn(MoveDirection direction) {
    final moving = _moving;

    if (moving != null && direction == moving.opposite && _progress > 0) {
      _col += moving.dx;
      _row += moving.dy;
      _progress = 1 - _progress;
      _moving = direction;
      _facing = direction;
      _queued = null;
      _cellsLeft = cellsPerCommand;
      return;
    }

    if (_progress == 0 && _canEnter(direction)) {
      _moving = direction;
      _facing = direction;
      _queued = null;
      _cellsLeft = cellsPerCommand;
      return;
    }

    _queued = direction;
  }

  void update(double dt) {
    var remaining = dt * cellsPerSecond;
    while (remaining > 0) {
      final moving = _moving;
      if (moving == null) return;

      final step = math.min(remaining, 1 - _progress);
      _progress += step;
      remaining -= step;
      if (_progress < 1) return;

      _col += moving.dx;
      _row += moving.dy;
      _progress = 0;
      _collect();
      _decideAtCenter(moving);
    }
  }

  void _decideAtCenter(MoveDirection moving) {
    final queued = _queued;
    if (queued != null && _canEnter(queued)) {
      _queued = null;
      _moving = queued;
      _facing = queued;
      _cellsLeft = cellsPerCommand;
      return;
    }
    _cellsLeft--;
    if (_cellsLeft <= 0 || !_canEnter(moving)) _moving = null;
  }

  bool _canEnter(MoveDirection direction) =>
      !isWall(_col + direction.dx, _row + direction.dy);

  void _collect() {
    final tile = _tiles[_row][_col];
    if (tile != Tile.coin && tile != Tile.power) return;
    _tiles[_row][_col] = Tile.floor;
    _coinsLeft--;
    _coinsEaten++;
    _score += tile == Tile.power ? kPowerScore : kCoinScore;
  }
}

class _Point {
  const _Point(this.x, this.y);
  final int x;
  final int y;
}
