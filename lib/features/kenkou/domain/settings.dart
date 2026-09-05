import '../../../core/voice/voice_sensitivity.dart';

const kMinFaceReps = 1;
const kMaxFaceReps = 20;
const kMinPatakaReps = 1;
const kMaxPatakaReps = 20;
const kMinHoldMillis = 500;
const kMaxHoldMillis = 5000;
const kMinStrictness = 60;
const kMaxStrictness = 95;

/// 健口操的次數與判定參數,全部收在首頁右上角的齒輪後面。
///
/// 次數的預設值照日本牙醫師會的「口腔體操」頁面:パタカラ 各 8 次。
/// 嘴型動作的次數官網只寫「數回」,先給 5。
///
/// **這裡的每一個欄位都真的有人讀。** 以前還有 `openHoldSeconds`、
/// `patakaSets`、`includeGuided` 三個欄位,有預設值、有 copyWith、有夾範圍的
/// 上下限常數、也存進 JSON —— 但 [buildProgram] 從來沒讀過,設定畫面也沒露出來。
/// 那種欄位比沒有還糟:它讓讀的人以為調得動,實際上調了不會有任何事發生。
class KenkouSettings {
  const KenkouSettings({
    this.faceReps = 5,
    this.holdMillis = 1500,
    this.patakaReps = 8,
    this.strictness = 80,
    this.voiceSensitivity = kDefaultVoiceSensitivity,
    this.showDebug = false,
  });

  /// 每個嘴型動作(嘟嘴、張大嘴巴、「衣～」)要做幾次。
  final int faceReps;

  /// 嘴型要維持多久才算一次。
  final int holdMillis;

  /// パタカラ 每個音節要說幾次。
  final int patakaReps;

  /// 嘴型判定嚴格度,60~95。對應 [HoldTracker] 的進入門檻。
  final int strictness;

  /// 語音靈敏度 1(遲鈍)~5(敏感)。越敏感越容易誤判環境音。
  final int voiceSensitivity;

  /// 在畫面上顯示判定數值。調參數時用。
  final bool showDebug;


  Duration get hold => Duration(milliseconds: holdMillis);

  double get enterThreshold => strictness / 100;

  /// 換算表跟吃金幣共用,見 [blankPenaltyFor]。
  double get blankPenalty => blankPenaltyFor(voiceSensitivity);

  KenkouSettings copyWith({
    int? faceReps,
    int? holdMillis,
    int? patakaReps,
    int? strictness,
    int? voiceSensitivity,
    bool? showDebug,
  }) {
    return KenkouSettings(
      faceReps: faceReps ?? this.faceReps,
      holdMillis: holdMillis ?? this.holdMillis,
      patakaReps: patakaReps ?? this.patakaReps,
      strictness: strictness ?? this.strictness,
      voiceSensitivity: voiceSensitivity ?? this.voiceSensitivity,
      showDebug: showDebug ?? this.showDebug,
    );
  }

  Map<String, Object?> toJson() => {
        'faceReps': faceReps,
        'holdMillis': holdMillis,
        'patakaReps': patakaReps,
        'strictness': strictness,
        'voiceSensitivity': voiceSensitivity,
        'showDebug': showDebug,
      };

  /// 每個數字都夾回合法範圍 —— 設定檔可能是舊版本寫的,也可能被手動改過。
  factory KenkouSettings.fromJson(Map<String, Object?> json) {
    const defaults = KenkouSettings();
    int read(String key, int fallback, int min, int max) =>
        ((json[key] as num?)?.toInt() ?? fallback).clamp(min, max);

    return KenkouSettings(
      faceReps: read('faceReps', defaults.faceReps, kMinFaceReps, kMaxFaceReps),
      holdMillis: read(
          'holdMillis', defaults.holdMillis, kMinHoldMillis, kMaxHoldMillis),
      patakaReps: read(
          'patakaReps', defaults.patakaReps, kMinPatakaReps, kMaxPatakaReps),
      strictness: read(
          'strictness', defaults.strictness, kMinStrictness, kMaxStrictness),
      voiceSensitivity: read('voiceSensitivity', defaults.voiceSensitivity,
          kMinVoiceSensitivity, kMaxVoiceSensitivity),
      showDebug: json['showDebug'] as bool? ?? defaults.showDebug,
    );
  }
}
