import 'package:flutter/material.dart';

import '../../../core/ui/number_setting_row.dart';
import '../domain/settings.dart';
import '../data/settings_store.dart';

/// 右上角齒輪打開的設定。跟健口操一樣改動即時存檔,關掉就生效。
Future<void> showPacmanSettingsSheet(
  BuildContext context, {
  required PacmanSettings settings,
  required PacmanSettingsStore store,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // 秒數輸入框會叫出鍵盤,沒有這個的話輸入框會被鍵盤蓋住。
    isScrollControlled: true,
    builder: (context) => _SettingsSheet(settings: settings, store: store),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.settings, required this.store});

  final PacmanSettings settings;
  final PacmanSettingsStore store;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late PacmanSettings _settings = widget.settings;

  void _update(PacmanSettings next) {
    setState(() => _settings = next);
    // 每改一格就存 —— 關掉 sheet 的方式太多(往下滑、點外面),等關閉才存會漏。
    widget.store.save(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _settings;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(
                    '小遊戲設定',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: scheme.outline,
                    ),
                  ),
                ),
                NumberSettingRow(
                  icon: Icons.timer_outlined,
                  label: '遊戲時限:',
                  unit: '秒',
                  value: s.gameSeconds,
                  min: kMinGameSeconds,
                  max: kMaxGameSeconds,
                  onChanged: (v) => _update(s.copyWith(gameSeconds: v)),
                ),
                NumberSettingRow(
                  icon: Icons.directions_walk,
                  label: '念一次走:',
                  unit: '格',
                  value: s.cellsPerCommand,
                  min: kMinCellsPerCommand,
                  max: kMaxCellsPerCommand,
                  onChanged: (v) => _update(s.copyWith(cellsPerCommand: v)),
                ),
                NumberSettingRow(
                  icon: Icons.view_agenda_outlined,
                  label: '方塊多久掉一格:',
                  unit: '秒',
                  value: s.tetrisFallSeconds,
                  min: kMinTetrisFallSeconds,
                  max: kMaxTetrisFallSeconds,
                  onChanged: (v) => _update(s.copyWith(tetrisFallSeconds: v)),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
