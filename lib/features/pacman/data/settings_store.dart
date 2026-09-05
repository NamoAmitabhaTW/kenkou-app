import '../../../core/storage/json_file_store.dart';
import '../domain/settings.dart';

/// 設定檔:`Documents/pacman/settings.json`
class PacmanSettingsStore extends JsonFileStore<PacmanSettings> {
  const PacmanSettingsStore();

  @override
  String get folder => 'pacman';

  @override
  String get fileName => 'settings.json';

  @override
  PacmanSettings get defaults => const PacmanSettings();

  @override
  PacmanSettings fromJson(Map<String, Object?> json) =>
      PacmanSettings.fromJson(json);

  @override
  Map<String, Object?> toJson(PacmanSettings value) => value.toJson();
}
