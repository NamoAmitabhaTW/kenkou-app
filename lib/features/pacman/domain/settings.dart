import '../../../core/voice/voice_sensitivity.dart';

const kMinGameSeconds = 10;
const kMaxGameSeconds = 180;
const kMinCellsPerSecond = 1.0;
const kMaxCellsPerSecond = 6.0;

/// 吃金幣遊戲的設定,收在首頁右上角的齒輪後面。
class PacmanSettings {
  const PacmanSettings({
    this.gameSeconds = 30,
    this.cellsPerSecond = 3,
    this.voiceSensitivity = kDefaultVoiceSensitivity,
    this.stepMove = false,
    this.showDebug = false,
  });

  /// 一局幾秒。
  final int gameSeconds;

  /// 小精靈一秒走幾格。
  final double cellsPerSecond;

  /// 語音靈敏度 1(遲鈍)~5(敏感),跟健口操同一套刻度。
  final int voiceSensitivity;

  /// true = 念一次只走一格;false = 念一次一路走到撞牆。
  final bool stepMove;

  /// 在畫面上顯示辨識器聽到什麼。調參數時用。
  final bool showDebug;

  /// 換算表跟健口操共用,見 [blankPenaltyFor]。
  double get blankPenalty => blankPenaltyFor(voiceSensitivity);

  PacmanSettings copyWith({
    int? gameSeconds,
    double? cellsPerSecond,
    int? voiceSensitivity,
    bool? stepMove,
    bool? showDebug,
  }) {
    return PacmanSettings(
      gameSeconds: gameSeconds ?? this.gameSeconds,
      cellsPerSecond: cellsPerSecond ?? this.cellsPerSecond,
      voiceSensitivity: voiceSensitivity ?? this.voiceSensitivity,
      stepMove: stepMove ?? this.stepMove,
      showDebug: showDebug ?? this.showDebug,
    );
  }

  Map<String, Object?> toJson() => {
        'gameSeconds': gameSeconds,
        'cellsPerSecond': cellsPerSecond,
        'voiceSensitivity': voiceSensitivity,
        'stepMove': stepMove,
        'showDebug': showDebug,
      };

  /// 每個數字都夾回合法範圍 —— 設定檔可能是舊版本寫的,也可能被手動改過。
  factory PacmanSettings.fromJson(Map<String, Object?> json) {
    const defaults = PacmanSettings();
    return PacmanSettings(
      gameSeconds: ((json['gameSeconds'] as num?)?.toInt() ?? defaults.gameSeconds)
          .clamp(kMinGameSeconds, kMaxGameSeconds),
      cellsPerSecond:
          ((json['cellsPerSecond'] as num?)?.toDouble() ?? defaults.cellsPerSecond)
              .clamp(kMinCellsPerSecond, kMaxCellsPerSecond),
      voiceSensitivity:
          ((json['voiceSensitivity'] as num?)?.toInt() ?? defaults.voiceSensitivity)
              .clamp(kMinVoiceSensitivity, kMaxVoiceSensitivity),
      stepMove: json['stepMove'] as bool? ?? defaults.stepMove,
      showDebug: json['showDebug'] as bool? ?? defaults.showDebug,
    );
  }
}
