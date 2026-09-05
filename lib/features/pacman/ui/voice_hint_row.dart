import 'package:flutter/material.dart';

import '../domain/maze.dart';
import 'maze_painter.dart';

/// 「念『怕』 ↑ 往上移動」的一列。
///
/// 首頁的操控說明用。遊戲畫面改用自己的對照表(字更大、兩欄對齊),
/// 那裡要的排版跟這裡不一樣,硬共用只會讓兩邊都難調。
class VoiceHintRow extends StatelessWidget {
  const VoiceHintRow({
    super.key,
    required this.direction,
    required this.scheme,
    this.highlighted = false,
  });

  final MoveDirection direction;
  final ColorScheme scheme;

  /// 剛剛聽到這個音,亮一下讓人知道有聽到。
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    const size = 21.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? kPacmanColor.withValues(alpha: 0.22) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        // 貼著內容就好:首頁那欄是 stretch,寬度照樣撐滿;遊戲畫面那欄是置中,
        // 亮起來的底色才不會變成一整條橫幅。
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('念', style: TextStyle(fontSize: size - 4, color: scheme.outline)),
          const SizedBox(width: 4),
          Text(
            '「${direction.word}」',
            style: TextStyle(
              fontSize: size + 3,
              fontWeight: FontWeight.w900,
              color: highlighted ? kPacmanColor : scheme.onSurface,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            direction.arrow,
            style: TextStyle(
              fontSize: size + 5,
              fontWeight: FontWeight.w900,
              color: highlighted ? kPacmanColor : scheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            direction.label,
            style: TextStyle(fontSize: size, color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}
