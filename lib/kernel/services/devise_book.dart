import 'package:intl/intl.dart';

class DeviseRate {
  final String code;
  final String label;
  final String symbol;
  final bool enabled;
  final String role;
  final double rate;

  const DeviseRate({
    required this.code,
    required this.label,
    required this.symbol,
    required this.enabled,
    required this.role,
    required this.rate,
  });
}

class DeviseBook {
  static final DeviseBook instance = DeviseBook();

  String primary = 'FC';
  String reportDefault = 'native';
  List<DeviseRate> currencies = const [
    DeviseRate(code: 'FC', label: 'Franc congolais', symbol: 'FC', enabled: true, role: 'primary', rate: 1),
    DeviseRate(code: 'USD', label: 'Dollar', symbol: '\$', enabled: true, role: 'secondary', rate: 2200),
    DeviseRate(code: 'FCFA', label: 'Franc CFA', symbol: 'FCFA', enabled: false, role: 'off', rate: 1),
    DeviseRate(code: 'EUR', label: 'Euro', symbol: '€', enabled: false, role: 'extra', rate: 1),
  ];

  void load(dynamic json, {double? legacyUsdRate}) {
    if (json is! Map) {
      if (legacyUsdRate != null && legacyUsdRate > 0) {
        _setRate('USD', legacyUsdRate);
      }
      return;
    }
    primary = normalize(json['primary']?.toString());
    reportDefault = json['report_default']?.toString() ?? 'native';
    final list = json['currencies'];
    if (list is List && list.isNotEmpty) {
      currencies = list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final code = normalize(map['code']?.toString());
        return DeviseRate(
          code: code,
          label: map['label']?.toString() ?? code,
          symbol: map['symbol']?.toString() ?? symbolOf(code),
          enabled: map['enabled'] == true || map['enabled'] == 1,
          role: map['role']?.toString() ?? 'off',
          rate: double.tryParse(map['rate']?.toString() ?? '') ?? 1,
        );
      }).toList();
    }
  }

  void _setRate(String code, double rate) {
    currencies = currencies
        .map((item) => item.code == code
            ? DeviseRate(code: item.code, label: item.label, symbol: item.symbol, enabled: item.enabled, role: item.role, rate: rate)
            : item)
        .toList();
  }

  String normalize(String? code) {
    final value = (code ?? '').toUpperCase().trim();
    if (value.isEmpty || value == 'CDF' || value == 'F') return 'FC';
    if (value == '\$' || value == 'DOLLAR' || value == 'DOLLARS') return 'USD';
    if (value == '€' || value == 'EURO') return 'EUR';
    if (value == 'XAF' || value == 'CFA') return 'FCFA';
    return value;
  }

  double roundMoney(double value) => (value * 100).round() / 100;

  double parseMoney(dynamic raw) {
    if (raw is num) return roundMoney(raw.toDouble());
    var text = raw.toString().trim().replaceAll('\u00A0', '').replaceAll('\u202F', '').replaceAll(' ', '');
    if (text.contains(',') && text.contains('.')) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else {
      text = text.replaceAll(',', '.');
    }
    return roundMoney(double.tryParse(text) ?? 0);
  }

  String formatMoney(double value) {
    final rounded = roundMoney(value);
    return NumberFormat('#,##0.00', 'fr_FR')
        .format(rounded)
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ');
  }

  String symbolOf(String? code) {
    final normalized = normalize(code);
    for (final item in currencies) {
      if (item.code == normalized) return item.symbol;
    }
    switch (normalized) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'FCFA':
        return 'FCFA';
      default:
        return 'FC';
    }
  }

  double rateOf(String code) {
    final normalized = normalize(code);
    for (final item in currencies) {
      if (item.code == normalized && item.rate > 0) return item.rate;
    }
    return 1;
  }

  double convert(double amount, String from, String to) {
    final source = normalize(from);
    final target = normalize(to);
    if (source == target) return amount;
    final inPrimary = amount * rateOf(source);
    return inPrimary / rateOf(target);
  }

  Map<String, double> nativeTotals(Iterable<({String devise, double amount})> lines) {
    final totals = <String, double>{};
    for (final line in lines) {
      final code = normalize(line.devise);
      totals[code] = roundMoney((totals[code] ?? 0) + line.amount);
    }
    totals.removeWhere((key, value) => value == 0);
    return totals;
  }
}
