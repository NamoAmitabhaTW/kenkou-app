import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/media/mic_stream.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/overlays.dart';
import '../../../core/voice/pataka_detector.dart';
import '../../../core/voice/syllable.dart';
import '../domain/tetris_game.dart';
import 'tetris_painter.dart';

enum TetrisMove {
  left(Syllable.pa, '向左', '←'),
  right(Syllable.ta, '向右', '→'),
  down(Syllable.ka, '向下', '↓'),
  rotate(Syllable.ra, '旋轉', '↻');

  const TetrisMove(this.syllable, this.label, this.arrow);

  final Syllable syllable;
  final String label;
  final String arrow;

  String get word => syllable.label;
}

final _moveBySyllable = <Syllable, TetrisMove>{
  for (final move in TetrisMove.values) move.syllable: move,
};

enum _Phase { loading, playing, finished }

class TetrisPage extends StatefulWidget {
  const TetrisPage({
    super.key,
    required this.blankPenalty,
    required this.fallSeconds,
  });

  final double blankPenalty;

  final double fallSeconds;

  @override
  State<TetrisPage> createState() => _TetrisPageState();
}

class _TetrisPageState extends State<TetrisPage>
    with SingleTickerProviderStateMixin {
  late TetrisGame _game = _newGame();

  TetrisGame _newGame() => TetrisGame(fallSeconds: widget.fallSeconds);

  late final Ticker _ticker;

  PatakaDetector? _detector;
  MicStream? _mic;
  StreamSubscription<SyllableHit>? _hits;
  String? _voiceError;

  _Phase _phase = _Phase.loading;
  Duration _lastTick = Duration.zero;
  double _clock = 0;

  TetrisMove? _lastMove;
  double _lastMoveAt = -99;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _boot();
  }

  Future<void> _boot() async {
    try {
      _detector = await PatakaDetector.create(blankPenalty: widget.blankPenalty);
      _hits = _detector!.hits.listen(_onSyllable);
    } catch (e) {
      _voiceError = '語音辨識載入失敗,請用畫面下方的按鈕操控';
    }
    if (_detector != null && !await _startMic()) {
      _voiceError = '麥克風沒開起來(權限?),請用畫面下方的按鈕操控';
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.playing);
  }

  Future<bool> _startMic() async {
    final mic = MicStream();
    _mic = mic;
    return mic.start(onChunk: (chunk) => _detector?.feed(chunk));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _hits?.cancel();
    _mic?.dispose();
    _detector?.dispose();
    super.dispose();
  }

  void _onSyllable(SyllableHit hit) {
    final move = _moveBySyllable[hit.syllable];
    if (move == null) return;
    _apply(move);
    if (_phase == _Phase.playing) _detector?.restart();
  }

  void _apply(TetrisMove move) {
    if (_phase != _Phase.playing || _game.isOver) return;
    switch (move) {
      case TetrisMove.left:
        _game.moveLeft();
      case TetrisMove.right:
        _game.moveRight();
      case TetrisMove.down:
        _game.moveDown();
      case TetrisMove.rotate:
        _game.rotate();
    }
    _lastMove = move;
    _lastMoveAt = _clock;
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    _clock += dt;

    if (_phase == _Phase.playing) {
      _game.update(dt);
      if (_game.isOver) {
        _phase = _Phase.finished;
        _mic?.dispose();
        _mic = null;
      }
    }
    if (mounted) setState(() {});
  }

  void _finish() {
    setState(() => _phase = _Phase.finished);
    _mic?.dispose();
    _mic = null;
  }

  void _restart() {
    setState(() {
      _game = _newGame();
      _phase = _Phase.playing;
    });
    if (_mic == null && _detector != null) _startMic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTetrisBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _infoPanel(),
                Expanded(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: TetrisPainter(game: _game),
                    ),
                  ),
                ),
              ],
            ),
            if (_phase == _Phase.loading)
              _overlay(child: const PreparingView(detail: '正在載入語音辨識')),
            if (_phase == _Phase.finished) _overlay(child: _resultBody()),
          ],
        ),
      ),
    );
  }

  Widget _infoPanel() {
    final recent = _clock - _lastMoveAt < 0.8;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('分數',
                  style: TextStyle(color: Colors.white54, fontSize: 20)),
              const SizedBox(width: 10),
              Text('${_game.score}',
                  style: const TextStyle(
                      color: kAccentGreen,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      height: 1.1)),
              const Spacer(),
              FilledButton(
                onPressed: _phase == _Phase.playing ? _finish : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(104, 52),
                  textStyle: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800),
                ),
                child: const Text('結算'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final move in TetrisMove.values)
                _hintCell(move, recent && _lastMove == move),
            ],
          ),
          const Text('一次念一聲',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          if (_voiceError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_voiceError!,
                  style:
                      const TextStyle(color: Colors.orangeAccent, fontSize: 14)),
            ),
        ],
      ),
    );
  }

  Widget _hintCell(TetrisMove move, bool highlighted) {
    final color = highlighted ? kVoiceHighlight : Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? kVoiceHighlight.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(move.word,
              softWrap: false,
              style: TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w900, color: color)),
          Text('${move.arrow} ${move.label}',
              softWrap: false,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: highlighted ? kVoiceHighlight : Colors.white70)),
        ],
      ),
    );
  }

  Widget _overlay({required Widget child}) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(child: child),
        ),
      );

  Widget _resultBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_game.isOver ? '堆到頂了!' : '這局結束',
              style: const TextStyle(
                  color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          Text('${_game.score} 分',
              style: const TextStyle(
                  color: kAccentGreen,
                  fontSize: 64,
                  fontWeight: FontWeight.w900)),
          Text('消掉 ${_game.lines} 列',
              style: const TextStyle(color: Colors.white70, fontSize: 20)),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _restart,
            style: kBigButtonStyle.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(72)),
            ),
            child: const Text('再玩一次',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: const Text('回上一頁',
                style: TextStyle(fontSize: 22, color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
