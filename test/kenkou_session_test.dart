import 'package:face_mesh/face_mesh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremode2026/core/voice/syllable.dart';
import 'package:futuremode2026/features/kenkou/domain/exercise_program.dart';
import 'package:futuremode2026/features/kenkou/domain/face_geometry.dart';
import 'package:futuremode2026/features/kenkou/domain/settings.dart';
import 'package:futuremode2026/features/kenkou/domain/mouth_shape.dart';
import 'package:futuremode2026/features/kenkou/domain/session_runner.dart';
import 'package:futuremode2026/core/voice/syllable_map.dart';

void main() {
  ExerciseStep face(String id, List<MouthShape> shapes, {int reps = 2}) =>
      ExerciseStep(
        id: id,
        section: 's',
        mode: StepMode.face,
        shapes: shapes,
        reps: reps,
      );

  ExerciseStep speech(Syllable syllable, {int reps = 2}) => ExerciseStep(
        id: 'speech_${syllable.name}',
        section: 's',
        mode: StepMode.speech,
        syllable: syllable,
        reps: reps,
      );

  const guided = ExerciseStep(
    id: 'guided',
    section: 's',
    mode: StepMode.guided,
    cues: [GuidedCue('做', seconds: 5)],
  );

  KenkouSession session(List<ExerciseStep> steps) =>
      KenkouSession(steps: steps, defaultHold: Duration.zero);

  SessionEvent doOneRep(KenkouSession s) {
    s.onFaceScore(0.9);
    final event = s.onFaceScore(0.9);
    s.onFaceScore(0.0);
    return event;
  }

  group('嘴型動作', () {
    test('維持住算一次,次數到了就完成這個動作', () {
      final s = session([face('a', [MouthShape.a], reps: 2), guided]);

      expect(doOneRep(s), SessionEvent.rep);
      expect(s.reps, 1);
      expect(doOneRep(s), SessionEvent.stepDone);
      expect(s.stepComplete, isTrue);
      expect(s.completedSteps, 1);
    });

    test('沒有放鬆回來就不能刷次數', () {
      final s = session([face('a', [MouthShape.a], reps: 5)]);

      s.onFaceScore(0.9);
      s.onFaceScore(0.9);
      expect(s.reps, 1);
      for (var i = 0; i < 10; i++) {
        expect(s.onFaceScore(0.9), SessionEvent.none);
      }
      expect(s.reps, 1);
    });

    test('分數低於門檻不算', () {
      final s = session([face('a', [MouthShape.a])]);
      for (var i = 0; i < 10; i++) {
        expect(s.onFaceScore(0.5), SessionEvent.none);
      }
      expect(s.reps, 0);
    });

    test('多段動作(鼓頰 → 縮嘴)整組做完才算一次', () {
      final s = session([
        face('cheek', [MouthShape.cheekPuff, MouthShape.u], reps: 1),
      ]);

      expect(s.targetShape, MouthShape.cheekPuff);
      expect(s.nextShape, MouthShape.u);

      expect(doOneRep(s), SessionEvent.partial);
      expect(s.reps, 0);
      expect(s.targetShape, MouthShape.u);
      expect(s.nextShape, isNull);

      expect(doOneRep(s), SessionEvent.stepDone);
      expect(s.reps, 1);
    });

    test('多段動作做完一組就從頭開始,放鬆的臉分數偏高也不會卡住', () {
      final s = session([
        face('cheek', [MouthShape.cheekPuff, MouthShape.cheekSuck], reps: 2),
      ]);
      doOneRep(s);
      s.onFaceScore(0.9);
      expect(s.onFaceScore(0.9), SessionEvent.rep);
      expect(s.targetShape, MouthShape.cheekPuff);

      s.onFaceScore(0.71);
      expect(s.tracker!.state, isNot(HoldState.completed));
      s.onFaceScore(0.9);
      expect(s.onFaceScore(0.9), SessionEvent.partial, reason: '下一組的鼓頰照常算');
    });

    test('次數到了之後的輸入全部忽略,直到 advance', () {
      final s = session([face('a', [MouthShape.a], reps: 1), guided]);

      expect(doOneRep(s), SessionEvent.stepDone);
      expect(doOneRep(s), SessionEvent.none);
      expect(s.index, 0);

      s.advance();
      expect(s.index, 1);
      expect(s.stepComplete, isFalse);
      expect(s.reps, 0);
    });
  });

  group('パタカラ', () {
    test('只有目標音節算數', () {
      final s = session([speech(Syllable.pa, reps: 2)]);
      var at = DateTime(2026);
      SessionEvent say(Syllable syllable) {
        at = at.add(const Duration(seconds: 1));
        return s.onSyllable(syllable, at: at);
      }

      expect(say(Syllable.ta), SessionEvent.none);
      expect(s.reps, 0);
      expect(say(Syllable.pa), SessionEvent.rep);
      expect(say(Syllable.pa), SessionEvent.stepDone);
    });

    test('一次發音被吐成好幾個結果,只算一次', () {
      final s = session([speech(Syllable.pa, reps: 3)]);
      final at = DateTime(2026);

      expect(s.onSyllable(Syllable.pa, at: at), SessionEvent.rep);
      expect(s.reps, 1);
      expect(s.onSyllable(Syllable.pa, at: at), SessionEvent.none);
      expect(
          s.onSyllable(Syllable.pa,
              at: at.add(const Duration(milliseconds: 120))),
          SessionEvent.none);
      expect(
          s.onSyllable(Syllable.pa,
              at: at.add(const Duration(milliseconds: 399))),
          SessionEvent.none);
      expect(s.reps, 1, reason: '整串重複只能算一次');
    });

    test('冷卻過了就是新的一次發音', () {
      final s = session([speech(Syllable.pa, reps: 3)]);
      final at = DateTime(2026);

      expect(s.onSyllable(Syllable.pa, at: at), SessionEvent.rep);
      expect(s.onSyllable(Syllable.pa, at: at.add(KenkouSession.repCooldown)),
          SessionEvent.rep);
      expect(s.reps, 2);
    });

    test('換一個動作之後冷卻重新計算', () {
      final s = session([
        speech(Syllable.pa, reps: 1),
        speech(Syllable.ta, reps: 1),
      ]);
      final at = DateTime(2026);

      expect(s.onSyllable(Syllable.pa, at: at), SessionEvent.stepDone);
      s.advance();
      expect(
          s.onSyllable(Syllable.ta,
              at: at.add(const Duration(milliseconds: 10))),
          SessionEvent.stepDone);
    });

    test('嘴型分數餵給語音步驟不會有反應', () {
      final s = session([speech(Syllable.pa)]);
      expect(s.onFaceScore(0.95), SessionEvent.none);
      expect(s.onFaceScore(0.95), SessionEvent.none);
      expect(s.reps, 0);
    });

    test('嘴唇偵測只救 パ:目標是パ、聽成タ/カ、剛才有閉唇,才改判成パ', () {
      expect(resolveSyllable(heard: Syllable.ta, target: Syllable.pa, lipsClosed: true), Syllable.pa);
      expect(resolveSyllable(heard: Syllable.ka, target: Syllable.pa, lipsClosed: true), Syllable.pa);
      expect(resolveSyllable(heard: Syllable.ta, target: Syllable.pa, lipsClosed: false), Syllable.ta);
      expect(resolveSyllable(heard: Syllable.pa, target: Syllable.ta, lipsClosed: false), Syllable.pa);
      expect(resolveSyllable(heard: Syllable.pa, target: Syllable.ta, lipsClosed: true), Syllable.pa);
      expect(resolveSyllable(heard: Syllable.ra, target: Syllable.ra, lipsClosed: true), Syllable.ra);
    });

    test('手動計次只在語音步驟有效', () {
      final s = session([speech(Syllable.ka, reps: 1), guided]);
      expect(s.countManually(), SessionEvent.stepDone);
      s.advance();
      expect(s.countManually(), SessionEvent.none);
    });

    test('增量解析:德文切詞,最後一個詞先照現在的樣子算', () {
      final (de, seenDe) = parseGermanIncrement('Pa, paar, K, ra ra.', 0);
      expect(de.map((p) => p.label), ['pa', 'pa', 'ka', 'la', 'la']);
      expect(seenDe, 5);
      expect(parseGermanIncrement('Pa, paar, K, ra ra.', 5).$1, isEmpty);
    });

    test('德文模型的字對得回音節:大小寫、標點、黏在一起的 paar 都處理', () {
      expect(germanSyllable('Pa,'), 'pa');
      expect(germanSyllable('paar'), 'pa');
      expect(germanSyllable('K'), 'ka');
      expect(germanSyllable('T'), 'ta');
      expect(germanSyllable('t'), 'ta');
      expect(germanSyllable('ra.'), 'la');
      expect(germanSyllable('Train'), isNull);
      expect(germanSyllable(''), isNull);
    });
  });

  group('手動完成', () {
    test('偵測不到時可以手動宣告完成,算完成不算跳過', () {
      final s = session([guided]);
      expect(s.completeManually(), SessionEvent.stepDone);
      expect(s.completedSteps, 1);
      expect(s.skippedSteps, 0);
    });

  });

  group('引導步驟與流程', () {
    test('引導步驟只能靠 completeGuided 完成', () {
      final s = session([guided]);
      expect(s.onSyllable(Syllable.pa, at: DateTime(2026)), SessionEvent.none);
      expect(s.onFaceScore(0.9), SessionEvent.none);
      expect(s.completeGuided(), SessionEvent.stepDone);
      expect(s.completedSteps, 1);
    });

    test('跳過不算完成', () {
      final s = session([guided, guided]);
      expect(s.skip(), SessionEvent.stepDone);
      expect(s.skippedSteps, 1);
      expect(s.completedSteps, 0);
      expect(s.skip(), SessionEvent.none);
    });

    test('最後一個動作 advance 之後整套結束', () {
      final s = session([guided, guided]);
      s.completeGuided();
      s.advance();
      expect(s.isFinished, isFalse);
      s.completeGuided();
      s.advance();
      expect(s.isFinished, isTrue);
      expect(s.completedSteps, 2);
      s.advance();
      expect(s.isFinished, isTrue);
    });
  });

  group('休息(張口訓練)', () {
    ExerciseStep withRest({int reps = 2}) => ExerciseStep(
          id: 'open',
          section: 's',
          mode: StepMode.face,
          shapes: const [MouthShape.a],
          reps: reps,
          rest: const Duration(seconds: 10),
        );

    test('做完一次先休息,休息完才做下一次;最後一次休息完才算完成', () {
      final s = session([withRest(reps: 2), guided]);

      expect(doOneRep(s), SessionEvent.rest);
      expect(s.reps, 1);
      expect(s.resting, isTrue);
      expect(s.currentRound, 1, reason: '休息屬於剛做完的第 1 次');

      expect(s.finishRest(), SessionEvent.none);
      expect(s.resting, isFalse);
      expect(s.currentRound, 2);

      expect(doOneRep(s), SessionEvent.rest);
      expect(s.reps, 2);
      expect(s.stepComplete, isFalse, reason: '最後一次也要先休息');

      expect(s.finishRest(), SessionEvent.stepDone);
      expect(s.completedSteps, 1);
    });

    test('休息中嘴型分數不算數', () {
      final s = session([withRest(reps: 3)]);
      expect(doOneRep(s), SessionEvent.rest);
      expect(doOneRep(s), SessionEvent.none);
      expect(s.reps, 1);
    });

    test('休息完從頭開始下一次,不會停在上一次的「完成」', () {
      final s = session([withRest(reps: 2)]);
      s.onFaceScore(0.9);
      s.onFaceScore(0.9);
      expect(s.tracker!.state, HoldState.completed);

      s.finishRest();
      expect(s.tracker!.state, HoldState.idle);
    });

    test('休息中可以跳過,算跳過不算完成', () {
      final s = session([withRest(), guided]);
      doOneRep(s);
      expect(s.skip(), SessionEvent.stepDone);
      expect(s.resting, isFalse);
      expect(s.skippedSteps, 1);
      expect(s.completedSteps, 0);
    });

    test('沒在休息時 finishRest 沒有作用', () {
      final s = session([withRest()]);
      expect(s.finishRest(), SessionEvent.none);
      expect(s.reps, 0);
    });
  });

  group('分段的引導步驟', () {
    const cued = ExerciseStep(
      id: 'cued',
      section: 's',
      mode: StepMode.guided,
      cues: [
        GuidedCue('一', seconds: 3),
        GuidedCue('二', seconds: 5),
        GuidedCue('三', seconds: 4),
      ],
    );

    test('每段倒數完換下一段,最後一段完才算完成', () {
      final s = session([cued]);
      expect(s.currentCue!.text, '一');

      expect(s.completeGuided(), SessionEvent.partial);
      expect(s.currentCue!.text, '二');
      expect(s.currentCue!.seconds, 5);

      expect(s.completeGuided(), SessionEvent.partial);
      expect(s.completeGuided(), SessionEvent.stepDone);
      expect(s.completedSteps, 1);
    });

    test('reps 大於 1 時整組分段重複做,第幾組跟著走', () {
      const repeated = ExerciseStep(
        id: 'cheeks',
        section: 's',
        mode: StepMode.guided,
        reps: 3,
        cues: [
          GuidedCue('鼓起臉頰', seconds: 3),
          GuidedCue('縮起臉頰', seconds: 3),
        ],
      );
      final s = session([repeated]);
      expect(s.step.guidedCues, hasLength(6));
      expect(s.currentRound, 1);

      expect(s.completeGuided(), SessionEvent.partial);
      expect(s.currentCue!.text, '縮起臉頰');
      expect(s.currentRound, 1, reason: '鼓起、縮起都做完才換下一組');

      expect(s.completeGuided(), SessionEvent.partial);
      expect(s.currentCue!.text, '鼓起臉頰');
      expect(s.currentRound, 2);

      s.completeGuided();
      s.completeGuided();
      s.completeGuided();
      expect(s.currentRound, 3);
      expect(s.completeGuided(), SessionEvent.stepDone);
    });

    test('換到下一個動作時分段從頭開始', () {
      final s = session([cued, cued]);
      s.completeGuided();
      s.completeGuided();
      s.completeGuided();
      s.advance();
      expect(s.currentCue!.text, '一');
    });

    test('嘴型步驟的第幾組是「正在做的那一組」', () {
      final s = session([face('lips', [MouthShape.u, MouthShape.i], reps: 3)]);
      expect(s.currentRound, 1);
      doOneRep(s);
      expect(s.currentRound, 1, reason: '屋做完、衣還沒,還在第 1 組');
      doOneRep(s);
      expect(s.currentRound, 2);
    });

    test('嘴型和語音步驟沒有分段提示', () {
      expect(session([face('a', [MouthShape.a])]).currentCue, isNull);
      expect(session([speech(Syllable.pa)]).currentCue, isNull);
    });
  });

  group('整套內容', () {
    test('次數跟著設定走', () {
      const settings = KenkouSettings(faceReps: 7, patakaReps: 3);
      final steps = buildProgram(settings);
      ExerciseStep byId(String id) => steps.firstWhere((s) => s.id == id);

      expect(byId('mouth_pucker').reps, 7);

      final pataka = steps.where((s) => s.mode == StepMode.speech).toList();
      expect(pataka, hasLength(4));
      expect(pataka.every((s) => s.reps == 3), isTrue);
      expect(pataka.map((s) => s.syllable), Syllable.values);
    });

    test('整套 9 個動作', () {
      final steps = buildProgram(const KenkouSettings());
      expect(steps.map((s) => s.id), [
        'mouth_pucker', 'mouth_open', 'mouth_ii', 'tongue_press_left', 'tongue_press_right', 'pataka_pa_1', 'pataka_ta_1', 'pataka_ka_1', 'pataka_ra_1',
      ]);
      final press = steps.where((s) => s.marker == FaceMarker.cheek).toList();
      expect(press.map((s) => s.side), [FaceSide.left, FaceSide.right]);
      expect(press.every((s) => s.mode == StepMode.guided), isTrue);
    });

    test('引導步驟都有分段提示,每一段都有字、倒數都大於 0 秒', () {
      final guidedSteps = buildProgram(const KenkouSettings())
          .where((s) => s.mode == StepMode.guided);
      for (final step in guidedSteps) {
        expect(step.guidedCues, isNotEmpty, reason: step.id);
        for (final cue in step.guidedCues) {
          expect(cue.text, isNotEmpty, reason: step.id);
          expect(cue.seconds, greaterThan(0), reason: step.id);
        }
      }
    });

    test('動作 id 不重複', () {
      final ids = buildProgram(const KenkouSettings()).map((s) => s.id);
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('設定', () {
    test('JSON 來回一致', () {
      const original = KenkouSettings(
        faceReps: 9,
        holdMillis: 2500,
        patakaReps: 6,
        strictness: 70,
        voiceSensitivity: 5,
        showDebug: true,
      );
      final restored = KenkouSettings.fromJson(original.toJson());
      expect(restored.toJson(), original.toJson());
    });

    test('壞掉或缺欄位的 JSON 退回預設並夾在範圍內', () {
      final s = KenkouSettings.fromJson({'faceReps': 999, 'labelSystem': 'nope'});
      expect(s.faceReps, kMaxFaceReps);
      expect(s.patakaReps, const KenkouSettings().patakaReps);
    });

    test('嚴格度與靈敏度換算', () {
      expect(const KenkouSettings(strictness: 80).enterThreshold, 0.8);
      expect(const KenkouSettings(voiceSensitivity: 3).blankPenalty, 0);
      expect(const KenkouSettings(voiceSensitivity: 5).blankPenalty,
          greaterThan(const KenkouSettings(voiceSensitivity: 1).blankPenalty));
    });
  });

  group('閉唇判定', () {
    FaceFrame open(double ratio) =>
        FaceFrame(hasFace: true, mouthOpenRatio: ratio);

    test('沒校正時用保守的預設門檻(基準 0.008 + 餘裕 0.006)', () {
      final lips = LipsClosedDetector();
      expect(lips.threshold, closeTo(0.014, 1e-9));
      expect(lips.isClosed(open(0.010)), isTrue);
      expect(lips.isClosed(open(0.020)), isFalse);
    });

    test('校正之後門檻跟著使用者的放鬆基準走', () {
      final lips = LipsClosedDetector()
        ..calibrate([open(0.020), open(0.030), open(0.025)]);
      expect(lips.threshold, closeTo(0.031, 1e-9));
      expect(lips.isClosed(open(0.028)), isTrue);
      expect(lips.isClosed(open(0.035)), isFalse);
    });

    test('沒有臉的影格不列入校正,也一律不算閉唇', () {
      final lips = LipsClosedDetector()
        ..calibrate([const FaceFrame(hasFace: false), open(0.020)]);
      expect(lips.threshold, closeTo(0.026, 1e-9));
      expect(lips.isClosed(const FaceFrame(hasFace: false)), isFalse);
    });

    test('全部都沒有臉時保留原本的門檻', () {
      final lips = LipsClosedDetector()
        ..calibrate([const FaceFrame(hasFace: false)]);
      expect(lips.threshold, closeTo(0.014, 1e-9));
    });
  });
}
