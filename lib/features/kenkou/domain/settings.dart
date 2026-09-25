import '../../../core/voice/voice_sensitivity.dart';

const kMinFaceReps = 1;
const kMaxFaceReps = 20;
const kMinPatakaReps = 1;
const kMaxPatakaReps = 20;
const kMinHoldMillis = 500;
const kMaxHoldMillis = 5000;
const kMinStrictness = 60;
const kMaxStrictness = 95;

class KenkouSettings {
  const KenkouSettings({
    this.faceReps = 5,
    this.holdMillis = 3000,
    this.patakaReps = 8,
    this.strictness = 80,
    this.voiceSensitivity = kDefaultVoiceSensitivity,
    this.showDebug = false,
  });

  final int faceReps;

  final int holdMillis;

  final int patakaReps;

  final int strictness;

  final int voiceSensitivity;

  final bool showDebug;

  Duration get hold => Duration(milliseconds: holdMillis);

  double get enterThreshold => strictness / 100;

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
