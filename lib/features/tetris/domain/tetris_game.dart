import 'dart:math' as math;

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

List<(int, int)> rotatedCells(Tetromino piece, int rotation) {
  var cells = piece.cells;
  for (var i = 0; i < rotation % 4; i++) {
    cells = [for (final (x, y) in cells) (piece.box - 1 - y, x)];
  }
  return cells;
}

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

  final double fallSeconds;

  static const _lineScore = [0, 100, 300, 500, 800];

  static const clearSeconds = 0.45;

  final math.Random _random;

  final _bag = <Tetromino>[];

  late final List<List<Tetromino?>> _board;

  Tetromino _piece = Tetromino.o;
  int _rotation = 0;
  int _col = 0;
  int _row = 0;

  double _elapsed = 0;
  int _score = 0;
  int _pieceCount = 0;

  List<int> _clearing = const [];
  double _clearElapsed = 0;
  int _lines = 0;
  bool _over = false;

  int get score => _score;
  int get lines => _lines;

  int get pieceCount => _pieceCount;

  List<int> get clearingRows => _clearing;

  bool get isClearing => _clearing.isNotEmpty;

  double get clearProgress =>
      _clearing.isEmpty ? 0 : (_clearElapsed / clearSeconds).clamp(0.0, 1.0);
  bool get isOver => _over;

  Tetromino get piece => _piece;

  Tetromino? settledAt(int col, int row) {
    if (col < 0 || col >= columns || row < 0 || row >= rows) return null;
    return _board[row][col];
  }

  List<(int, int)> get activeCells =>
      [for (final (x, y) in rotatedCells(_piece, _rotation)) (_col + x, _row + y)];

  void moveLeft() => _shift(-1);

  void moveRight() => _shift(1);

  void moveDown() {
    if (_over) return;
    if (!_fits(_piece, _rotation, _col, _row + 1)) return;
    _row++;
    _elapsed = 0;
  }

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

  void update(double dt) {
    if (_over) return;
    if (_clearing.isNotEmpty) {
      _clearElapsed += dt;
      if (_clearElapsed >= clearSeconds) _finishClear();
      return;
    }
    _elapsed += dt;
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
    _clearing = full;
    _clearElapsed = 0;
    _lines += full.length;
    _score += _lineScore[math.min(full.length, _lineScore.length - 1)];
  }

  void _finishClear() {
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
    if (!_fits(_piece, _rotation, _col, _row)) _over = true;
  }

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
      if (r < 0) continue;
      if (_board[r][c] != null) return false;
    }
    return true;
  }
}
