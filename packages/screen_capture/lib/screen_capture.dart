import 'package:flutter/services.dart';

class ScreenCapture {
  static const MethodChannel _channel = MethodChannel('screen_capture/method');

  static Future<bool> isAvailable() async =>
      await _channel.invokeMethod<bool>('isAvailable') ?? false;

  static Future<void> start(String path, {bool microphone = true}) =>
      _channel.invokeMethod<void>('start', {
        'path': path,
        'microphone': microphone,
      });

  static Future<String?> stop() => _channel.invokeMethod<String>('stop');

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
