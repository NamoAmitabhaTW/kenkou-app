import 'package:flutter/material.dart';

import 'app_theme.dart';

class ScrimGradient extends StatelessWidget {
  const ScrimGradient({
    super.key,
    this.topAlpha = 0.5,
    this.bottomAlpha = 0.6,
    this.stops = const [0.0, 0.35, 0.75],
  });

  final double topAlpha;
  final double bottomAlpha;
  final List<double> stops;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: topAlpha),
              Colors.transparent,
              Colors.black.withValues(alpha: bottomAlpha),
            ],
            stops: stops,
          ),
        ),
      ),
    );
  }
}

class RecordingBadge extends StatelessWidget {
  const RecordingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, size: 12, color: kAlertRed),
          SizedBox(width: 6),
          Text('錄影中', style: TextStyle(fontSize: 13, color: Colors.white70)),
        ],
      ),
    );
  }
}

class PreparingView extends StatelessWidget {
  const PreparingView({super.key, this.detail});

  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: kAccentGreen),
          const SizedBox(height: 20),
          const Text(
            '準備中…',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(detail!,
                style: const TextStyle(color: Colors.white54, fontSize: 15)),
          ],
        ],
      ),
    );
  }
}

class ThumbOverlay extends StatelessWidget {
  const ThumbOverlay({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(text),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          builder: (context, value, child) => Transform.scale(
            scale: 0.6 + 0.4 * value.clamp(0.0, 1.0),
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: kSuccessGreen.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.thumb_up, size: 88, color: Colors.white),
                const SizedBox(height: 10),
                Text(text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CalibrationOverlay extends StatelessWidget {
  const CalibrationOverlay({
    super.key,
    required this.headline,
    required this.progress,
    required this.hasFace,
  });

  final String headline;

  final double progress;

  final bool hasFace;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      height: 1.1)),
              const SizedBox(height: 32),
              SizedBox(
                width: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(kAccentGreen),
                  ),
                ),
              ),
              if (!hasFace) ...[
                const SizedBox(height: 20),
                const Text('沒有偵測到臉',
                    style: TextStyle(color: Colors.redAccent, fontSize: 18)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CameraErrorOverlay extends StatelessWidget {
  const CameraErrorOverlay({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white38, size: 56),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: kBigButtonStyle,
                child: const Text('回首頁', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
