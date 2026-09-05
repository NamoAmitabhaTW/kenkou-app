import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/media/mic_stream.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/overlays.dart';
import '../../../core/voice/pataka_detector.dart';
import 'voice_hint_row.dart';
import '../domain/maze.dart';
import 'maze_painter.dart';
import '../domain/settings.dart';

enum _Phase { loading, countdown, playing, finished }

/// 開始前的倒數,讓人來得及把手機拿好再開口。
const _countdownSeconds = 3;

/// 吃金幣遊戲本體。
///
/// 麥克風的 PCM 直接餵給 [PatakaDetector],聽到 パ/タ/カ/ラ 就轉成一個方向
/// 丟給 [MazeGame]。辨識器跟健口操共用同一顆德文模型和同一套對照表,
/// 「怕踏卡拉」的判定行為兩邊完全一致。
///
/// 辨識失敗(模型載不起來、沒給麥克風權限)不擋著不讓玩:
/// 直接在迷宮上滑一下也能操控,至少還玩得下去。
class PacmanGamePage extends StatefulWidget {
  const PacmanGamePage({super.key, required this.settings});

  final PacmanSettings settings;

  @override
  State<PacmanGamePage> createState() => _PacmanGamePageState();
}

class _PacmanGamePageState extends State<PacmanGamePage>
    with SingleTickerProviderStateMixin {
  late MazeGame _game;

  /// 不要寫成 `late final _ticker = createTicker(...)..start()` —— `late` 是
  /// 第一次被讀到才初始化,而這個欄位除了 dispose 沒人讀,ticker 會整局都沒開,
  /// 畫面停在剛進來的那一格。要在 initState 明確建。
  late final Ticker _ticker;

  PatakaDetector? _detector;
  MicStream? _mic;
  StreamSubscription<SyllableHit>? _hits;
  String? _voiceError;

  _Phase _phase = _Phase.loading;

  /// 目前這個階段跑了幾秒(倒數 3 秒 / 遊戲時限都用它)。
  double _phaseTime = 0;

  /// 從進頁面開始一直累加,只給嘴巴開合、金幣呼吸這些動畫用。
  double _clock = 0;

  Duration _lastTick = Duration.zero;

  /// 最後一次收到的指令,亮起對應的提示 —— 使用者要看得出「有聽到我說話」。
  MoveDirection? _lastDirection;
  double _lastDirectionAt = -99;

  MazeGame _newGame() => MazeGame(
        cellsPerSecond: widget.settings.cellsPerSecond,
        stepMove: widget.settings.stepMove,
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
    // 辨識器在這裡分流吃 PCM,不自己再開一次麥克風 —— 同一支麥克風被兩個
    // 消費者搶,結果通常是其中一邊拿到無聲。
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

  // MARK: 輸入

  void _onSyllable(SyllableHit hit) {
    final direction = kDirectionBySyllable[hit.syllable];
    if (direction != null) _apply(direction);
  }

  void _apply(MoveDirection direction) {
    if (_phase != _Phase.playing) return;
    _game.turn(direction);
    _lastDirection = direction;
    _lastDirectionAt = _clock;
  }

  /// 語音之外的備援:在迷宮上往哪邊滑就往哪邊走。
  void _onSwipe(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance < 120) return;
    _apply(velocity.dx.abs() > velocity.dy.abs()
        ? (velocity.dx > 0 ? MoveDirection.right : MoveDirection.left)
        : (velocity.dy > 0 ? MoveDirection.down : MoveDirection.up));
  }

  // MARK: 主迴圈

  void _onTick(Duration elapsed) {
    // 卡頓或切回前景時 elapsed 會一次跳很多,夾住免得小精靈瞬間穿過半張地圖。
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
    // 倒數那三秒聽到的東西不算,不然「三、二、一」自己就會走起來。
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

  /// 上方那個秒數。`_phaseTime` 在開場倒數時算的是那三秒,不能拿來減 ——
  /// 不然還沒開始玩,計時就先從 30 掉到 27,開打的瞬間又跳回 30。
  double get _secondsLeft => switch (_phase) {
        _Phase.playing =>
          (widget.settings.gameSeconds - _phaseTime).clamp(0, double.infinity),
        _Phase.finished => 0,
        _Phase.loading || _Phase.countdown =>
          widget.settings.gameSeconds.toDouble(),
      };

  // MARK: 畫面

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
                              // 停下來的時候嘴巴微張就好,不要一直在原地啃空氣。
                              mouth: _game.isMoving
                                  ? 0.5 + 0.5 * math.sin(_clock * 13)
                                  : 0.2,
                              pulse: 0.5 + 0.5 * math.sin(_clock * 4),
                            ),
                          ),
                        ),
                      ),
                      // 倒數只蓋迷宮 —— 這三秒就是要讓人看下面的提示、
                      // 順便瞄一眼倒數計時,整片蓋掉等於把要讀的東西藏起來。
                      if (_phase == _Phase.countdown)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.7),
                          child: Center(child: _countdownBody()),
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

  // MARK: 上方:金幣數量與倒數計時

  Widget _topBar() {
    final left = _secondsLeft;
    final hurry = left <= 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white70),
                iconSize: 30,
                tooltip: '離開',
              ),
              const Icon(Icons.circle, color: kCoinColor, size: 16),
              const SizedBox(width: 8),
              Text(
                '${_game.coinsEaten}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 5),
                child: Text('顆',
                    style: TextStyle(color: Colors.white54, fontSize: 15)),
              ),
              const SizedBox(width: 14),
              Text(
                '${_game.score} 分',
                style: const TextStyle(
                  color: kCoinColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(Icons.timer_outlined,
                  color: hurry ? Colors.redAccent : Colors.white54, size: 22),
              const SizedBox(width: 6),
              Text(
                left.ceil().toString(),
                style: TextStyle(
                  color: hurry ? Colors.redAccent : Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 5),
                child: Text('秒',
                    style: TextStyle(color: Colors.white54, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: left / widget.settings.gameSeconds,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(
                  hurry ? Colors.redAccent : kPacmanColor),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: 下方:操控提示

  Widget _hints() {
    final scheme = Theme.of(context).colorScheme;
    // 亮 0.8 秒。太短會來不及看到,太長會分不出是哪一次。
    final recent = _clock - _lastDirectionAt < 0.8;

    Widget row(MoveDirection direction) => VoiceHintRow(
          direction: direction,
          scheme: scheme,
          compact: true,
          highlighted: recent && _lastDirection == direction,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: Colors.white10,
      child: Column(
        // 一行一個方向。排成兩欄雖然省高度,但「往下移動」四個字加上前面的
        // 「念『拉』↓」在半個螢幕寬裡放不下,右邊會被切掉;迷宮是等比例縮放的,
        // 上下本來就有空位,寧可把高度讓給提示。
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final direction in MoveDirection.values) row(direction),
          if (_voiceError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_voiceError!,
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 13)),
            ),
          if (widget.settings.showDebug)
            Padding(
              padding: const EdgeInsets.only(top: 6),
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

  // MARK: 覆蓋層

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
            style: TextStyle(color: Colors.white70, fontSize: 20)),
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
