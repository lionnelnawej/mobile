import 'package:flutter/material.dart';
import 'package:loyambo/kernel/models/product.dart';
import 'package:loyambo/kernel/services/devise_book.dart';

class DeviseTotals extends StatefulWidget {
  final List<Product> items;
  final ValueChanged<String>? onModeChanged;
  final String initialMode;
  final bool compact;
  final bool showButtons;
  final double discountPercent;
  final double discountAmount;
  final String discountCurrency;

  const DeviseTotals({
    super.key,
    required this.items,
    this.onModeChanged,
    this.initialMode = 'native',
    this.compact = false,
    this.showButtons = false,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.discountCurrency = 'FC',
  });

  @override
  State<DeviseTotals> createState() => _DeviseTotalsState();
}

class _DeviseTotalsState extends State<DeviseTotals> {
  late String _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  Map<String, double> get _native {
    final raw = DeviseBook.instance.nativeTotals(
      widget.items.map((item) => (devise: item.currency, amount: item.price * item.quantity)),
    );
    if (widget.discountPercent > 0) {
      final factor = (1 - (widget.discountPercent / 100)).clamp(0.0, 1.0);
      return raw.map((code, value) => MapEntry(code, _roundMoney(value * factor)));
    }
    if (widget.discountAmount > 0) {
      final next = Map<String, double>.from(raw);
      final code = DeviseBook.instance.normalize(widget.discountCurrency);
      final left = _roundMoney((next[code] ?? 0) - widget.discountAmount);
      if (left <= 0.0001) {
        next.remove(code);
      } else {
        next[code] = left;
      }
      return next;
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final book = DeviseBook.instance;
    final native = _native;
    final codes = native.keys.toList();
    final mixed = codes.length > 1;
    if (!mixed && codes.isNotEmpty && _mode != codes.first && _mode != 'native') {
      _mode = codes.first;
    }

    final buttons = <String>[];
    if (widget.showButtons && mixed) {
      buttons.add('native');
      buttons.addAll(codes);
    }

    String labelOf(String mode) {
      if (mode == 'native') return 'Natif';
      return 'Tout en ${book.symbolOf(mode)}';
    }

    final amountStyle = TextStyle(
      fontSize: widget.compact ? 14 : 20,
      fontWeight: FontWeight.w900,
      color: Colors.orange.shade800,
    );
    Widget amount(String text) => Text(text, textAlign: TextAlign.end, style: amountStyle);

    final lines = <Widget>[];
    if (!mixed || _mode == 'native') {
      if (native.isEmpty) {
        lines.add(amount('0'));
      }
      native.forEach((code, value) {
        lines.add(amount('${book.formatMoney(value)} ${book.symbolOf(code)}'));
      });
    } else {
      var total = 0.0;
      native.forEach((code, value) {
        total += book.convert(value, code, _mode);
      });
      lines.add(amount('${book.formatMoney(total)} ${book.symbolOf(_mode)}'));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: lines,
          ),
        ),
        if (buttons.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _modeButton(buttons[i], labelOf(buttons[i]))),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _modeButton(String mode, String label) {
    final active = _mode == mode;
    return Material(
      color: active ? Colors.indigo : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => _mode = mode);
          widget.onModeChanged?.call(mode);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : Colors.indigo,
            ),
          ),
        ),
      ),
    );
  }
}

double _roundMoney(double value) => (value * 100).round() / 100;
