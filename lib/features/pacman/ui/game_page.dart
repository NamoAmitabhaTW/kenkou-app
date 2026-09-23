import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/media/mic_stream.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/overlays.dart';
import '../../../core/voice/pataka_detector.dart';
import '../domain/maze.dart';
import 'maze_painter.dart';
import '../../../core/game_settings.dart';

enum _Phase { loading, countdown, playing, finished }

const _countdownSeconds = 3;

class PacmanGamePage extends StatefulWidget {
  const PacmanGamePage({super.key, required this.settings});

  final GameSettings settings;

  @override
  State<PacmanGamePage> createState() => _PacmanGamePageState();
}

class _PacmanGamePageState extends State<PacmanGamePage>
    with SingleTickerProviderStateMixin {
  late MazeGame _game;

  late final Ticker _ticker;

  PatakaDetector? _detector;
  MicStream? _mic;
  StreamSubscription<SyllableHit>? _hits;
  String? _voiceError;

  _Phase _phase = _Phase.loading;

  double _phaseTime = 0;

  double _clock = 0;

  Duration _lastTick = Duration.zero;

  MoveDirection? _lastDirection;
  double _lastDirectionAt = -99;

  MazeGame _newGame() => MazeGame(
        cellsPerSecond: widget.settings.cellsPerSecond,
        cellsPerCommand: widget.settings.cellsPerCommand,
      );

  @override
  void initState() {
    super.initState();
    _game = _newGame();
    _ticker = createTicker(_onTick)..start();
    _boot();
  }

  Future<void> _boot() async {
    try {
      _detector =
          await PatakaDetector.create(blankPenalty: widget.settings.blankPenalty);
      _hits = _detector!.hits.listen(_onSyllable);
    } catch (e) {
      _voiceError = '語音辨識載入失敗,請用手指滑動操控';
    }

    if (_detector != null && !await _startMic()) {
      _voiceError = '麥克風沒開起來(權限?),請用手指滑動操控';
    }
    if (!mounted) return;
    setState(() {
      _phase = _Phase.countdown;
      _phaseTime = 0;
    });
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
    final direction = kDirectionBySyllable[hit.syllable];
    if (direction == null) return;
    _apply(direction);

    if (_phase == _Phase.playing) _detector?.restart();
  }

  void _apply(MoveDirection direction) {
    if (_phase != _Phase.playing) return;
    _game.turn(direction);
    _lastDirection = direction;
    _lastDirectionAt = _clock;
  }

  void _onSwipe(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance < 120) return;
    _apply(velocity.dx.abs() > velocity.dy.abs()
        ? (velocity.dx > 0 ? MoveDirection.right : MoveDirection.left)
        : (velocity.dy > 0 ? MoveDirection.down : MoveDirection.up));
  }

  void _onTick(Duration elapsed) {
    final dt =
        ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    _clock += dt;

    switch (_phase) {
      case _Phase.loading:
      case _Phase.finished:
        break;
      case _Phase.countdown:
        _phaseTime += dt;
        if (_phaseTime >= _countdownSeconds) _startPlaying();
      case _Phase.playing:
        _phaseTime += dt;
        _game.update(dt);
        if (_game.cleared || _phaseTime >= widget.settings.gameSeconds) {
          _phase = _Phase.finished;
          _mic?.dispose();
          _mic = null;
        }
    }

    if (mounted) setState(() {});
  }

  void _startPlaying() {
    _phase = _Phase.playing;
    _phaseTime = 0;
    _detector?.restart();
  }

  Future<void> _replay() async {
    _game = _newGame();
    _lastDirection = null;
    if (_mic == null && _detector != null) await _startMic();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.countdown;
      _phaseTime = 0;
    });
  }

  double get _secondsLeft => switch (_phase) {
        _Phase.playing =>
          (widget.settings.gameSeconds - _phaseTime).clamp(0, double.infinity),
        _Phase.finished => 0,
        _Phase.loading || _Phase.countdown =>
          widget.settings.gameSeconds.toDouble(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMazeBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _topBar(),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onPanEnd: _onSwipe,
                        behavior: HitTestBehavior.opaque,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: MazePainter(
                              game: _game,
                              mouth: _game.isMoving
                                  ? 0.5 + 0.5 * math.sin(_clock * 13)
                                  : 0.2,
                              pulse: 0.5 + 0.5 * math.sin(_clock * 4),
                            ),
                          ),
                        ),
                      ),
                      if (_phase == _Phase.countdown)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.7),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _countdownBody(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _hints(),
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

  Widget _topBar() {
    final left = _secondsLeft;
    final hurry = left <= 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70),
            iconSize: 30,
            tooltip: '離開',
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Icon(Icons.circle, color: kCoinColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '${_game.score}',
                    style: const TextStyle(
                      color: kCoinColor,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(' 分',
                      style: TextStyle(color: Colors.white70, fontSize: 20)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                left.ceil().toString(),
                style: TextStyle(
                  color: hurry ? Colors.redAccent : Colors.white,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(' 秒',
                  style: TextStyle(
                      color: hurry ? Colors.redAccent : Colors.white70,
                      fontSize: 20)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hints() {
    final recent = _clock - _lastDirectionAt < 0.8;
    Widget cell(MoveDirection d) =>
        _hintCell(d, recent && _lastDirection == d);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      color: Colors.white10,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('一次念一聲',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              cell(MoveDirection.left),
              cell(MoveDirection.right),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              cell(MoveDirection.up),
              cell(MoveDirection.down),
            ],
          ),
          if (_voiceError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_voiceError!,
                  style:
                      const TextStyle(color: Colors.orangeAccent, fontSize: 14)),
            ),
          if (widget.settings.showDebug)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '聽到:${_detector?.lastHeard ?? '-'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hintCell(MoveDirection direction, bool highlighted) {
    final color = highlighted ? kVoiceHighlight : Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? kVoiceHighlight.withValues(alpha: 0.22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            child: Text(direction.word,
                textAlign: TextAlign.center,
                softWrap: false,
                style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w900, color: color)),
          ),
          SizedBox(
            width: 34,
            child: Text(direction.arrow,
                textAlign: TextAlign.center,
                softWrap: false,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: highlighted ? kVoiceHighlight : kAccentGreen)),
          ),
          SizedBox(
            width: 68,
            child: Text(direction.short,
                softWrap: false,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          ),
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

  Widget _countdownBody() {
    final left = (_countdownSeconds - _phaseTime).ceil().clamp(1, _countdownSeconds);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$left',
          style: const TextStyle(
              color: kPacmanColor, fontSize: 120, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text('要開始囉！',
            style: TextStyle(
                color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _resultBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _game.cleared ? '金幣全部吃完了!' : '時間到!',
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${_game.coinsEaten}',
                style: const TextStyle(
                    color: kCoinColor, fontSize: 72, fontWeight: FontWeight.w900),
              ),
              const Text(' 顆金幣',
                  style: TextStyle(color: Colors.white70, fontSize: 22)),
            ],
          ),
          Text(
            '${_game.score} 分',
            style: const TextStyle(
                color: kPacmanColor, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _replay,
              style: kBigButtonStyle,
              icon: const Icon(Icons.refresh, size: 28),
              label: const Text('再玩一次',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: kBigButtonStyle,
              child: const Text('回首頁', style: TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }
}
