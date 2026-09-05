import 'package:audioplayers/audioplayers.dart';

import '../debug_log.dart';

/// iOS 的 audio session 模式。只有「一邊錄音一邊播聲音」的頁面需要動它。
///
/// audioplayers 播放時預設會把 session 設成 `.playback`,那會關掉錄音輸入 ——
/// 麥克風就從播題目的那一刻起收不到東西,錄出來的影片後半整段無聲。
abstract final class AudioSession {
  /// 播放與錄音並存。`defaultToSpeaker` 讓題目仍從喇叭出來
  /// (走聽筒的話長輩聽不清楚)。
  static Future<void> allowPlaybackWhileRecording() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: const {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowBluetooth,
            },
          ),
        ),
      );
    } catch (e) {
      debugLog('AUDIO', '設定 playAndRecord 失敗:$e');
    }
  }

  /// 還原成單純播放。
  ///
  /// **一定要等錄音真的停了才呼叫** —— 提早切回 `.playback` 等於在 ReplayKit
  /// 和麥克風還在收音時把錄音路由拆掉,寫出來的檔案會是壞的或空的。
  static Future<void> restorePlaybackOnly() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {},
          ),
        ),
      );
    } catch (e) {
      debugLog('AUDIO', '還原 audio session 失敗:$e');
    }
  }
}
