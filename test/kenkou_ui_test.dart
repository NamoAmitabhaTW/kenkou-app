import 'dart:ui' as ui;

import 'package:face_mesh/face_mesh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremode2026/core/voice/syllable.dart';
import 'package:futuremode2026/features/kenkou/domain/exercise_program.dart';
import 'package:futuremode2026/features/kenkou/domain/face_geometry.dart';
import 'package:futuremode2026/features/kenkou/domain/mouth_shape.dart';
import 'package:futuremode2026/features/kenkou/domain/session_runner.dart';
import 'package:futuremode2026/features/kenkou/domain/settings.dart';
import 'package:futuremode2026/features/kenkou/ui/face_markers.dart';
import 'package:futuremode2026/features/kenkou/ui/feedback.dart';
import 'package:futuremode2026/features/kenkou/ui/feedback_badge.dart';
import 'package:futuremode2026/features/kenkou/ui/session_hud.dart';

import 'support/face_frames.dart';

const _hold = Duration(milliseconds: 3000);

const _nudge = FeedbackMessage('再用力一點', FeedbackTone.nudge);
const _holding = FeedbackMessage('很好!維持住', FeedbackTone.hold);

void useNarrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2220);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void completeShape(KenkouSession session) {
  session.onFaceScore(0.9);
  session.tracker!.held = session.tracker!.requiredHold;
  session.onFaceScore(0.9);
}

