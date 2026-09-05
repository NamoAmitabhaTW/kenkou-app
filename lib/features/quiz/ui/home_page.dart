import 'package:flutter/material.dart';

import '../../../core/media/recording_gallery_page.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/number_setting_row.dart';
import '../domain/question.dart';
import '../domain/bank.dart';
import 'play_page.dart';
import 'question_bank_page.dart';
import 'question_editor_page.dart';
import '../data/quiz_store.dart';

/// 齒輪選單裡的入口。這些都是家人在用的,不是長輩。
enum _FamilyAction { setup, bank, recordings }

class QuizHomePage extends StatefulWidget {
  const QuizHomePage({super.key});

  @override
  State<QuizHomePage> createState() => _QuizHomePageState();
}

class _QuizHomePageState extends State<QuizHomePage> {
  final _store = QuizStore();

  QuizBank? _bank;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final bank = await _store.load();
    if (mounted) setState(() => _bank = bank);
  }

  /// 新增一題。題目彼此獨立,所以一次就是一題。
  Future<void> _addQuestion() async {
    await Navigator.push<QuizQuestion>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditorPage(
          store: _store,
          question: QuizQuestion.create(),
          isNew: true,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _openBank() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => QuestionBankPage(store: _store)),
    );
    await _reload();
  }

  Future<void> _openRecordings() {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const RecordingGalleryPage()),
    );
  }

  /// 每次開始都重新抽題,所以按一次「開始」就是一輪新的組合。
  Future<void> _start() async {
    final bank = await _store.load();
    final round = bank.drawRound();
    if (round.isEmpty || !mounted) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPlayPage(
          store: _store,
          questions: round,
          secondsPerQuestion: bank.secondsPerQuestion,
        ),
      ),
    );

    // 出過的題目要記下來,下一輪抽題才輪得到別題。
    await _store.markAsked([for (final q in round) q.id]);
    await _reload();
  }

  Future<void> _setSeconds(int seconds) async {
    await _store.setSeconds(seconds);
    await _reload();
  }

  Future<void> _setRoundSize(int count) async {
    await _store.setRoundSize(count);
    await _reload();
  }

  /// 設定類的操作全部收在齒輪後面,首頁只留長輩要按的那一顆。
  Future<void> _openFamilyMenu() async {
    final bank = _bank;
    if (bank == null) return;

    final action = await showModalBottomSheet<_FamilyAction>(
      context: context,
      showDragHandle: true,
      // 數字輸入框會叫出鍵盤,沒有這個的話輸入框會被鍵盤蓋住。
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  '家人設定',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              _MenuTile(
                icon: Icons.mic_none,
                title: '設置題目',
                onTap: () => Navigator.pop(context, _FamilyAction.setup),
              ),
              _MenuTile(
                icon: Icons.folder_copy_outlined,
                title: '題庫',
                onTap: () => Navigator.pop(context, _FamilyAction.bank),
              ),
              NumberSettingRow(
                icon: Icons.casino_outlined,
                label: '每輪出題:',
                unit: '題',
                value: bank.questionsPerRound,
                min: kMinQuestionsPerRound,
                max: kMaxQuestionsPerRound,
                onChanged: _setRoundSize,
              ),
              NumberSettingRow(
                icon: Icons.timer_outlined,
                label: '每題答題限時:',
                unit: '秒',
                value: bank.secondsPerQuestion,
                min: kMinSecondsPerQuestion,
                max: kMaxSecondsPerQuestion,
                onChanged: _setSeconds,
              ),
              _MenuTile(
                icon: Icons.video_library_outlined,
                title: '影片記錄',
                onTap: () => Navigator.pop(context, _FamilyAction.recordings),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    if (action == null || !mounted) return;
    switch (action) {
      case _FamilyAction.setup:
        await _addQuestion();
      case _FamilyAction.bank:
        await _openBank();
      case _FamilyAction.recordings:
        await _openRecordings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bank = _bank;
    final ready = bank?.canPlay ?? false;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '快問快答',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900),
                  ),
                  // 準備好的時候標題底下什麼都不放,長輩看到的就是
                  // 一個大標題加一顆大按鈕。還沒有題目才補一句說明。
                  if (bank != null && !ready) ...[
                    const SizedBox(height: 12),
                    Text(
                      '還沒有題目,請家人先加入題目',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                  const SizedBox(height: 56),
                  if (bank == null)
                    const Center(child: CircularProgressIndicator())
                  else if (ready)
                    FilledButton(
                      onPressed: _start,
                      style: kBigButtonStyle,
                      child: const Text(
                        '開始',
                        style:
                            TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                    )
                  else
                    // 題庫空的時候,唯一該做的事就是加題目。
                    FilledButton.tonal(
                      onPressed: _addQuestion,
                      style: kBigButtonStyle,
                      child: const Text(
                        '建立題目',
                        style:
                            TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 8,
              child: IconButton(
                onPressed: bank == null ? null : _openFamilyMenu,
                iconSize: 34,
                tooltip: '家人設定',
                icon: const Icon(Icons.settings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 齒輪選單的一列。長輩偶爾也會誤點進來,所以一樣做大。
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      leading: Icon(icon, size: 30),
      title: Text(
        title,
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      ),
    );
  }
}
