import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 單張影格的偵測結果。

class FaceFrame {
  const FaceFrame({
    required this.hasFace,
    this.blendshapes = const {},
    this.yaw = 0,
    this.rollDegrees = 0,
    this.mouthOpenRatio = 0,
    this.mouthWidthRatio = 0,
    Float32List? contour,
    this.imageSize = const Size(480, 640),
  }) : _contour = contour;

  final bool hasFace;

  /// 嘴部相關的 blendshape,值域 0~1。原生端已經做過正規化,
  /// 不受使用者與鏡頭的距離影響。
  final Map<String, double> blendshapes;

  /// -1 ~ 1,0 表示正對鏡頭。絕對值大時嘴寬會被投影壓縮,判定要放寬或直接擋掉。
  final double yaw;
  final double rollDegrees;

  /// 以臉寬正規化的嘴唇幾何,可拿來跟 blendshape 交叉驗證。
  final double mouthOpenRatio;
  final double mouthWidthRatio;

  /// 嘴唇輪廓與臉寬錨點,交錯成 [x0,y0,x1,y1,...] 的正規化座標。
  ///
  /// Float32List 沒有 const 形式,所以內部收 nullable,對外一律補成空陣列 —
  /// 呼叫端不必為「還沒偵測到臉」寫另一條分支。
  final Float32List? _contour;

  Float32List get contour => _contour ?? _empty;

  static final Float32List _empty = Float32List(0);

  /// 產生 [contour] 的那張影格的像素尺寸。
  final Size imageSize;

  /// 外唇輪廓,依序連線即為封閉路徑。
  List<Offset> get outerLip => _slice(0, 20);

  /// 內唇輪廓。內外唇之間的距離就是嘴唇厚度,張口程度看的是內唇。
  List<Offset> get innerLip => _slice(20, 20);

  /// 左右臉緣兩點,用來算臉寬。
  List<Offset> get faceEdges => _slice(40, 2);

  /// 上臉頰(顴骨下方)各 5 個點,只跟著頭動,舌壓訓練拿來當剛性參考。
  /// A 在影像左半邊(x 較小)、B 在右半邊;預覽是鏡像的,哪邊是使用者的左臉要看投影後的 x。
  List<Offset> get upperCheekA => _slice(42, 5);
  List<Offset> get upperCheekB => _slice(47, 5);

  /// 下臉頰(嘴角旁到下顎)各 10 個點,舌頭頂臉頰時鼓起來的就是這一帶。
  List<Offset> get lowerCheekA => _slice(52, 10);
  List<Offset> get lowerCheekB => _slice(62, 10);

  /// 錨點:鼻尖、鼻樑、下巴、耳前 A/B、下顎線 A/B。順序與原生端一致。
  List<Offset> get anchors => _slice(72, 7);

  Offset? get noseTip => _anchor(0);
  Offset? get noseBridge => _anchor(1);
  Offset? get chin => _anchor(2);
  Offset? get earA => _anchor(3);
  Offset? get earB => _anchor(4);
  Offset? get jawA => _anchor(5);
  Offset? get jawB => _anchor(6);

  /// 臉部外輪廓在臉頰到下顎那一段各 4 個點。鼓頰時往外撐的是這條線。
  List<Offset> get ovalA => _slice(79, 4);
  List<Offset> get ovalB => _slice(83, 4);

  /// 舊版原生端只送 42 個點;有沒有臉頰與錨點資料看這個。
  bool get hasExtendedContour => contour.length >= 87 * 2;

  Offset? _anchor(int i) {
    final points = anchors;
    return points.length > i ? points[i] : null;
  }

  List<Offset> _slice(int start, int count) {
    if (contour.length < (start + count) * 2) return const [];
    return List.generate(
      count,
      (i) => Offset(contour[(start + i) * 2], contour[(start + i) * 2 + 1]),
      growable: false,
    );
  }

  /// 頭有沒有擺正到可以信任判定結果。
  bool get isPoseUsable => hasFace && yaw.abs() < 0.25 && rollDegrees.abs() < 15;

  double operator [](String key) => blendshapes[key] ?? 0;

