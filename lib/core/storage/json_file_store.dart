import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract class JsonFileStore<T> {
  const JsonFileStore();

  String get folder;

  String get fileName;

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
