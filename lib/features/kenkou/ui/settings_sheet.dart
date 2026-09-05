import 'package:flutter/material.dart';

import '../../../core/label_system.dart';
import '../../../core/ui/number_setting_row.dart';
import '../domain/settings.dart';
import '../data/settings_store.dart';

/// 設定選單裡除了改數字之外還能去的地方。
enum KenkouMenuAction { recordings }

/// 右上角齒輪打開的設定。改動即時存檔,關掉就生效。
Future<KenkouMenuAction?> showKenkouSettingsSheet(
  BuildContext context, {
  required KenkouSettings settings,
  required KenkouSettingsStore store,
}) {
  return showModalBottomSheet<KenkouMenuAction>(
    context: context,
    showDragHandle: true,
    // 數字輸入框會叫出鍵盤,沒有這個的話輸入框會被鍵盤蓋住。
    isScrollControlled: true,
    builder: (context) => _SettingsSheet(settings: settings, store: store),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.settings, required this.store});

  final KenkouSettings settings;
  final KenkouSettingsStore store;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late KenkouSettings _settings = widget.settings;

  void _update(KenkouSettings next) {
    setState(() => _settings = next);
    // 每改一格就存,使用者關掉 sheet 的方式太多(往下滑、點外面),
    // 等關閉時才存很容易漏。
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
                    '健口操設定',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: scheme.outline,
                    ),
                  ),
                ),
                _heading(context, '次數與時間'),
                NumberSettingRow(
                  icon: Icons.repeat,
                  label: '每個嘴型動作:',
                  unit: '次',
                  value: s.faceReps,
                  min: kMinFaceReps,
                  max: kMaxFaceReps,
                  onChanged: (v) => _update(s.copyWith(faceReps: v)),
                ),
                _SliderRow(
                  icon: Icons.hourglass_bottom,
                  label: '嘴型要維持',
                  valueLabel: '${(s.holdMillis / 1000).toStringAsFixed(1)} 秒',
                  value: s.holdMillis / 1000,
                  min: 0.5,
                  max: 5,
                  divisions: 9,
                  onChanged: (v) =>
                      _update(s.copyWith(holdMillis: (v * 1000).round())),
                ),
                NumberSettingRow(
                  icon: Icons.record_voice_over_outlined,
                  label: 'パタカラ 每個音:',
                  unit: '次',
                  value: s.patakaReps,
                  min: kMinPatakaReps,
                  max: kMaxPatakaReps,
                  onChanged: (v) => _update(s.copyWith(patakaReps: v)),
                ),
                _heading(context, '判定'),
                _SliderRow(
                  icon: Icons.tune,
                  label: '嘴型判定嚴格度',
                  valueLabel: '${s.strictness}%',
                  value: s.strictness.toDouble(),
                  min: 60,
                  max: 95,
                  divisions: 7,
                  onChanged: (v) => _update(s.copyWith(strictness: v.round())),
                ),
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
                _heading(context, '顯示'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.translate),
                      const SizedBox(width: 16),
                      const Text('文字標示', style: TextStyle(fontSize: 17)),
                      const Spacer(),
                      SegmentedButton<LabelSystem>(
                        segments: [
                          for (final system in LabelSystem.values)
                            ButtonSegment(
                              value: system,
                              label: Text(system.displayName),
                            ),
                        ],
                        selected: {s.labelSystem},
                        showSelectedIcon: false,
                        onSelectionChanged: (set) =>
                            _update(s.copyWith(labelSystem: set.first)),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.bug_report_outlined),
                  title: const Text('顯示判定數值', style: TextStyle(fontSize: 17)),
                  subtitle: const Text('調參數時用,長輩練習時請關掉',
                      style: TextStyle(fontSize: 13)),
                  value: s.showDebug,
                  onChanged: (v) => _update(s.copyWith(showDebug: v)),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.video_library_outlined, size: 28),
                  title: const Text('影片記錄', style: TextStyle(fontSize: 19)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.pop(context, KenkouMenuAction.recordings),
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
            width: 52,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
