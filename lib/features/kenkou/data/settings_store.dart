import '../../../core/storage/json_file_store.dart';
import '../domain/settings.dart';

/// 設定檔:`Documents/kenkou/settings.json`
class KenkouSettingsStore extends JsonFileStore<KenkouSettings> {
  const KenkouSettingsStore();

  @override
  String get folder => 'kenkou';

  @override
  String get fileName => 'settings.json';

  @override
  KenkouSettings get defaults => const KenkouSettings();

  @override
  KenkouSettings fromJson(Map<String, Object?> json) =>
      KenkouSettings.fromJson(json);

  @override
  Map<String, Object?> toJson(KenkouSettings value) => value.toJson();
}
