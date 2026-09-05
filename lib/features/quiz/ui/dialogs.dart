import 'package:flutter/material.dart';

import '../domain/question.dart';

/// 刪除一題前的確認。
Future<bool> confirmDeleteQuestion(
  BuildContext context,
  QuizQuestion question,
) async {
  final name = question.isComplete
      ? '${question.optionA} / ${question.optionB}'
      : '這題';

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('刪除這一題?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      content: Text('「$name」的圖片和錄音都會一起刪掉,沒辦法復原。',
          style: const TextStyle(fontSize: 17)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消', style: TextStyle(fontSize: 18)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('刪除', style: TextStyle(fontSize: 18)),
        ),
      ],
    ),
  );
  return ok ?? false;
}
