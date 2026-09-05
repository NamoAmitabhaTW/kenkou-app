import 'dart:ui';

import 'package:face_mesh/face_mesh.dart';

import '../../../core/voice/syllable.dart';

/// 使用者自己的左右邊 —— 也就是鏡子裡看到的左右,不是影像座標的左右。
enum FaceSide { left, right }

/// 從臉部座標算出來、嘴型樣板管不到的幾何量。
///
/// 門檻沒有拿很多真人量過,是起手值。開「顯示判定數值」可以看到實測讀數。
class FaceGeometry {
  /// 使用者左/右邊的嘴角(外唇輪廓第 0 與第 10 點)。
  static Offset? mouthCornerOf(FaceFrame frame, FaceSide side) {
    final outer = frame.outerLip;
    if (outer.length < 11) return null;
    final aIsLeft = outer[0].dx > outer[10].dx;
    return (side == FaceSide.left) == aIsLeft ? outer[0] : outer[10];
  }
}

/// 閉唇判定。放鬆閉嘴時的內唇開口不是 0(唇厚、假牙都會影響),
/// 所以拿校正時的基準值加一點餘裕,而不是寫死一個數。
///
/// パタカラ 的 パ 是閉唇音,發音前嘴唇一定先閉起來 —— 語音模型把 パ 聽成
/// タ/カ 的時候,靠這個把它救回來(見 [resolveSyllable])。
class LipsClosedDetector {
  static const _margin = 0.006;

  double _baseline = 0.008;

  void calibrate(List<FaceFrame> neutralFrames) {
    final withFace = neutralFrames.where((f) => f.hasFace).toList();
    if (withFace.isEmpty) return;
    _baseline = withFace.map((f) => f.mouthOpenRatio).reduce((a, b) => a + b) /
        withFace.length;
  }

  double get threshold => _baseline + _margin;

  bool isClosed(FaceFrame frame) =>
      frame.hasFace && frame.mouthOpenRatio < threshold;
}

/// パタカラ:模型聽到的音跟目標不一樣時,用嘴唇偵測救一次。
///
/// 四個音裡只有 パ 是閉唇音,發音前嘴唇一定先閉起來;模型常把「pa」聽成
/// 別的音。所以目標是 パ、模型聽成 タ/カ、而剛才嘴唇有閉起來,就當作 パ。
/// 其他情況照模型的結果 —— 不反過來把聽成 パ 的音改判成別的,那樣會讓
/// 亂念也過關。
Syllable? resolveSyllable({
  required Syllable heard,
  required Syllable target,
  required bool lipsClosed,
}) {
  if (heard == target) return heard;
  if (target == Syllable.pa && lipsClosed && heard != Syllable.ra) {
    return Syllable.pa;
  }
  return heard;
}
