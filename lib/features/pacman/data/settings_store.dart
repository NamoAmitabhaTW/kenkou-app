import '../../../core/storage/json_file_store.dart';
import '../../../core/game_settings.dart';

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
