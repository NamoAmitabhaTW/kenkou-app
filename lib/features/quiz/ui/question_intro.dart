import 'package:flutter/material.dart';

import '../../../core/ui/chinese_numerals.dart';

class QuestionIntro extends StatefulWidget {
  const QuestionIntro({super.key, required this.index, required this.onComplete});

  final int index;
  final VoidCallback onComplete;

  @override
  State<QuestionIntro> createState() => _QuestionIntroState();
}

class _QuestionIntroState extends State<QuestionIntro>
    with SingleTickerProviderStateMixin {
  static const _perChar = 400;
  static const _hold = 800;
  static const _total = _perChar * 3 + _hold;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete();
    });

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final characters = ['第', chineseNumeral(widget.index + 1), '題'];

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < characters.length; i++)
              _AnimatedCharacter(
                character: characters[i],
                animation: CurvedAnimation(
                  parent: _controller,
                  curve: Interval(
                    (i * _perChar) / _total,
                    (i * _perChar + 350) / _total,
                    curve: Curves.easeOutBack,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCharacter extends StatelessWidget {
  const _AnimatedCharacter({required this.character, required this.animation});

  final String character;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.5 + animation.value * 0.5, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          character,
          style: const TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
