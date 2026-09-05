import 'dart:async';

import 'package:face_mesh/face_mesh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/label_system.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/overlays.dart';
import 'lip_overlay.dart';
import '../domain/mouth_shape.dart';

/// 自由練習:自己挑一個嘴型反覆做,不照課程順序走。
///
/// 這頁同時是調參數的工具 —— 除錯面板把每一維特徵、目標框讀數、判定
/// 信心值都攤開來,`mouth_shape.dart` 裡那些門檻就是照著這裡的讀數調的。
/// 校正要收集幾張有臉的影格,跟正式流程同一個值。
const _calibrationFrames = 45;

class FreePracticePage extends StatefulWidget {
  const FreePracticePage({super.key});

  @override
  State<FreePracticePage> createState() => _FreePracticePageState();
}

class _FreePracticePageState extends State<FreePracticePage> {
  final _classifier = MouthShapeClassifier();
  final _tracker = HoldTracker();

  StreamSubscription<FaceFrame>? _subscription;
  FaceFrame _frame = const FaceFrame(hasFace: false);
  ShapeScore _detected = const ShapeScore(MouthShape.neutral, 0);
  double _targetScore = 0;

  MouthShape _target = MouthShape.a;
  LabelSystem _labelSystem = LabelSystem.zhuyin;
  String? _error;
  bool _showDebug = true;
  bool _showGuide = true;

  /// 校正期間累積的靜止影格。
  List<FaceFrame>? _calibrationBuffer;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    _subscription = FaceMesh.frames.listen(_onFrame);
    try {
      await FaceMesh.start();
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    }
  }

  void _onFrame(FaceFrame frame) {
    final buffer = _calibrationBuffer;
    if (buffer != null) {
      if (frame.hasFace) buffer.add(frame);
      if (buffer.length >= _calibrationFrames) {
        _classifier.calibrate(buffer);
        _calibrationBuffer = null;
        _tracker.resetSession();
      }
      if (mounted) setState(() => _frame = frame);
      return;
    }

    // 頭沒擺正時不判定,也不推進計時器。
    // 側臉會讓嘴寬被投影壓縮,這時候給分數只是在製造假資料。
    if (!frame.isPoseUsable) {
      _tracker.update(0);
      if (mounted) {
        setState(() {
          _frame = frame;
          _targetScore = 0;
        });
      }
      return;
    }

    final detected = _classifier.classify(frame);
    final targetScore = _classifier.scoreFor(frame, _target);
    _tracker.update(targetScore);

    if (mounted) {
      setState(() {
        _frame = frame;
        _detected = detected;
        _targetScore = targetScore;
      });
    }
  }

  void _startCalibration() {
    setState(() => _calibrationBuffer = []);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    FaceMesh.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const FaceMeshPreview(),
          const ScrimGradient(),
          if (_showGuide)
            Positioned.fill(
              child: CustomPaint(
                painter: LipOverlayPainter(
                  frame: _frame,
                  // 只有真的維持住才轉綠。剛好碰到門檻就閃綠色會讓人以為做對了。
                  matched: _tracker.state == HoldState.holding ||
                      _tracker.state == HoldState.completed,
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                _statusBar(),
                const Spacer(),
                if (_showDebug) _debugPanel(),
                _controls(),
              ],
            ),
          ),
          if (_error != null) CameraErrorOverlay(message: _error!),
          if (_calibrationBuffer != null)
            CalibrationOverlay(
              collected: _calibrationBuffer!.length,
              needed: _calibrationFrames,
              hasFace: _frame.hasFace,
            ),
        ],
      ),
    );
  }

  // MARK: 狀態列

  Widget _statusBar() {
    final (label, color) = switch (_frame) {
      FaceFrame(hasFace: false) => ('沒有偵測到臉', Colors.redAccent),
      FaceFrame(isPoseUsable: false) => ('請正對鏡頭', Colors.orangeAccent),
      _ => ('偵測中', kAccentGreen),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (!_classifier.isCalibrated)
            const Text('未校正', style: TextStyle(color: Colors.white54, fontSize: 12)),
          TextButton(
            onPressed: () => setState(() {
              final values = LabelSystem.values;
              _labelSystem = values[(_labelSystem.index + 1) % values.length];
            }),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(_labelSystem.displayName,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          IconButton(
            onPressed: () => setState(() => _showGuide = !_showGuide),
            icon: Icon(_showGuide ? Icons.gesture : Icons.gesture_outlined,
                size: 20, color: _showGuide ? Colors.white70 : Colors.white24),
          ),
          IconButton(
            onPressed: () => setState(() => _showDebug = !_showDebug),
            icon: Icon(_showDebug ? Icons.bug_report : Icons.bug_report_outlined,
                size: 20, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // MARK: 除錯面板 — 調參數時真正在看的東西

  Widget _debugPanel() {
    final features = _classifier.extractFeatures(_frame);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('判定:${_detected.shape.labelIn(_labelSystem)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(_detected.confidence.toStringAsFixed(2),
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(width: 12),
              Text('目標 ${_target.labelIn(_labelSystem)} ${_targetScore.toStringAsFixed(2)}',
                  style: const TextStyle(color: kAccentGreen, fontSize: 13)),
              const Spacer(),
              Text('yaw ${_frame.yaw.toStringAsFixed(2)}  ${_frame.rollDegrees.toStringAsFixed(0)}°',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '實測 width ${_frame.mouthWidthRatio.toStringAsFixed(3)}  '
            'open ${_frame.mouthOpenRatio.toStringAsFixed(3)}'
            '   ←  目標框 ${_target.guide.widthRatio} / ${_target.guide.openRatio}',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 6),
          for (final key in kFeatureKeys) _featureBar(key, features[key] ?? 0),
        ],
      ),
    );
  }

  Widget _featureBar(String key, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(key, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(kAccentGreen),
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(value.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  // MARK: 練習控制

  Widget _controls() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final shape in MouthShape.values)
                  if (shape != MouthShape.neutral) _targetChip(shape),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('${_tracker.completions}',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 4),
                child: Text('次', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      switch (_tracker.state) {
                        HoldState.idle => '做出「${_target.labelIn(_labelSystem)}」的嘴型',
                        HoldState.entering => '再用力一點',
                        HoldState.holding => '維持住…',
                        HoldState.completed => '很好,放鬆',
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _tracker.progress,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(
                          _tracker.state == HoldState.completed
                              ? kAccentGreen
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _startCalibration,
                  icon: const Icon(Icons.center_focus_weak, size: 18),
                  label: const Text('校正'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(_tracker.resetSession),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('歸零'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _targetChip(MouthShape shape) {
    final selected = shape == _target;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          _target = shape;
          _tracker.resetSession();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kBrandGreen : Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            shape.labelIn(_labelSystem),
            style: TextStyle(
              color: selected ? Colors.white : Colors.white60,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
