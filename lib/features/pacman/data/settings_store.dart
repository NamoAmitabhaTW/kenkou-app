import '../../../core/storage/json_file_store.dart';
import '../../../core/game_settings.dart';

/// 設定檔:`Documents/pacman/settings.json`
///
/// 存的是兩個小遊戲共用的 [GameSettings]。資料夾名稱維持 `pacman` 而不是改成
/// `games` —— 改了之後使用者存過的設定就讀不到、全部退回預設值。
class GameSettingsStore extends JsonFileStore<GameSettings> {
  const GameSettingsStore();

  @override
  String get folder => 'pacman';

  @override
  String get fileName => 'settings.json';

  @override
  GameSettings get defaults => const GameSettings();

  @override
  GameSettings fromJson(Map<String, Object?> json) =>
      GameSettings.fromJson(json);

  @override
  Map<String, Object?> toJson(GameSettings value) => value.toJson();
}
