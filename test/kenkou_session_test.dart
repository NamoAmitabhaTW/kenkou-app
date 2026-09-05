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
        title: id,
        instruction: '',
        mode: StepMode.face,
        shapes: shapes,
        reps: reps,
      );

  ExerciseStep speech(Syllable syllable, {int reps = 2}) => ExerciseStep(
        id: 'speech_${syllable.name}',
        section: 's',
        title: '',
        instruction: '',
        mode: StepMode.speech,
        syllable: syllable,
        reps: reps,
      );

  const guided = ExerciseStep(
    id: 'guided',
    section: 's',
    title: '',
    instruction: '',
    mode: StepMode.guided,
    guidedSeconds: 5,
  );

  /// hold 設成 0:第一張達標影格進入 holding,第二張就算完成。
  KenkouSession session(List<ExerciseStep> steps) =>
      KenkouSession(steps: steps, defaultHold: Duration.zero);

  /// 做到位、維持、放鬆 —— 一次完整的動作。
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
      // 模型對同一聲吐出的重複結果,時間幾乎一樣。
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
      // 只差 10 毫秒,但已經是另一個動作了,不該被上一個動作的冷卻擋掉。
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
      // 反過來不救:目標是タ、聽成パ,就是パ,不能因為嘴唇開著就算タ。
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
      // 模型有時只吐一個字母,大小寫都要算(正規化會先轉小寫)。
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

  group('整套內容', () {
    test('次數跟著設定走', () {
      const settings = KenkouSettings(faceReps: 7, patakaReps: 3);
      final steps = buildProgram(settings);

      final pucker = steps.firstWhere((s) => s.id == 'mouth_pucker');
      expect(pucker.reps, 7);

      // パタカラ 固定一組,四個音各一個動作。
      final pataka = steps.where((s) => s.mode == StepMode.speech).toList();
      expect(pataka, hasLength(4));
      expect(pataka.every((s) => s.reps == 3), isTrue);
      expect(pataka.map((s) => s.syllable).take(4), Syllable.values);
    });

    test('整套只有嘟嘴、張嘴、衣、舌頂左右、パタカラ 一組,共 9 個動作', () {
      final steps = buildProgram(const KenkouSettings());
      expect(steps.map((s) => s.id), [
        'mouth_pucker', 'mouth_open', 'mouth_ii',
        'tongue_press_left', 'tongue_press_right',
        'pataka_pa_1', 'pataka_ta_1', 'pataka_ka_1', 'pataka_ra_1',
      ]);
      final press = steps.where((s) => s.marker == FaceMarker.cheek).toList();
      expect(press.map((s) => s.side), [FaceSide.left, FaceSide.right]);
      expect(press.every((s) => s.mode == StepMode.guided), isTrue);
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
      // 多出來的欄位(舊版設定檔留下的)要被忽略,不能讓整包解析失敗。
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
    // 這幾個數字是判定 パ 的鬆緊,調動它會直接改變「說一次算不算一次」。
    // 有人動到就該紅燈,不要靠 code review 抓。
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
      // 平均 0.025,加上固定餘裕 0.006。
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
