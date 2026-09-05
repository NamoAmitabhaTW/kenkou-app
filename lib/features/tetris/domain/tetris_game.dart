import 'dart:math' as math;

/// 七種方塊。
///
/// [cells] 是方塊在 [box] × [box] 方框裡佔哪幾格,原點在左上。用方框而不是
/// 直接寫死四個旋轉狀態,是因為旋轉可以用同一條公式算出來(見 [rotatedCells]),
/// 少寫 28 組座標就少 28 個打錯的機會。
enum Tetromino {
  i(box: 4, cells: [(0, 1), (1, 1), (2, 1), (3, 1)]),
  o(box: 2, cells: [(0, 0), (1, 0), (0, 1), (1, 1)]),
  t(box: 3, cells: [(1, 0), (0, 1), (1, 1), (2, 1)]),
  s(box: 3, cells: [(1, 0), (2, 0), (0, 1), (1, 1)]),
  z(box: 3, cells: [(0, 0), (1, 0), (1, 1), (2, 1)]),
  j(box: 3, cells: [(0, 0), (0, 1), (1, 1), (2, 1)]),
  l(box: 3, cells: [(2, 0), (0, 1), (1, 1), (2, 1)]);

  const Tetromino({required this.box, required this.cells});

  final int box;
  final List<(int, int)> cells;
}

/// 把方塊順時針轉 [rotation] 次(每次 90 度)之後,佔哪幾格。
///
/// 在方框裡繞中心轉:(x, y) → (box - 1 - y, x)。
List<(int, int)> rotatedCells(Tetromino piece, int rotation) {
  var cells = piece.cells;
  for (var i = 0; i < rotation % 4; i++) {
    cells = [for (final (x, y) in cells) (piece.box - 1 - y, x)];
  }
  return cells;
}

/// 俄羅斯方塊的規則,純 Dart 不碰 UI。
///
/// 用語音操控,所以刻意跟一般的俄羅斯方塊不一樣:
///
/// - **掉得很慢。** 語音辨識大約慢半拍,一格掉 [fallSeconds] 秒,使用者才來得及
///   喊完、聽到反應、再決定下一步。
/// - **只有順時針一個轉向。** 四個音要分給左、右、下、轉,沒有多的音給逆時針。
///
/// 出題用「七個一袋」(7-bag):把七種形狀洗成一袋發完再洗下一袋,而不是每次
/// 都獨立亂數。純亂數會出現「連五個 L、整局沒看過直條」這種串,玩的人會覺得
/// 遊戲在跟他作對;一袋發完保證七種各出現一次,連帶也保證前兩塊一定不一樣。
class TetrisGame {
  TetrisGame({
    this.columns = 8,
    this.rows = 13,
    this.fallSeconds = 2.5,
    math.Random? random,
  })  : assert(columns >= 4),
        assert(rows >= 6),
        _random = random ?? math.Random() {
    _board = List.generate(rows, (_) => List<Tetromino?>.filled(columns, null));
    _spawn();
  }

  final int columns;
  final int rows;

  /// 正常速度下,一格要掉幾秒。
  final double fallSeconds;

  /// 一次消掉幾列各得幾分。一次消越多列越划算,跟原版一樣。
  static const _lineScore = [0, 100, 300, 500, 800];

  /// 消行動畫要演多久。這段期間方塊不落下,也不發新的一塊 ——
  /// 讓人看清楚「哪幾列消掉了」,不然分數莫名其妙就跳了。
  static const clearSeconds = 0.45;

  final math.Random _random;

  /// 還沒發出去的那一袋。空了就重新裝滿七種再洗牌。
  final _bag = <Tetromino>[];

  late final List<List<Tetromino?>> _board;

  Tetromino _piece = Tetromino.o;
  int _rotation = 0;
  int _col = 0;
  int _row = 0;

  double _elapsed = 0;
  int _score = 0;
  int _pieceCount = 0;

  /// 正在消掉的那幾列(盤面座標),空的時候代表沒有在演動畫。
  List<int> _clearing = const [];
  double _clearElapsed = 0;
  int _lines = 0;
  bool _over = false;

  int get score => _score;
  int get lines => _lines;

  /// 到目前為止發過幾塊(含正在掉的那一塊)。
  int get pieceCount => _pieceCount;

  /// 正在消掉的那幾列。畫面拿它演動畫。
  List<int> get clearingRows => _clearing;

  bool get isClearing => _clearing.isNotEmpty;

  /// 消行動畫演到哪了,0~1。
  double get clearProgress =>
      _clearing.isEmpty ? 0 : (_clearElapsed / clearSeconds).clamp(0.0, 1.0);
  bool get isOver => _over;

  /// 目前這一塊是什麼形狀。畫顏色用。
  Tetromino get piece => _piece;

