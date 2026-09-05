import 'package:flutter/services.dart';

/// App 內的螢幕錄製(iOS ReplayKit)。
///
/// 錄的是系統合成後的畫面,所以原生的相機預覽層也會被錄進去 ——
/// 這是選它而不是在 Flutter 端截圖的原因。
class ScreenCapture {
  static const MethodChannel _channel = MethodChannel('screen_capture/method');

  /// 模擬器與部分受限情境下無法錄製。
  static Future<bool> isAvailable() async =>
      await _channel.invokeMethod<bool>('isAvailable') ?? false;

  /// 開始錄製並寫入 [path]。第一次呼叫時系統會跳出錄製權限詢問。
  ///
  /// [microphone] 為 true 時錄的是麥克風,題目語音會透過喇叭被一起收進去,
  /// 長輩的聲音和題目落在同一條音軌上 —— 就像用錄影機拍下整個現場。
  /// 為 false 則只錄 App 內部音訊,聽得到題目但聽不到人。
  static Future<void> start(String path, {bool microphone = true}) =>
      _channel.invokeMethod<void>('start', {
        'path': path,
        'microphone': microphone,
      });

  /// 結束錄製,回傳影片檔的實際路徑。
  static Future<String?> stop() => _channel.invokeMethod<String>('stop');

  /// 把無聲影片和另外錄的音軌合成一支 mp4,回傳輸出路徑。
  /// 成功後會刪掉兩份中間檔。
  static Future<String?> merge({
    required String video,
    required String audio,
    required String output,
  }) =>
      _channel.invokeMethod<String>('merge', {
        'video': video,
        'audio': audio,
        'output': output,
      });
}
