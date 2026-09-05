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
                    '吃金幣設定',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: scheme.outline,
                    ),
                  ),
                ),
                _heading(context, '遊戲'),
                NumberSettingRow(
                  icon: Icons.timer_outlined,
                  label: '遊戲時限:',
                  unit: '秒',
                  value: s.gameSeconds,
                  min: kMinGameSeconds,
                  max: kMaxGameSeconds,
                  onChanged: (v) => _update(s.copyWith(gameSeconds: v)),
                ),
                _SliderRow(
                  icon: Icons.speed,
                  label: '移動速度',
                  valueLabel: '${s.cellsPerSecond.toStringAsFixed(1)} 格/秒',
                  value: s.cellsPerSecond,
                  min: kMinCellsPerSecond,
                  max: kMaxCellsPerSecond,
                  divisions: 10,
                  onChanged: (v) => _update(s.copyWith(cellsPerSecond: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.directions_walk),
                  title: const Text('念一次只走一格', style: TextStyle(fontSize: 17)),
                  subtitle: const Text('關掉的話念一次會一路走到撞牆',
                      style: TextStyle(fontSize: 13)),
                  value: s.stepMove,
                  onChanged: (v) => _update(s.copyWith(stepMove: v)),
                ),
                _heading(context, '判定'),
                _SliderRow(
                  icon: Icons.hearing,
                  label: '語音靈敏度',
                  valueLabel: '${s.voiceSensitivity}',
                  value: s.voiceSensitivity.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  onChanged: (v) =>
                      _update(s.copyWith(voiceSensitivity: v.round())),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.bug_report_outlined),
                  title: const Text('顯示辨識結果', style: TextStyle(fontSize: 17)),
                  subtitle: const Text('調參數時用,長輩玩的時候請關掉',
                      style: TextStyle(fontSize: 13)),
                  value: s.showDebug,
                  onChanged: (v) => _update(s.copyWith(showDebug: v)),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 16, 0),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontSize: 17)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
