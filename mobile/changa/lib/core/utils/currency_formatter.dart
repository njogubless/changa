import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _full = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'KES ',
    decimalDigits: 0,
  );

  static final _compact = NumberFormat.compact(locale: 'en_KE');

  
  static String format(double amount) => _full.format(amount);

  
  static String formatCompact(double amount) =>
      'KES ${_compact.format(amount)}';

  
  static String formatNumber(double amount) =>
      NumberFormat('#,###', 'en_KE').format(amount);

  
  static String formatPercent(double value) =>
      '${value.toStringAsFixed(1)}%';
}
