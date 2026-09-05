import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 相機畫面上下緣的漸層壓暗。
///
/// 只壓上下、中間不動 —— 疊在上面的字要看得清楚,但整片壓暗會讓人臉
/// 變得灰灰的很難看,而人臉正是錄影裡唯一值得留下來的東西。
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

/// 「錄影中」的紅點徽章。
///
/// 明確告訴使用者正在錄影。這是在錄長輩的臉,不該悄悄進行 ——
/// 所以健口操和快問快答一定要長得一樣,不能其中一頁忘了放。
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

/// 相機、麥克風、語音模型都還在起來時的等待畫面。
class PreparingView extends StatelessWidget {
  const PreparingView({super.key, this.detail});

  /// 多說一句在等什麼,例如「正在載入語音辨識」。
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

/// 做對一次的回饋:大拇指 + 一句話,彈出來再淡掉。
///
/// 做得很大是刻意的。長輩在做動作時眼睛是盯著自己的臉的,回饋要大到
/// 用餘光就看得到,不然等於沒有。
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

/// 開始前記錄使用者放鬆時的臉。
class CalibrationOverlay extends StatelessWidget {
  const CalibrationOverlay({
    super.key,
    required this.collected,
    required this.needed,
    required this.hasFace,
  });

  final int collected;
  final int needed;
  final bool hasFace;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('先放鬆閉上嘴,正對鏡頭',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('記一下你放鬆時的樣子,等一下判定才準',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: needed == 0 ? 0 : collected / needed,
                    minHeight: 10,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(kAccentGreen),
                  ),
                ),
              ),
              if (!hasFace) ...[
                const SizedBox(height: 16),
                const Text('沒有偵測到臉',
                    style: TextStyle(color: Colors.redAccent, fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 相機開不起來。沒有相機就沒有嘴型可判,整套做不下去,只能請人回首頁。
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
