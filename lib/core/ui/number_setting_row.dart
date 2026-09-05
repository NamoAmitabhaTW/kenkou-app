import 'package:flutter/material.dart';

/// 「標題 [__] 單位」的數字設定列。
///
/// 三個設定選單(快問快答的每輪題數與限時、健口操的動作次數)共用這一個
/// 控制項,輸入、夾範圍、回寫的行為才不會每個地方都不一樣。
class NumberSettingRow extends StatefulWidget {
  const NumberSettingRow({
    super.key,
    required this.icon,
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String unit;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  State<NumberSettingRow> createState() => _NumberSettingRowState();
}

class _NumberSettingRowState extends State<NumberSettingRow> {
  late final _controller = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // 輸入到一半的數字不能直接當設定值用(打「1」準備打「15」),
    // 所以離開輸入框或按下完成的時候才收。
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(NumberSettingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_focus.hasFocus) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text.trim());
    final value = (parsed ?? widget.value).clamp(widget.min, widget.max);

    // 亂打或超出範圍時把框裡的字改回真正生效的值,不要讓畫面說謊。
    _controller.text = '$value';
    if (value != widget.value) widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = widget.enabled ? null : scheme.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Icon(widget.icon, size: 30, color: tint),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.label,
              style: TextStyle(
                  fontSize: 21, fontWeight: FontWeight.w700, color: tint),
            ),
          ),
          SizedBox(
            width: 78,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _commit(),
              onTapOutside: (_) => _focus.unfocus(),
            ),
          ),
          const SizedBox(width: 8),
          Text(widget.unit,
              style: TextStyle(fontSize: 20, color: tint)),
        ],
      ),
    );
  }
}
