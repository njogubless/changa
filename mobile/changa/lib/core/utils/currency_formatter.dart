import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _full = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'KES ',
    decimalDigits: 0,
  );

  static final _compact = NumberFormat.compact(locale: 'en_KE');

  /// KES 1,500
  static String format(double amount) => _full.format(amount);

  /// KES 1.5K
  static String formatCompact(double amount) =>
      'KES ${_compact.format(amount)}';

  /// 1,500
  static String formatNumber(double amount) =>
      NumberFormat('#,###', 'en_KE').format(amount);

  /// 67.5%
  static String formatPercent(double value) =>
      '${value.toStringAsFixed(1)}%';
}
