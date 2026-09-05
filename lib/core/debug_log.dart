import 'package:flutter/foundation.dart';

/// 開發時把某條流程的每一步印出來,release build 整段拿掉。
///
/// [kDebugMode] 是編譯期常數,所以 release 裡連字串都不會被組出來。
///
/// 錄影是一條跨越 ReplayKit、麥克風、AVAssetWriter 的鏈,任何一環斷掉的
/// 表徵都是「沒有影片」;語音辨識也一樣,聽錯跟沒聽到看起來一模一樣。
/// 沒有 log 就只能猜,所以這兩條路徑上的每一步都留了一行。
void debugLog(String tag, String message) {
  if (kDebugMode) debugPrint('[$tag] $message');
}
