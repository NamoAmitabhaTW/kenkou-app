import 'voice/voice_sensitivity.dart';

const kMinGameSeconds = 10;
const kMaxGameSeconds = 180;
const kMinCellsPerSecond = 1.0;
const kMaxCellsPerSecond = 6.0;
const kMinCellsPerCommand = 1;
const kMaxCellsPerCommand = 3;
const kMinTetrisFallSeconds = 1;
const kMaxTetrisFallSeconds = 6;

/// 小遊戲分頁的設定,收在首頁右上角的齒輪後面。
///
/// 吃金幣和俄羅斯方塊共用一份 —— 語音靈敏度本來就該一致(同一顆模型、
/// 同一個刻度),各自獨立的項目就多一個欄位。
///
/// 放在 core 而不是任何一個 feature 底下:兩個 feature 都要用,擺進其中一邊
/// 就會讓另一邊得跨 feature 引用,架構測試會擋。
class GameSettings {
  const GameSettings({
    this.gameSeconds = 30,
    this.cellsPerSecond = 3,
    this.voiceSensitivity = kDefaultVoiceSensitivity,
    this.cellsPerCommand = 2,
    this.tetrisFallSeconds = 3,
    this.showDebug = false,
  });

  /// 一局幾秒。
  final int gameSeconds;

  /// 小精靈一秒走幾格。
  final double cellsPerSecond;

  /// 語音靈敏度 1(遲鈍)~5(敏感),跟健口操同一套刻度。
  final int voiceSensitivity;

  /// 念一次走幾格,走完就停下來等下一個指令。
  ///
  /// 預設 2:迷宮裡相鄰路口的間距多半就是 2 格(實測 16 處是 2、8 處是 4),
  /// 所以念一次剛好停在下一個路口上,不會衝過頭。
  final int cellsPerCommand;

  /// 俄羅斯方塊的方塊多久掉一格,秒。
  ///
  /// 語音慢半拍,掉太快來不及喊完、看到反應、再決定下一步。
  final int tetrisFallSeconds;

  /// 在畫面上顯示辨識器聽到什麼。調參數時用。
  final bool showDebug;

  /// 換算表跟健口操共用,見 [blankPenaltyFor]。
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

  /// 每個數字都夾回合法範圍 —— 設定檔可能是舊版本寫的,也可能被手動改過。
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

/// 讀「念一次走幾格」,順便把舊版的 stepMove 換算過來。
///
/// 舊版是布林:true = 只走一格、false = 一路走到撞牆。走到底那個模式已經拿掉
/// (地圖左右兩端上方都是牆,走到底會卡在死角只能掉頭),所以換算成最大格數。
int _readCellsPerCommand(Map<String, Object?> json, int fallback) {
  final value = (json['cellsPerCommand'] as num?)?.toInt();
  if (value != null) {
    return value.clamp(kMinCellsPerCommand, kMaxCellsPerCommand);
  }
  final legacy = json['stepMove'] as bool?;
  if (legacy != null) return legacy ? kMinCellsPerCommand : kMaxCellsPerCommand;
  return fallback;
}
