import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 一份存在 app 沙盒裡的 JSON 設定檔。
///
///   `Documents/<folder>/<fileName>`
///
/// 健口操和吃金幣的設定檔以前各自抄了一份一模一樣的
/// 「建資料夾 → 讀檔 → decode → 壞掉就回預設 → encode 寫回」。
/// 收成這個基底之後,兩邊的設定類別只剩下真正屬於自己的東西:欄位、
/// 預設值、以及 JSON 怎麼對應。
///
/// 讀檔一律不丟例外 —— 設定檔壞掉就退回預設值。一個讀不出來的偏好設定
/// 不值得讓整個功能開不起來。
abstract class JsonFileStore<T> {
  const JsonFileStore();

  /// 沙盒 Documents 底下的資料夾名。
  String get folder;

  /// 檔名,例如 `settings.json`。
  String get fileName;

  /// 檔案不存在或壞掉時用的值。
  T get defaults;

  T fromJson(Map<String, Object?> json);
  Map<String, Object?> toJson(T value);

  Future<File> _file() async {
    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory('${documents.path}/$folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$fileName');
  }

  Future<T> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return defaults;
      return fromJson(
        jsonDecode(await file.readAsString()) as Map<String, Object?>,
      );
    } catch (_) {
      return defaults;
    }
  }

  Future<void> save(T value) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(toJson(value)), flush: true);
  }
}
