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

enum QuizPhase {
  preparing,

  intro,

  answering,

  feedback,

  done,
}

class QuizPlayPage extends StatefulWidget {
  const QuizPlayPage({
    super.key,
    required this.store,
    required this.questions,
    required this.secondsPerQuestion,
  });

  final QuizStore store;

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

  int? _selected;

  Timer? _countdown;
  Timer? _advance;

  String? _directory;
  bool _cameraReady = false;

  bool _savingVideo = true;

  String? _videoPath;

  QuizQuestion get _question => widget.questions[_index];

  int get _total => widget.questions.length;

  bool get _isCorrect => _selected == _question.correctOption;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    _directory = (await widget.store.directory()).path;

    try {
      await FaceMesh.start(detect: false);
      _cameraReady = true;
    } catch (_) {
      _cameraReady = false;
    }

    if (!mounted) return;
    await ScreenCaptureNotice.showIfNeeded(context);
    if (!mounted) return;

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
    _recorder.discard();
    FaceMesh.stop();
    super.dispose();
  }

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
        _submit(null);
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

    setState(() => _phase = QuizPhase.done);

    final path = await _recorder.finish(score: _correctCount, total: _total);
    await AudioSession.restorePlaybackOnly();

    if (!mounted) return;
    setState(() {
      _videoPath = path;
      _savingVideo = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: switch (_phase) {
          QuizPhase.preparing => const PreparingView(),
          QuizPhase.intro => QuestionIntro(
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