  factory FaceFrame.fromMap(Map<Object?, Object?> map) {
    if (map['hasFace'] != true) return const FaceFrame(hasFace: false);

    final raw = (map['blendshapes'] as Map?) ?? const {};
    return FaceFrame(
      hasFace: true,
      blendshapes: {
        for (final entry in raw.entries)
          entry.key as String: (entry.value as num).toDouble(),
      },
      yaw: (map['yaw'] as num?)?.toDouble() ?? 0,
      rollDegrees: (map['rollDegrees'] as num?)?.toDouble() ?? 0,
      mouthOpenRatio: (map['mouthOpenRatio'] as num?)?.toDouble() ?? 0,
      mouthWidthRatio: (map['mouthWidthRatio'] as num?)?.toDouble() ?? 0,
      contour: map['contour'] as Float32List?,
      imageSize: Size(
        ((map['imageWidth'] as num?) ?? 480).toDouble(),
        ((map['imageHeight'] as num?) ?? 640).toDouble(),
      ),
    );
  }
}

class FaceMesh {
  static const MethodChannel _method = MethodChannel('face_mesh/method');
  static const EventChannel _events = EventChannel('face_mesh/events');

  /// 開啟前鏡頭。權限被拒或模型缺失時丟 [PlatformException]。
  ///
  /// [detect] 為 false 時只開預覽,不載入 MediaPipe —— 適合單純要顯示
  /// 使用者畫面、不需要臉部偵測的場景。
  static Future<void> start({bool detect = true}) =>
      _method.invokeMethod<void>('start', {'detect': detect});

  static Future<void> stop() => _method.invokeMethod<void>('stop');

  /// 偵測結果串流,約與相機同步(30fps)。
  ///
  /// 刻意不快取、也不套 asBroadcastStream:後者在最後一個訂閱者取消時就關閉,
  /// 之後再 listen 收不到任何東西 —— 離開健口操分頁再回來就會變成黑畫面。
  /// EventChannel 自己回傳的已經是可重複訂閱的 broadcast stream。
  static Stream<FaceFrame> get frames => _events
      .receiveBroadcastStream()
      .map((event) => FaceFrame.fromMap(event as Map<Object?, Object?>));
}

/// 把偵測到的正規化座標換算成 [FaceMeshPreview] 上的畫面座標。
///
/// 有兩個一定會踩到的陷阱,都封在這裡而不是丟給呼叫端:
///
/// 1. **鏡像**。預覽層是鏡像的(使用者要看到照鏡子的自己),但送進
///    MediaPipe 的影格刻意沒有鏡像,以免 blendshape 的左右語意被對調。
///    所以疊在預覽上的座標,x 必須翻轉。
///
/// 2. **aspect fill 裁切**。預覽用 resizeAspectFill,影像比例和 widget
///    比例不同時會被裁掉一部分。直接把 0~1 乘上 widget 尺寸會整個歪掉。
@immutable
class FaceMeshProjection {
  FaceMeshProjection({required this.imageSize, required this.viewSize})
      : _scale = math.max(
          viewSize.width / imageSize.width,
          viewSize.height / imageSize.height,
        );

  final Size imageSize;
  final Size viewSize;
  final double _scale;

  double get _scaledWidth => imageSize.width * _scale;
  double get _scaledHeight => imageSize.height * _scale;

  Offset project(Offset normalized) {
    return Offset(
      (1 - normalized.dx) * _scaledWidth - (_scaledWidth - viewSize.width) / 2,
      normalized.dy * _scaledHeight - (_scaledHeight - viewSize.height) / 2,
    );
  }

  /// 正規化的長度換算成畫面上的像素長度。
  ///
  /// x 和 y 的正規化基準不同(分別除以影像寬和高),所以長度換算
  /// 要指定是沿著哪個軸,不能共用一個係數。
  double scaleX(double normalized) => normalized * _scaledWidth;
  double scaleY(double normalized) => normalized * _scaledHeight;
}

/// 相機預覽。影格完全不經過 Dart — 這只是一個掛著
/// AVCaptureVideoPreviewLayer 的原生 view。
class FaceMeshPreview extends StatelessWidget {
  const FaceMeshPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return const UiKitView(
      viewType: 'face_mesh/preview',
      creationParamsCodec: StandardMessageCodec(),
    );
  }
}