  /// 已經落地、堆在盤面上的格子;null 是空的。
  Tetromino? settledAt(int col, int row) {
    if (col < 0 || col >= columns || row < 0 || row >= rows) return null;
    return _board[row][col];
  }

  /// 正在掉的那一塊佔哪幾格(盤面座標)。
  List<(int, int)> get activeCells =>
      [for (final (x, y) in rotatedCells(_piece, _rotation)) (_col + x, _row + y)];

  // MARK: 操作

  /// 喊「怕」:往左移一格。移不動就當沒這回事,不要硬擠。
  void moveLeft() => _shift(-1);

  /// 喊「踏」:往右移一格。
  void moveRight() => _shift(1);

  /// 喊「卡」:往下移一格,跟一般俄羅斯方塊的下鍵一樣。
  ///
  /// 落不下去時什麼都不做(而不是立刻鎖定)—— 辨識偶爾會誤聽成「卡」,
  /// 那時候直接把方塊釘死會很冤枉。等它自己掉到時間就好。
  void moveDown() {
    if (_over) return;
    if (!_fits(_piece, _rotation, _col, _row + 1)) return;
    _row++;
    // 手動移動之後重新計時,不然剛喊完可能馬上又自動掉一格。
    _elapsed = 0;
  }

  /// 喊「啦」:順時針轉 90 度。
  ///
  /// 轉完卡到牆或別的方塊時,往左右各挪一到兩格試試看(踢牆)。都不行就不轉 ——
  /// 寧可不動,也不要讓方塊莫名其妙跳到別的地方。
  void rotate() {
    if (_over) return;
    final next = (_rotation + 1) % 4;
    for (final kick in const [0, -1, 1, -2, 2]) {
      if (_fits(_piece, next, _col + kick, _row)) {
        _rotation = next;
        _col += kick;
        return;
      }
    }
  }

  void _shift(int dx) {
    if (_over) return;
    if (_fits(_piece, _rotation, _col + dx, _row)) _col += dx;
  }

  // MARK: 主迴圈

  /// 推進 [dt] 秒。
  void update(double dt) {
    if (_over) return;
    // 消行動畫期間整個盤面凍住:不落下、不發新的一塊。
    if (_clearing.isNotEmpty) {
      _clearElapsed += dt;
      if (_clearElapsed >= clearSeconds) _finishClear();
      return;
    }
    _elapsed += dt;
    // while 而不是 if:卡頓或切回前景時 dt 可能一次跳好幾格。
    while (_elapsed >= fallSeconds) {
      _elapsed -= fallSeconds;
      _stepDown();
      if (_over) return;
    }
  }

  void _stepDown() {
    if (_fits(_piece, _rotation, _col, _row + 1)) {
      _row++;
      return;
    }
    _lock();
  }

  void _lock() {
    for (final (x, y) in activeCells) {
      if (y >= 0 && y < rows && x >= 0 && x < columns) _board[y][x] = _piece;
    }
    final full = [
      for (var row = 0; row < rows; row++)
        if (_board[row].every((cell) => cell != null)) row
    ];
    if (full.isEmpty) {
      _spawn();
      return;
    }
    // 分數馬上加,但那幾列先留在盤面上演完動畫再拿掉。
    _clearing = full;
    _clearElapsed = 0;
    _lines += full.length;
    _score += _lineScore[math.min(full.length, _lineScore.length - 1)];
  }

  /// 動畫演完:把那幾列真的拿掉,上面整片往下掉,再發新的一塊。
  void _finishClear() {
    // 由下往上刪 —— 先刪小的索引會讓後面那幾個索引跟著位移。
    for (final row in _clearing.toList()..sort((a, b) => b.compareTo(a))) {
      _board.removeAt(row);
      _board.insert(0, List<Tetromino?>.filled(columns, null));
    }
    _clearing = const [];
    _clearElapsed = 0;
    _spawn();
  }

  void _spawn() {
    _piece = _draw();
    _pieceCount++;
    _rotation = 0;
    _col = (columns - _piece.box) ~/ 2;
    _row = 0;
    _elapsed = 0;
    // 新的一塊一出生就卡住 = 堆到頂了。
    if (!_fits(_piece, _rotation, _col, _row)) _over = true;
  }

  /// 從袋子裡拿一塊;袋子空了就重新裝滿七種再洗。
  Tetromino _draw() {
    if (_bag.isEmpty) {
      _bag.addAll(Tetromino.values);
      _bag.shuffle(_random);
    }
    return _bag.removeLast();
  }

  bool _fits(Tetromino piece, int rotation, int col, int row) {
    for (final (x, y) in rotatedCells(piece, rotation)) {
      final c = col + x;
      final r = row + y;
      if (c < 0 || c >= columns || r >= rows) return false;
      // 盤面上方允許超出,不然高一點的方塊一出生就算撞到。
      if (r < 0) continue;
      if (_board[r][c] != null) return false;
    }
    return true;
  }
}
