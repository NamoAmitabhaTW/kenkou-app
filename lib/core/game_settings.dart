import 'voice/voice_sensitivity.dart';

const kMinGameSeconds = 10;
const kMaxGameSeconds = 180;
const kMinCellsPerSecond = 1.0;
const kMaxCellsPerSecond = 6.0;
const kMinCellsPerCommand = 1;
const kMaxCellsPerCommand = 3;
const kMinTetrisFallSeconds = 1;
const kMaxTetrisFallSeconds = 6;

class GameSettings {
  const GameSettings({
    this.gameSeconds = 30,
    this.cellsPerSecond = 3,
    this.voiceSensitivity = kDefaultVoiceSensitivity,
    this.cellsPerCommand = 2,
    this.tetrisFallSeconds = 3,
    this.showDebug = false,
  });

  final int gameSeconds;

  final double cellsPerSecond;

  final int voiceSensitivity;

  final int cellsPerCommand;

  final int tetrisFallSeconds;

  final bool showDebug;

  double get blankPenalty => blankPenaltyFor(voiceSensitivity);

  GameSettings copyWith({
    int? gameSeconds,
    double? cellsPerSecond,
    int? voiceSensitivity,
    int? cellsPerCommand,
    int? tetrisFallSeconds,
    bool? showDebug,
  }) {
    return GameSettings(
      gameSeconds: gameSeconds ?? this.gameSeconds,
      cellsPerSecond: cellsPerSecond ?? this.cellsPerSecond,
      voiceSensitivity: voiceSensitivity ?? this.voiceSensitivity,
      cellsPerCommand: cellsPerCommand ?? this.cellsPerCommand,
      tetrisFallSeconds: tetrisFallSeconds ?? this.tetrisFallSeconds,
      showDebug: showDebug ?? this.showDebug,
    );
  }

  Map<String, Object?> toJson() => {
        'gameSeconds': gameSeconds,
        'cellsPerSecond': cellsPerSecond,
        'voiceSensitivity': voiceSensitivity,
        'cellsPerCommand': cellsPerCommand,
        'tetrisFallSeconds': tetrisFallSeconds,
        'showDebug': showDebug,
      };

  factory GameSettings.fromJson(Map<String, Object?> json) {
    const defaults = GameSettings();
    return GameSettings(
      gameSeconds: ((json['gameSeconds'] as num?)?.toInt() ?? defaults.gameSeconds)
          .clamp(kMinGameSeconds, kMaxGameSeconds),
      cellsPerSecond:
          ((json['cellsPerSecond'] as num?)?.toDouble() ?? defaults.cellsPerSecond)
              .clamp(kMinCellsPerSecond, kMaxCellsPerSecond),
      voiceSensitivity:
          ((json['voiceSensitivity'] as num?)?.toInt() ?? defaults.voiceSensitivity)
              .clamp(kMinVoiceSensitivity, kMaxVoiceSensitivity),
      cellsPerCommand: _readCellsPerCommand(json, defaults.cellsPerCommand),
      tetrisFallSeconds:
          ((json['tetrisFallSeconds'] as num?)?.toInt() ?? defaults.tetrisFallSeconds)
              .clamp(kMinTetrisFallSeconds, kMaxTetrisFallSeconds),
      showDebug: json['showDebug'] as bool? ?? defaults.showDebug,
    );
  }
}

int _readCellsPerCommand(Map<String, Object?> json, int fallback) {
  final value = (json['cellsPerCommand'] as num?)?.toInt();
  if (value != null) {
    return value.clamp(kMinCellsPerCommand, kMaxCellsPerCommand);
  }
  final legacy = json['stepMove'] as bool?;
  if (legacy != null) return legacy ? kMinCellsPerCommand : kMaxCellsPerCommand;
  return fallback;
}
