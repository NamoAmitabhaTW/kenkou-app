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
    if (direction == null) return;
    _apply(direction);

    // 每認到一個音就重開串流。整局共用一條串流時,辨識器的上下文會越積越長,
    // 德文模型會把連續的 pa 黏成 "paar",ka / ta 的區別也跟著變差 ——
    // 健口操每換一個動作就 restart 一次,所以不會遇到,吃金幣原本整局只 restart
    // 一次(開場倒數結束時)。
    //
    // 代價是 PatakaDetector 類別說明講的那件事:reset 之後串流從零開始,
    // 緊接著說的下一個音少了前後文,比較容易漏。restart() 會先墊半秒靜音暖機
    // 來補償。
    if (_phase == _Phase.playing) _detector?.restart();
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
                          // 提示表格放大之後迷宮那塊變矮,倒數的「3」是 120pt,
                          // 在小螢幕上會撐破。讓它在放不下時自己縮。
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

  // MARK: 上方:金幣數量與倒數計時

  Widget _topBar() {
    final left = _secondsLeft;
    final hurry = left <= 5;

    // 顆數與分數用 FittedBox 包住:金幣吃滿時分數會到四位數,放大字級之後
    // 固定排版一定會爆版,讓它在放不下的時候自己縮,而不是畫面壞掉。
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

  // MARK: 下方:操控提示

  Widget _hints() {
    // 亮 0.8 秒。太短會來不及看到,太長會分不出是哪一次。
    final recent = _clock - _lastDirectionAt < 0.8;
    Widget cell(MoveDirection d) =>
        _hintCell(d, recent && _lastDirection == d);

    // 排成兩欄三列而不是四列 —— 四列吃掉太多高度,迷宮被壓到看不清楚。
    // 「一次念一聲」放最上面當標題,它是唯一的操作規則。
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
          // 上排放左右、下排放上下 —— 同一組相反的方向排在一起,
          // 比照著音節順序排更好記。
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

  /// 對照表的一格:念的字、箭頭、往哪走。
  ///
  /// 三欄固定寬度,左右兩格的字才會上下對齊。聽到那個音時整格亮起來,
  /// 讓人知道「有聽到我說話」。
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
