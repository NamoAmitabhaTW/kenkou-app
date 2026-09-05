import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/question.dart';
import '../domain/bank.dart';

/// 題庫與媒體檔的持久化,全部放在 app 沙盒的 Documents 底下。
///
///   Documents/quiz/bank.json            所有題目 + 每輪題數 + 每題秒數
///   Documents/quiz/q1757_image.jpg      某題的圖片
///   Documents/quiz/q1757_audio.m4a      某題的錄音
///
/// 媒體檔平放在同一層,靠檔名前面的題目 id 區隔;檔名可以由題目 id
/// 直接算出來,所以 JSON 裡存的檔名跟實際檔案永遠對得起來。
class QuizStore {
  static const _folder = 'quiz';
  static const _bankFileName = 'bank.json';

  Directory? _cachedDir;
  QuizBank? _cachedBank;

  /// 沙盒裡放題目資料的資料夾,不存在就建。
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

  /// 把存下來的檔名組回這次啟動時的實際路徑。
  Future<String> resolve(String fileName) async =>
      '${(await directory()).path}/$fileName';

  // MARK: 題庫

  Future<QuizBank> load() async {
    final cached = _cachedBank;
    if (cached != null) return cached;
    return _cachedBank = await _read();
  }

  Future<QuizBank> _read() async {
    final file = File('${(await directory()).path}/$_bankFileName');
    if (!await file.exists()) return QuizBank.empty();

    try {
      return QuizBank.decode(await file.readAsString());
    } catch (_) {
      // 檔案毀損或格式版本不認得就當作空題庫,不要讓 app 開不起來。
      return QuizBank.empty();
    }
  }

  Future<QuizBank> _persist(QuizBank bank) async {
    final file = File('${(await directory()).path}/$_bankFileName');
    await file.writeAsString(bank.encode());
    return _cachedBank = bank;
  }

  /// 存回某一題。編輯途中每一步都會呼叫,所以要能吃到未完成的狀態。
  Future<QuizBank> save(QuizQuestion question) async {
    final bank = await load();
    final exists = bank.questions.any((q) => q.id == question.id);
    return _persist(
      exists ? bank.replacing(question) : bank.adding(question),
    );
  }

  /// 刪掉一題,連同它引用到的圖片與錄音。
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

  /// 一輪答完之後記錄哪些題目出過,下一輪抽題才輪得到別題。
  Future<QuizBank> markAsked(Iterable<String> ids) async =>
      _persist((await load()).markAsked(ids));

  Future<QuizBank> setSeconds(int seconds) async =>
      _persist((await load()).withSeconds(seconds));

  Future<QuizBank> setRoundSize(int count) async =>
      _persist((await load()).withRoundSize(count));

  // MARK: 媒體檔

  /// 把使用者選的圖片複製進沙盒,回傳檔名。
  ///
  /// image_picker 給的是暫存路徑,系統隨時會清掉,一定要自己複製一份。
  ///
  /// 副檔名固定寫死 `.jpg`,不沿用來源檔名:iPhone 相簿裡的照片多半是
  /// HEIC,而 Flutter 的 Image widget 解不了 HEIC。呼叫端一律帶著尺寸與
  /// 品質參數去挑圖,image_picker 會重新編碼成 JPEG,所以這裡拿到的內容
  /// 一定是 JPEG —— 沿用來源副檔名反而會存出一個名為 .heic 的 JPEG。
  ///
  /// 檔名固定的另一個好處:同一題換圖不會產生新檔名,不會留下孤兒檔。
  Future<String> importImage(File source, String questionId) async {
    final fileName = imageFileNameFor(questionId);
    await source.copy('${(await directory()).path}/$fileName');
    return fileName;
  }

  String imageFileNameFor(String questionId) => '${questionId}_image.jpg';

  /// 錄音要寫進去的完整路徑。錄音套件直接寫在沙盒裡,不用再搬一次。
  Future<String> audioPathFor(String questionId) async =>
      '${(await directory()).path}/${audioFileNameFor(questionId)}';

  String audioFileNameFor(String questionId) => '${questionId}_audio.m4a';

  Future<void> deleteFile(String fileName) async {
    final file = File(await resolve(fileName));
    if (await file.exists()) await file.delete();
  }
}