void main() {
  group('動作卡', () {
    Future<void> pumpHud(
      WidgetTester tester,
      KenkouSession session, {
      FeedbackMessage? feedback,
      bool voiceReady = false,
      int countdown = 10,
    }) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SessionHud(
            session: session,
            settings: const KenkouSettings(),
            step: session.step,
            frame: const FaceFrame(hasFace: false),
            classifier: MouthShapeClassifier(),
            lips: LipsClosedDetector(),
            targetScore: 0,
            isRecording: true,
            voiceReady: voiceReady,
            feedback: feedback,
            countdown: countdown,
            lastHeard: null,
            lastHeardDebug: '',
            onExit: () {},
            onSkip: () {},
            onCountManually: () {},
          ),
        ),
      ));
    }

    testWidgets('每個動作(含每一段提示、休息)在窄螢幕上都放得下', (tester) async {
      useNarrowPhone(tester);

      final steps = buildProgram(const KenkouSettings());
      final session = KenkouSession(steps: steps, defaultHold: _hold);
      while (!session.isFinished) {
        final step = session.step;
        final feedback = step.mode == StepMode.guided ? null : _nudge;
        await pumpHud(tester, session, feedback: feedback);
        expect(find.text(step.section), findsOneWidget, reason: step.id);
        if (step.detail != null) {
          expect(find.text(step.detail!), findsOneWidget, reason: step.id);
        }
        if (step.caution != null) {
          expect(find.text(step.caution!), findsOneWidget, reason: step.id);
        }

        if (step.mode == StepMode.guided) {
          expect(find.text(session.currentCue!.text), findsOneWidget);
          while (session.completeGuided() == SessionEvent.partial) {
            await pumpHud(tester, session);
            expect(find.text(session.currentCue!.text), findsOneWidget,
                reason: step.id);
          }
        }
        if (step.rest != null) {
          session.resting = true;
          await pumpHud(tester, session);
          expect(find.text('嘴巴閉起來休息'), findsOneWidget);
          expect(find.text(step.detail!), findsNothing);
          session.resting = false;
        }
        session.skip();
        session.advance();
      }
    });

    testWidgets('口唇體操:先大字顯示「屋～」,做到了才換「衣～」,兩個都做到算一組',
        (tester) async {
      final lips = buildProgram(const KenkouSettings(faceReps: 5))
          .firstWhere((s) => s.id == 'lips_u_i');
      final session = KenkouSession(steps: [lips], defaultHold: _hold);

      await pumpHud(tester, session);
      expect(find.text('嘴唇往前噘起'), findsOneWidget);
      expect(find.text('屋～'), findsOneWidget);
      expect(find.text('衣～'), findsNothing, reason: '一次只顯示一個嘴型');
      expect(find.text('第 1 / 5 組'), findsOneWidget);

      completeShape(session);
      await pumpHud(tester, session);
      expect(find.text('嘴角往兩邊拉開'), findsOneWidget);
      expect(find.text('衣～'), findsOneWidget);
      expect(find.text('屋～'), findsNothing);
      expect(find.text('第 1 / 5 組'), findsOneWidget);

      completeShape(session);
      await pumpHud(tester, session);
      expect(find.text('屋～'), findsOneWidget);
      expect(find.text('第 2 / 5 組'), findsOneWidget);
    });

    testWidgets('回饋是動作卡下面另一個元件,動作的大字不會被換掉', (tester) async {
      final face = buildProgram(const KenkouSettings())
          .firstWhere((s) => s.mode == StepMode.face);
      final session = KenkouSession(steps: [face], defaultHold: _hold);

      await pumpHud(tester, session, feedback: _nudge);
      expect(find.text('嘴唇往前噘起'), findsOneWidget);
      expect(find.byType(FeedbackBadge), findsOneWidget);
      expect(find.text('再用力一點'), findsOneWidget);
      expect(tester.getRect(find.byType(FeedbackBadge)).top,
          greaterThan(tester.getRect(find.byType(LinearProgressIndicator)).bottom));

      await pumpHud(tester, session);
      expect(find.text('嘴唇往前噘起'), findsOneWidget);
      expect(find.byType(FeedbackBadge), findsNothing);
    });

    testWidgets('回饋出現、消失時,動作卡不會被推動', (tester) async {
      final face = buildProgram(const KenkouSettings())
          .firstWhere((s) => s.mode == StepMode.face);
      final session = KenkouSession(steps: [face], defaultHold: _hold);

      await pumpHud(tester, session);
      final without = tester.getRect(find.text('嘴唇往前噘起'));
      await pumpHud(tester, session, feedback: _nudge);
      expect(tester.getRect(find.text('嘴唇往前噘起')), without);
    });

    testWidgets('發音體操:要說的音放在「大聲說」右邊,放到最大,不放部位的說明',
        (tester) async {
      final pa = buildProgram(const KenkouSettings(patakaReps: 8))
          .firstWhere((s) => s.id == 'pataka_pa_1');
      final session = KenkouSession(steps: [pa], defaultHold: _hold);
      session.onSyllable(Syllable.pa, at: DateTime(2026));

      await pumpHud(tester, session, voiceReady: true);
      expect(find.text('大聲說'), findsOneWidget);
      expect(find.text('怕'), findsOneWidget);
      expect(find.text('1 / 8 次'), findsOneWidget);
      expect(find.text('嘴唇先閉緊,再用力彈開'), findsNothing);
      final prompt = tester.getRect(find.text('大聲說'));
      final sound = tester.getRect(find.text('怕'));
      expect(sound.left, greaterThan(prompt.right));
      expect(sound.top, lessThan(prompt.bottom));
    });

    testWidgets('張口訓練:「維持住」和還要撐幾秒放在回饋元件上;休息時換成閉口',
        (tester) async {
      useNarrowPhone(tester);
      final open = buildProgram(const KenkouSettings())
          .firstWhere((s) => s.id == 'mouth_open');
      final session = KenkouSession(steps: [open], defaultHold: _hold);

      await pumpHud(tester, session);
      expect(find.text('嘴巴慢慢張大'), findsOneWidget);
      expect(find.text('張到最大,維持 10 秒'), findsOneWidget);
      expect(find.text('第 1 / 2 次'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      session.onFaceScore(0.95);
      await pumpHud(tester, session, feedback: _holding);
      expect(find.text('很好!維持住'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      session.tracker!.held = const Duration(seconds: 4);
      session.onFaceScore(0.1);
      session.onFaceScore(0.95);
      await pumpHud(tester, session, feedback: _holding);
      expect(find.text('6'), findsOneWidget);

      session.resting = true;
      await pumpHud(tester, session, countdown: 7);
      expect(find.text('嘴巴閉起來休息'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('張到最大,維持 10 秒'), findsNothing,
          reason: '已經有大字和倒數圈,不重複');
    });

    testWidgets('引導步驟:名稱小字、動作大字,重複的分段顯示第幾組', (tester) async {
      final cheeks = buildProgram(const KenkouSettings(faceReps: 5))
          .firstWhere((s) => s.id == 'cheek_puff_suck');
      final session = KenkouSession(steps: [cheeks], defaultHold: _hold);

      await pumpHud(tester, session, countdown: 5);
      expect(find.text('嘴唇與臉頰體操'), findsOneWidget);
      expect(find.text('鼓起臉頰'), findsOneWidget);
      expect(find.text('第 1 / 5 組'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      session.completeGuided();
      session.completeGuided();
      await pumpHud(tester, session, countdown: 5);
      expect(find.text('鼓起臉頰'), findsOneWidget);
      expect(find.text('第 2 / 5 組'), findsOneWidget);
    });
  });

  group('回饋元件', () {
    Future<void> pumpBadge(WidgetTester tester, FeedbackMessage message,
        {int? seconds}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: FeedbackBadge(message: message, seconds: seconds)),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('「很好!維持住」配讚;帶倒數秒數時不放圖示,讓秒數大一點;提醒不放圖示',
        (tester) async {
      await pumpBadge(tester, _holding);
      expect(find.text('很好!維持住'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up), findsOneWidget);

      await pumpBadge(tester, _holding, seconds: 7);
      expect(find.byType(Icon), findsNothing);
      expect(find.text('7'), findsOneWidget);
      expect(find.text(' 秒'), findsOneWidget);
      double size(String text) =>
          tester.widget<Text>(find.text(text)).style!.fontSize!;
      expect(size(' 秒'), size('很好!維持住'));
      expect(size('7'), greaterThan(size('很好!維持住')));

      await pumpBadge(tester, _nudge);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('沒有給秒數就不顯示倒數', (tester) async {
      await pumpBadge(tester, _holding);
      expect(find.text(' 秒'), findsNothing);
    });
  });

  group('回饋', () {
    ExerciseStep faceStep({bool pauseOnDrop = false}) => ExerciseStep(
          id: 'a',
          section: 's',
          mode: StepMode.face,
          shapes: const [MouthShape.a],
          reps: 3,
          hold: const Duration(seconds: 10),
          pauseOnDrop: pauseOnDrop,
        );

    test('跟著嘴型狀態:差一點是提醒、維持中、沒在做就不講', () {
      final s = KenkouSession(steps: [faceStep()], defaultHold: _hold);
      expect(holdFeedback(s), isNull, reason: '還沒開始做,不用講話');

      s.onFaceScore(0.75);
      expect(holdFeedback(s), _nudge);

      s.onFaceScore(0.9);
      expect(holdFeedback(s), _holding, reason: '「很好」併在維持住裡,不另外跳');

      s.onFaceScore(0.1);
      expect(holdFeedback(s), isNull);
    });

    test('做完那一刻不另外講「很好」', () {
      final s = KenkouSession(steps: [faceStep()], defaultHold: _hold);
      s.onFaceScore(0.9);
      s.tracker!.held = s.tracker!.requiredHold;
      s.onFaceScore(0.9);
      expect(s.tracker!.state, HoldState.completed);
      expect(holdFeedback(s), isNull);
    });

    test('張口維持到一半掉下去也不講話:接著數的是 app,不是使用者', () {
      final s = KenkouSession(
          steps: [faceStep(pauseOnDrop: true)], defaultHold: _hold);
      s.onFaceScore(0.9);
      s.tracker!.held = const Duration(seconds: 4);
      s.onFaceScore(0.1);
      expect(s.tracker!.held, const Duration(seconds: 4), reason: '計時確實停在半路');
      expect(holdFeedback(s), isNull);
    });

    test('休息中、引導步驟都不講', () {
      final s = KenkouSession(steps: [faceStep()], defaultHold: _hold)
        ..resting = true;
      expect(holdFeedback(s), isNull);

      const guided = ExerciseStep(
        id: 'g',
        section: 's',
        mode: StepMode.guided,
        cues: [GuidedCue('做', seconds: 5)],
      );
      expect(holdFeedback(KenkouSession(steps: [guided], defaultHold: _hold)),
          isNull);
    });

    test('同一句話、同一個語氣才算相同 —— 穩定判斷靠這個', () {
      expect(const FeedbackMessage('很好!維持住', FeedbackTone.hold), _holding);
      expect(const FeedbackMessage('很好!維持住', FeedbackTone.nudge),
          isNot(_holding));
    });

    Duration ms(int n) => Duration(milliseconds: n);

    test('新的字要連續 0.4 秒都一樣才換上去', () {
      final shown = SettledValue<String?>(ms(400), null);
      final t0 = DateTime(2026);
      expect(shown.update('再用力一點', t0), isNull);
      expect(shown.update('再用力一點', t0.add(ms(399))), isNull);
      expect(shown.update('再用力一點', t0.add(ms(400))), '再用力一點');
    });

    test('中途跳回原本的值就重新計時,抖動被濾掉', () {
      final shown = SettledValue<String?>(ms(400), null);
      final t0 = DateTime(2026);
      shown.update('再用力一點', t0);
      shown.update(null, t0.add(ms(200)));
      shown.update('再用力一點', t0.add(ms(300)));
      expect(shown.update('再用力一點', t0.add(ms(650))), isNull,
          reason: '從 300 毫秒重新算,還不到 0.4 秒');
      expect(shown.update('再用力一點', t0.add(ms(700))), '再用力一點');
    });

    test('換動作時直接清掉,不等', () {
      final shown = SettledValue<String?>(ms(400), '維持住');
      shown.reset(null);
      expect(shown.value, isNull);
    });
  });

  group('臉上的標記', () {
    testWidgets('每一種標記在呼吸動畫的各個時間點都畫得出來', (tester) async {
      final frame = contourFrame();
      for (final marker in FaceMarker.values) {
        for (final pulse in const [0.0, 0.37, 0.99]) {
          final recorder = ui.PictureRecorder();
          FaceMarkerPainter(
            frame: frame,
            marker: marker,
            side: FaceSide.left,
            pulse: pulse,
          ).paint(Canvas(recorder), const Size(390, 844));
          recorder.endRecording().dispose();
        }
      }
    });

    testWidgets('沒有臉或沒有輪廓資料時什麼都不畫,也不會出錯', (tester) async {
      for (final frame in [
        const FaceFrame(hasFace: false),
        const FaceFrame(hasFace: true),
      ]) {
        for (final marker in FaceMarker.values) {
          final recorder = ui.PictureRecorder();
          FaceMarkerPainter(frame: frame, marker: marker, side: FaceSide.right)
              .paint(Canvas(recorder), const Size(390, 844));
          recorder.endRecording().dispose();
        }
      }
    });
  });
}
