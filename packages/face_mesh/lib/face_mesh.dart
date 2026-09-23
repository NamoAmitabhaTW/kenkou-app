import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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

  final Map<String, double> blendshapes;

  final double yaw;
  final double rollDegrees;

  final double mouthOpenRatio;
  final double mouthWidthRatio;

  final Float32List? _contour;

  Float32List get contour => _contour ?? _empty;

  static final Float32List _empty = Float32List(0);

  final Size imageSize;

  List<Offset> get outerLip => _slice(0, 20);

  List<Offset> get innerLip => _slice(20, 20);

  List<Offset> get faceEdges => _slice(40, 2);

  List<Offset> get upperCheekA => _slice(42, 5);
  List<Offset> get upperCheekB => _slice(47, 5);

  List<Offset> get lowerCheekA => _slice(52, 10);
  List<Offset> get lowerCheekB => _slice(62, 10);

  List<Offset> get anchors => _slice(72, 7);

  Offset? get noseTip => _anchor(0);
  Offset? get noseBridge => _anchor(1);
  Offset? get chin => _anchor(2);
  Offset? get earA => _anchor(3);
  Offset? get earB => _anchor(4);
  Offset? get jawA => _anchor(5);
  Offset? get jawB => _anchor(6);

  List<Offset> get ovalA => _slice(79, 4);
  List<Offset> get ovalB => _slice(83, 4);

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

  static Future<void> start({bool detect = true}) =>
      _method.invokeMethod<void>('start', {'detect': detect});

  static Future<void> stop() => _method.invokeMethod<void>('stop');

  static Stream<FaceFrame> get frames => _events
      .receiveBroadcastStream()
      .map((event) => FaceFrame.fromMap(event as Map<Object?, Object?>));
}

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

  double scaleX(double normalized) => normalized * _scaledWidth;
  double scaleY(double normalized) => normalized * _scaledHeight;
}

class FaceMeshPreview extends StatelessWidget {
  const FaceMeshPreview({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const AndroidView(
        viewType: 'face_mesh/preview',
        creationParamsCodec: StandardMessageCodec(),
      );
    }
    return const UiKitView(
      viewType: 'face_mesh/preview',
      creationParamsCodec: StandardMessageCodec(),
    );
  }
}
