import 'package:flutter/material.dart';

import '../domain/maze.dart';
import 'maze_painter.dart';

/// 「念『怕』 ↑ 往上移動」的一列。
///
/// 首頁和遊戲畫面共用,兩邊的說明才不會不一樣 —— 以前這個 widget 住在
/// 首頁裡,遊戲畫面得反過來 import 首頁才拿得到它。
class VoiceHintRow extends StatelessWidget {
  const VoiceHintRow({
    super.key,
    required this.direction,
    required this.scheme,
    this.highlighted = false,
    this.compact = false,
  });

  final MoveDirection direction;
  final ColorScheme scheme;

  /// 剛剛聽到這個音,亮一下讓人知道有聽到。
  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 17.0 : 21.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: EdgeInsets.symmetric(vertical: compact ? 2 : 5),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 4 : 6),
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
