import 'dart:math' as math;

import '../../../core/voice/syllable.dart';

/// 迷宮裡的一格是什麼。
enum Tile { wall, floor, coin, power }

/// 小精靈能走的四個方向,以及要念哪個音才會往那邊走。
///
/// 四個音就是健口操在練的那四個,辨識器(`PatakaDetector`)也只認得這四個。
/// 顯示的字直接取自 [Syllable.label] —— 兩邊共用同一份標示,不會各自漂移。
enum MoveDirection {
  up(dx: 0, dy: -1, syllable: Syllable.pa, label: '往上移動', short: '往上', arrow: '↑'),
  left(dx: -1, dy: 0, syllable: Syllable.ta, label: '往左移動', short: '往左', arrow: '←'),
  right(dx: 1, dy: 0, syllable: Syllable.ka, label: '往右移動', short: '往右', arrow: '→'),
  down(dx: 0, dy: 1, syllable: Syllable.ra, label: '往下移動', short: '往下', arrow: '↓');

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

  /// 念哪個音會往這個方向走。
  final Syllable syllable;

  final String label;

  /// 遊戲畫面的對照表用的短標。四個字排成表格會太擠。
  final String short;

  final String arrow;

  /// 要念的字。跟健口操同一份,改一處兩邊都會跟著改。
  String get word => syllable.label;

  MoveDirection get opposite => switch (this) {
        MoveDirection.up => MoveDirection.down,
        MoveDirection.down => MoveDirection.up,
        MoveDirection.left => MoveDirection.right,
        MoveDirection.right => MoveDirection.left,
      };

  /// 畫小精靈時把嘴巴轉到這個方向,弧度。
  double get angle => switch (this) {
        MoveDirection.right => 0,
        MoveDirection.down => math.pi / 2,
        MoveDirection.left => math.pi,
        MoveDirection.up => -math.pi / 2,
      };
}

/// 聽到的音節 → 往哪走。從 [MoveDirection.syllable] 反推,對應關係只定義一次。
final kDirectionBySyllable = <Syllable, MoveDirection>{
  for (final direction in MoveDirection.values) direction.syllable: direction,
};

/// 預設迷宮:15 x 17,左右對稱,所有金幣都走得到(見 test/pacman_maze_test.dart)。
///
/// 比街機的 28 x 31 小很多 —— 限時 30 秒,地圖太大只會逛到一個角落就結束。
/// `#` 牆、`.` 金幣、`o` 大金幣、` ` 空地、`P` 小精靈的起點。
/// 正中央那格是圍死的空地,牆才會畫成街機那種中空的方盒子(原版的鬼屋)。
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

/// 一顆金幣 / 一顆大金幣的分數。
const kCoinScore = 10;
const kPowerScore = 50;

/// 吃金幣遊戲的規則,純 Dart 不碰 UI —— 走位、轉彎、吃金幣全部在這裡,
/// 頁面只負責把 [x] / [y] 畫出來,以及把聽到的音節轉成 [turn]。
///
/// 念一次走 [cellsPerCommand] 格就停下來等下一個指令。
///
/// 早期是「一路走到底」,但地圖左右兩端上方都是牆 —— 從起點喊「卡」或「踏」
/// 走到底都會卡進死角,只剩掉頭一條路。改成固定格數之後,小精靈停著等你,
/// 語音辨識慢半拍就不再是「錯過路口」而只是「慢一點才動」。
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
    // 站上去的那一格也算吃到。金幣只在「走到某一格的中央」時結算,
    // 起點沒人走進去過,不補這一下就會永遠留一顆吃不掉。
    _collect();
  }

  final int width;
  final int height;

  /// 一秒走幾格。
  final double cellsPerSecond;

  /// 念一次走幾格。
  final int cellsPerCommand;

  /// 這個指令還剩幾格可以走。走完歸零就停下來。
  int _cellsLeft = 0;

  final _tiles = <List<Tile>>[];

  int _col = 1;
  int _row = 1;

  /// 正在往哪走。null = 停住(撞牆或還沒開始)。
  MoveDirection? _moving;

  /// 已經下了、但現在還轉不過去的指令。留著不丟:在直的通道裡先喊「卡」,
  /// 走到第一個有路口的地方就會右轉 —— 對反應慢的人比較友善,街機也是這樣。
  MoveDirection? _queued;

  /// 往 [_moving] 那一格走了多少,0~1。
  double _progress = 0;

  MoveDirection _facing = MoveDirection.right;

  int _coinsLeft = 0;
  int _coinsEaten = 0;
  int _score = 0;

  /// 目前位置,格為單位(可以是小數,格子之間是滑過去的)。
  double get x => _col + (_moving?.dx ?? 0) * _progress;
  double get y => _row + (_moving?.dy ?? 0) * _progress;

  /// 嘴巴朝哪邊。停下來也保留上一次的方向,不然會轉回預設的右邊。
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

  /// 下一個指令。停在格子中央又走得過去就馬上出發,否則排隊等到下一個路口。
  void turn(MoveDirection direction) {
    final moving = _moving;

    // 迴轉不必等路口:人在通道中間喊「回去」,當場掉頭最直覺。
    // 位置不動,只是把「從哪一格往哪一格」反過來寫。
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

  /// 推進 [dt] 秒。
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

  /// 只有走到格子正中央才換方向 —— 中途轉彎會穿牆。
  void _decideAtCenter(MoveDirection moving) {
    final queued = _queued;
    if (queued != null && _canEnter(queued)) {
      _queued = null;
      _moving = queued;
      _facing = queued;
      // 排隊的是一個新指令,額度重新算。
      _cellsLeft = cellsPerCommand;
      return;
    }
    // 剛走完一格,扣一格額度;扣完或撞牆就停。
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
