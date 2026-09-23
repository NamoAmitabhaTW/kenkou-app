import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../domain/question.dart';
import '../domain/bank.dart';
import '../domain/seed_questions.dart';

class QuizStore {
  static const _folder = 'quiz';
  static const _bankFileName = 'bank.json';
  static const _seedAssetFolder = 'assets/quiz';

  Directory? _cachedDir;
  QuizBank? _cachedBank;

  Future<Directory> directory() async {
    final cached = _cachedDir;
    if (cached != null) return cached;

    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory('${documents.path}/$_folder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _cachedDir = dir;
  }

  Future<String> resolve(String fileName) async =>
      '${(await directory()).path}/$fileName';

  Future<QuizBank> load() async {
    final cached = _cachedBank;
    if (cached != null) return cached;
    return _cachedBank = await _installSeeds(await _read());
  }

  Future<QuizBank> _installSeeds(QuizBank bank) async {
    final missing = bank.missingSeeds();
    if (missing.isEmpty && bank.seededVersion >= kSeedVersion) return bank;

    try {
      for (final question in missing) {
        for (final fileName in question.mediaFiles) {
          await _copyAsset(fileName);
        }
      }
      return await _persist(bank.withSeeds(missing));
    } catch (_) {
      return bank;
    }
  }

  Future<void> _copyAsset(String fileName) async {
    final data = await rootBundle.load('$_seedAssetFolder/$fileName');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await File(await resolve(fileName)).writeAsBytes(bytes, flush: true);
  }

  Future<QuizBank> _read() async {
    final file = File('${(await directory()).path}/$_bankFileName');
    if (!await file.exists()) return QuizBank.empty();

    try {
      return QuizBank.decode(await file.readAsString());
    } catch (_) {
      return QuizBank.empty();
    }
  }

  Future<QuizBank> _persist(QuizBank bank) async {
    final file = File('${(await directory()).path}/$_bankFileName');
    await file.writeAsString(bank.encode());
    return _cachedBank = bank;
  }

  Future<QuizBank> save(QuizQuestion question) async {
    final bank = await load();
    final exists = bank.questions.any((q) => q.id == question.id);
    return _persist(
      exists ? bank.replacing(question) : bank.adding(question),
    );
  }

  Future<QuizBank> deleteQuestion(String id) async {
    final bank = await load();
    for (final question in bank.questions) {
      if (question.id != id) continue;
      for (final fileName in question.mediaFiles) {
        await deleteFile(fileName);
      }
    }
    return _persist(bank.removing(id));
  }

  Future<QuizBank> markAsked(Iterable<String> ids) async =>
      _persist((await load()).markAsked(ids));

  Future<QuizBank> setSeconds(int seconds) async =>
      _persist((await load()).withSeconds(seconds));

  Future<QuizBank> setRoundSize(int count) async =>
      _persist((await load()).withRoundSize(count));

  Future<String> importImage(File source, String questionId) async {
    final fileName = imageFileNameFor(questionId);
    await source.copy('${(await directory()).path}/$fileName');
    return fileName;
  }

  String imageFileNameFor(String questionId) => '${questionId}_image.jpg';

  Future<String> audioPathFor(String questionId) async =>
      '${(await directory()).path}/${audioFileNameFor(questionId)}';

  String audioFileNameFor(String questionId) => '${questionId}_audio.m4a';

  Future<void> deleteFile(String fileName) async {
    final file = File(await resolve(fileName));
    if (await file.exists()) await file.delete();
  }
}
