import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../domain/question.dart';
import '../domain/bank.dart';
import '../domain/seed_questions.dart';

/// 題庫與媒體檔的持久化,全部放在 app 沙盒的 Documents 底下。
///
///   Documents/quiz/bank.json            所有題目 + 每輪題數 + 每題秒數
///   Documents/quiz/q1757_image.jpg      某題的圖片
///   Documents/quiz/q1757_audio.m4a      某題的錄音
///
/// 媒體檔平放在同一層,靠檔名前面的題目 id 區隔;檔名可以由題目 id
/// 直接算出來,所以 JSON 裡存的檔名跟實際檔案永遠對得起來。
///
/// 預設題目([kSeedQuestions])的圖片與錄音打包在 assets 裡,第一次讀
/// 題庫時複製進同一個資料夾 —— 進了沙盒之後,它們跟家人自己加的題目
/// 就沒有分別了,一樣可以換圖、重錄、刪掉。
class QuizStore {
  static const _folder = 'quiz';
  static const _bankFileName = 'bank.json';
  static const _seedAssetFolder = 'assets/quiz';

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
    return _cachedBank = await _installSeeds(await _read());
  }

  /// 把還沒有的預設題目補進題庫,連同它們的圖片與錄音。
  ///
  /// 補過就記在 [QuizBank.seededVersion] 裡,所以只會發生一次 ——
  /// 家人刪掉的預設題目不會下次開啟又冒出來。
  ///
  /// 順序是先複製媒體檔再寫題庫:中途失敗的話題庫沒動,下次啟動整個
  /// 重來一次,不會留下一題指著不存在的圖片。
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
      // 預設題目補不進去不該讓快問快答開不起來 —— 家人自己加的題目
      // 還在,照樣可以出題。下次啟動會再試一次。
      return bank;
    }
  }

  /// 把打包在 app 裡的一個媒體檔複製進沙盒,檔名不變。
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
      // 檔案毀損或格式版本不認得就當作空題庫,不要讓 app 開不起來。
      // 這份空題庫接著會被補上預設題目並寫回檔案 —— 原本的內容已經
      // 讀不出來了,留著也沒有人救得回來。
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
