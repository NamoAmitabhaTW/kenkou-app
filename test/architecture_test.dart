import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 分層規則的自動檢查。
///
/// 這些規則寫在 README 裡很容易腐爛 —— 半夜趕 demo 時隨手加一行 import,
/// 沒有人會發現架構已經破了。所以把它變成測試:破了就紅燈。
void main() {
  final libDir = Directory('lib');

  /// 每個 .dart 檔解析出「它 import 了 lib 底下的哪些檔案」,
  /// 路徑一律正規化成相對 lib 的形式(例如 `core/ui/app_theme.dart`)。
  Map<String, List<String>> importGraph() {
    final graph = <String, List<String>>{};
    final importPattern = RegExp(r"^\s*(?:import|export)\s+'([^']+)'");

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final from = p.relative(entity.path, from: 'lib');
      final targets = <String>[];
      for (final line in entity.readAsLinesSync()) {
        final match = importPattern.firstMatch(line);
        if (match == null) continue;
        final spec = match.group(1)!;

        if (spec.startsWith('package:futuremode2026/')) {
          targets.add(spec.substring('package:futuremode2026/'.length));
        } else if (!spec.startsWith('dart:') && !spec.startsWith('package:')) {
          targets.add(p.normalize(p.join(p.dirname(from), spec)));
        }
      }
      graph[from] = targets;
    }
    return graph;
  }

  String? featureOf(String path) {
    final parts = p.split(path);
    return parts.length > 1 && parts.first == 'features' ? parts[1] : null;
  }

  String? layerOf(String path) {
    final parts = p.split(path);
    return parts.length > 2 && parts.first == 'features' ? parts[2] : null;
  }

  late Map<String, List<String>> graph;

  setUpAll(() {
    graph = importGraph();
    // 抓錯目錄的話下面每一條都會空過,所以先確認真的掃到東西了。
    expect(graph.length, greaterThan(30), reason: 'lib/ 底下應該掃得到檔案');
  });

  test('core 不認識任何 feature', () {
    final offenders = <String>[];
    graph.forEach((from, targets) {
      if (!from.startsWith('core/')) return;
      for (final target in targets) {
        if (target.startsWith('features/')) offenders.add('$from → $target');
      }
    });
    expect(offenders, isEmpty,
        reason: 'core 是共用基礎設施,反過來依賴 feature 會讓兩邊綁死');
  });

  test('feature 之間不互相 import', () {
    final offenders = <String>[];
    graph.forEach((from, targets) {
      final self = featureOf(from);
      if (self == null) return;
      for (final target in targets) {
        final other = featureOf(target);
        if (other != null && other != self) offenders.add('$from → $target');
      }
    });
    expect(offenders, isEmpty,
        reason: '要共用就往 core 放,不要讓功能之間長出依賴');
  });

  test('domain 不碰 Flutter widget、檔案系統,也不往 ui / data 看', () {
    final banned = RegExp(
        r"flutter/material\.dart|flutter/widgets\.dart|dart:io|path_provider");
    final offenders = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final from = p.relative(entity.path, from: 'lib');
      if (layerOf(from) != 'domain') continue;

      for (final line in entity.readAsLinesSync()) {
        if (line.trimLeft().startsWith('import') && banned.hasMatch(line)) {
          offenders.add('$from → ${line.trim()}');
        }
      }
      for (final target in graph[from] ?? const <String>[]) {
        final layer = layerOf(target);
        if (layer == 'ui' || layer == 'data' || target.startsWith('core/ui/')) {
          offenders.add('$from → $target');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'domain 是純 Dart 的判定規則,要能不開模擬器就測');
  });

  test('data 不往 ui 看', () {
    final offenders = <String>[];
    graph.forEach((from, targets) {
      if (layerOf(from) != 'data') return;
      for (final target in targets) {
        if (layerOf(target) == 'ui' || target.startsWith('core/ui/')) {
          offenders.add('$from → $target');
        }
      }
    });
    expect(offenders, isEmpty, reason: '持久化不該知道畫面長什麼樣');
  });

  test('每個 feature 都有 domain / data / ui 三層,沒有散落在外的檔案', () {
    for (final feature in ['kenkou', 'quiz', 'pacman']) {
      final dir = Directory('lib/features/$feature');
      final strays = dir
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .toList();
      expect(strays, isEmpty, reason: '$feature 底下的檔案要放進三層之一');

      for (final layer in ['domain', 'data', 'ui']) {
        expect(Directory('lib/features/$feature/$layer').existsSync(), isTrue,
            reason: '$feature 缺少 $layer');
      }
    }
  });
}
