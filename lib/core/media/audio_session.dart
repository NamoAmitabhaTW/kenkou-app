import 'package:audioplayers/audioplayers.dart';

import '../debug_log.dart';

abstract final class AudioSession {
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
