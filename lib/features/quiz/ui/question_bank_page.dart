import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';
import 'dialogs.dart';
import '../domain/question.dart';
import '../domain/bank.dart';
import 'question_editor_page.dart';
import '../data/quiz_store.dart';

/// 題庫:所有題目的清單。點一題可以修改(含試聽與重錄),也可以刪除。
///
/// 這頁是給家人用的。長輩在首頁只會看到「開始」。
class QuestionBankPage extends StatefulWidget {
  const QuestionBankPage({super.key, required this.store});

  final QuizStore store;

  @override
  State<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends State<QuestionBankPage> {
  QuizBank? _bank;
  String? _directory;

  @override
  void initState() {
    super.initState();
    widget.store.load().then((bank) {
      if (mounted) setState(() => _bank = bank);
    });
    widget.store.directory().then((dir) {
      if (mounted) setState(() => _directory = dir.path);
    });
  }

  Future<void> _reload() async {
    final bank = await widget.store.load();
    if (mounted) setState(() => _bank = bank);
  }

  Future<void> _add() async {
    await Navigator.push<QuizQuestion>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditorPage(
          store: widget.store,
          question: QuizQuestion.create(),
          isNew: true,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _edit(QuizQuestion question) async {
    await Navigator.push<QuizQuestion>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditorPage(
          store: widget.store,
          question: question,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _delete(QuizQuestion question) async {
    if (!await confirmDeleteQuestion(context, question)) return;
    await widget.store.deleteQuestion(question.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final bank = _bank;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          bank == null ? '題庫' : '題庫 (${bank.questions.length} 題)',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: bank == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: bank.isEmpty
                      ? const _EmptyBank()
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: bank.questions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _QuestionCard(
                            question: bank.questions[i],
                            directory: _directory,
                            onTap: () => _edit(bank.questions[i]),
                            onDelete: () => _delete(bank.questions[i]),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: SafeArea(
                    top: false,
                    child: FilledButton.tonalIcon(
                      onPressed: _add,
                      style: kBigButtonStyle,
                      icon: const Icon(Icons.add, size: 26),
                      label: Text(
                        bank.isEmpty ? '建立第一題' : '新增題目',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 清單裡的一題。整張卡片可以點進去修改,右邊的垃圾桶直接刪。
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.directory,
    required this.onTap,
    required this.onDelete,
  });

  final QuizQuestion question;
  final String? directory;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fileName = question.imageFile;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 2, 12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: question.isComplete ? scheme.primary : scheme.error,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: fileName != null && directory != null
                    ? Image.file(File('$directory/$fileName'),
                        fit: BoxFit.cover)
                    // 文字題沒有圖,用題目的頭幾個字當縮圖。
                    : question.hasText
                        ? Padding(
                            padding: const EdgeInsets.all(4),
                            child: Center(
                              child: Text(
                                question.questionText.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          )
                        : Icon(Icons.help_outline,
                            size: 26, color: scheme.outline),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.isComplete
                          ? '${question.optionA} / ${question.optionB}'
                          : '未填完的題目',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: question.isComplete ? null : scheme.error,
                      ),
                    ),
                    if (question.isComplete) ...[
                      const SizedBox(height: 4),
                      Text('正解:${question.correctText}',
                          style:
                              TextStyle(fontSize: 15, color: scheme.primary)),
                    ],
                  ],
                ),
              ),
              // 鉛筆跟整張卡片是同一個動作 —— 卡片可以點不夠明顯,
              // 旁邊只有垃圾桶的話會讓人以為這裡只能刪。
              IconButton(
                onPressed: onTap,
                tooltip: '編輯',
                iconSize: 26,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: '刪除',
                iconSize: 26,
                color: scheme.error,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 一題都沒有的時候。
class _EmptyBank extends StatelessWidget {
  const _EmptyBank();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text(
              '題庫還是空的\n按下面的按鈕加入第一題',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
