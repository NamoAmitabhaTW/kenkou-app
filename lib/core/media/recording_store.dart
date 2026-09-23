import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum RecordingKind { quiz, kenkou }

class SessionRecording {
  const SessionRecording({
    required this.fileName,
    required this.recordedAt,
    required this.correctCount,
    required this.total,
    this.kind = RecordingKind.quiz,
  });

  final String fileName;
  final DateTime recordedAt;

  final int correctCount;
  final int total;
  final RecordingKind kind;

  String get scoreLabel => switch (kind) {
        RecordingKind.quiz => '答對 $correctCount / $total 題',
        RecordingKind.kenkou => '健口操 做完 $correctCount / $total 個動作',
      };

  String get shareText => switch (kind) {
        RecordingKind.quiz => '今天的我也健康!快問快答$scoreLabel 🎉',
        RecordingKind.kenkou => '今天的我也健康!$scoreLabel 🎉',
      };

  String get dateLabel {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${recordedAt.year}/${two(recordedAt.month)}/${two(recordedAt.day)} '
        '${two(recordedAt.hour)}:${two(recordedAt.minute)}';
  }

  Map<String, Object?> toJson() => {
        'fileName': fileName,
        'recordedAt': recordedAt.toIso8601String(),
        'correctCount': correctCount,
        'total': total,
        'kind': kind.name,
      };

  factory SessionRecording.fromJson(Map<String, Object?> json) => SessionRecording(
        fileName: json['fileName'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        kind: RecordingKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => RecordingKind.quiz,
        ),
      );
}

class RecordingStore {
  static const _folder = 'recordings';
  static const _indexFile = 'index.json';

  Directory? _cachedDir;

  Future<Directory> directory() async {
    final cached = _cachedDir;
    if (cached != null) return cached;

    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory('${documents.path}/$_folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _cachedDir = dir;
  }

  Future<String> resolve(String fileName) async =>
      '${(await directory()).path}/$fileName';

  Future<String> newRecordingPath({RecordingKind kind = RecordingKind.quiz}) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '${(await directory()).path}/${kind.name}_$stamp.mp4';
  }

  Future<List<SessionRecording>> load() async {
    final file = File('${(await directory()).path}/$_indexFile');
    if (!await file.exists()) return [];

    try {
      final raw = jsonDecode(await file.readAsString()) as List;
      final recordings = raw
          .map((e) => SessionRecording.fromJson(e as Map<String, Object?>))
          .toList();

      final existing = <SessionRecording>[];
      for (final recording in recordings) {
        if (await File(await resolve(recording.fileName)).exists()) {
          existing.add(recording);
        }
      }
      existing.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return existing;
    } catch (_) {
      return [];
    }
  }

  Future<void> add(SessionRecording recording) async {
    final all = await load()
      ..insert(0, recording);
    await _writeIndex(all);
  }

  Future<void> delete(SessionRecording recording) async {
    final file = File(await resolve(recording.fileName));
    if (await file.exists()) await file.delete();

    final all = await load()
      ..removeWhere((r) => r.fileName == recording.fileName);
    await _writeIndex(all);
  }

  Future<void> _writeIndex(List<SessionRecording> recordings) async {
    final file = File('${(await directory()).path}/$_indexFile');
    await file.writeAsString(
      jsonEncode(recordings.map((r) => r.toJson()).toList()),
    );
  }
}
