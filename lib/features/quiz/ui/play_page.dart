import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:face_mesh/face_mesh.dart';
import 'package:flutter/material.dart';

import '../../../core/media/audio_session.dart';
import '../../../core/media/recording_store.dart';
import '../../../core/media/screen_capture_notice.dart';
import '../../../core/media/session_recorder.dart';
import '../../../core/ui/overlays.dart';
import '../domain/question.dart';
import 'play_hud.dart';
import 'play_result_view.dart';
import 'question_intro.dart';
import '../data/quiz_store.dart';

/// 一輪答題走到哪裡。
///
/// 每一題都會走一遍 intro → answering → feedback,最後一題的 feedback 完才到 done。
enum QuizPhase {
  /// 相機、錄影、audio session 還在準備。
  preparing,

  /// 「第 X 題」的題號動畫。
  intro,

  /// 正在倒數作答。
  answering,

  /// 已作答(或逾時),正在顯示答案。
  feedback,

  /// 結算。
  done,
}

/// 出題與作答的流程。
///
/// 這個類別只管**流程**:現在第幾題、時間到了沒、答對了沒、什麼時候換下一題。
/// 畫面在 [QuizQuestionView] 和 [QuizResultView],錄影在 [SessionRecorder] ——
/// 三件事分開之後,「答題規則」才讀得出來。
class QuizPlayPage extends StatefulWidget {
  const QuizPlayPage({
    super.key,
    required this.store,
    required this.questions,
    required this.secondsPerQuestion,
  });

  final QuizStore store;

  /// 這一輪要出的題目,已經由題庫抽好也洗過牌。
  final List<QuizQuestion> questions;

  final int secondsPerQuestion;

  @override
  State<QuizPlayPage> createState() => _QuizPlayPageState();
}

class _QuizPlayPageState extends State<QuizPlayPage> {
  final _player = AudioPlayer();
  final _recorder = SessionRecorder(kind: RecordingKind.quiz);

  int _index = 0;
  QuizPhase _phase = QuizPhase.preparing;
  int _correctCount = 0;
  int _remaining = 0;

  /// 使用者選了哪一個。null 代表時間到了都沒作答。
  int? _selected;

  Timer? _countdown;
  Timer? _advance;

  String? _directory;
  bool _cameraReady = false;

  /// 結算畫面顯示出來之後,影片還在背景合成。分享要等它做完。
  bool _savingVideo = true;

  /// 錄完的影片路徑,分享時要用。錄製失敗時是 null。
  String? _videoPath;

  QuizQuestion get _question => widget.questions[_index];

  /// 這一輪的題數。題庫不夠時會少於設定的每輪題數。
  int get _total => widget.questions.length;

  bool get _isCorrect => _selected == _question.correctOption;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  /// 先把相機和錄製都準備好才開始出題。
  ///
  /// ReplayKit 第一次啟動會跳系統權限詢問,不等它就直接開始的話,
  /// 第一題的題號動畫會在對話框後面自己跑掉。
  Future<void> _boot() async {
    _directory = (await widget.store.directory()).path;

    try {
      await FaceMesh.start(detect: false);
      _cameraReady = true;
    } catch (_) {
      // 相機開不起來不該擋住答題,就當作沒有畫面繼續。
      _cameraReady = false;
    }

    if (!mounted) return;
    await ScreenCaptureNotice.showIfNeeded(context);
    if (!mounted) return;

    // 題目錄音是邊錄影邊播的,先把 audio session 切成「播放與錄音並存」,
    // 否則麥克風會從播第一題的那一刻起收不到東西。
    await AudioSession.allowPlaybackWhileRecording();
    await _recorder.start();

    if (!mounted) return;
    setState(() => _phase = QuizPhase.intro);
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _advance?.cancel();
    _player.dispose();
    // 中途離開也要收尾,不然 ReplayKit 和麥克風會一直開著。
    _recorder.discard();
    FaceMesh.stop();
    super.dispose();
  }

  // MARK: 流程

  void _beginAnswering() {
    setState(() {
      _phase = QuizPhase.answering;
      _selected = null;
      _remaining = widget.secondsPerQuestion;
    });

    _playQuestionAudio();

    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        timer.cancel();
        _submit(null); // 逾時當作答錯,一樣把正解顯示出來
      }
    });
  }

  Future<void> _playQuestionAudio() async {
    final fileName = _question.audioFile;
    if (fileName == null) return;
    await _player.play(DeviceFileSource(await widget.store.resolve(fileName)));
  }

  void _submit(int? option) {
    if (_phase != QuizPhase.answering) return;

    _countdown?.cancel();
    _player.stop();

    setState(() {
      _selected = option;
      _phase = QuizPhase.feedback;
      if (option == _question.correctOption) _correctCount++;
    });

    // 答對停留短一點,答錯多留一會兒讓人看清楚正解是哪個。
    _advance = Timer(Duration(milliseconds: _isCorrect ? 1800 : 2600), _next);
  }

  Future<void> _next() async {
    if (!mounted) return;

    if (_index < _total - 1) {
      setState(() {
        _index++;
        _phase = QuizPhase.intro;
      });
      return;
    }

    // 先把結算畫面顯示出來,再去收尾錄影。
    //
    // 合成影片要花幾秒鐘,擋在前面的話畫面會停在最後一題不動,看起來
    // 像當掉;收尾如果又丟出例外(這是 Timer callback,錯誤不會有人接),
    // 使用者就再也走不到結算畫面了。
    setState(() => _phase = QuizPhase.done);

    final path = await _recorder.finish(score: _correctCount, total: _total);
    // 錄音真的停了才還原 audio session,提早切回去會把還在寫的檔案弄壞。
    await AudioSession.restorePlaybackOnly();

    if (!mounted) return;
    setState(() {
      _videoPath = path;
      _savingVideo = false;
    });
  }

  // MARK: 畫面

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: switch (_phase) {
          QuizPhase.preparing => const PreparingView(),
          QuizPhase.intro => QuestionIntro(
              // 同一題重播時要讓 widget 重建,否則動畫不會重跑。
              key: ValueKey(_index),
              index: _index,
              onComplete: _beginAnswering,
            ),
          QuizPhase.answering || QuizPhase.feedback => QuizQuestionView(
              question: _question,
              index: _index,
              phase: _phase,
              directory: _directory,
              cameraReady: _cameraReady,
              isRecording: _recorder.isRecording,
              remainingSeconds: _remaining,
              totalSeconds: widget.secondsPerQuestion,
              selected: _selected,
              onAnswer: _submit,
            ),
          QuizPhase.done => QuizResultView(
              correctCount: _correctCount,
              total: _total,
              savingVideo: _savingVideo,
              videoPath: _videoPath,
            ),
        },
      ),
    );
  }
}
