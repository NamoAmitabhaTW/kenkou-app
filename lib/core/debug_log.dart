import 'package:flutter/foundation.dart';

void debugLog(String tag, String message) {
  if (kDebugMode) debugPrint('[$tag] $message');
}
