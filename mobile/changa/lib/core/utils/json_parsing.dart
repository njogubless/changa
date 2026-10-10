/// The API serialises every monetary value as an exact decimal string
/// ("1500.00") so no precision is lost in JSON (backend FIN-01). Ratios such
/// as `percentage_funded` are still plain JSON numbers. Casting either with
/// `as num` throws on the string form, which made every project, contribution
/// and budget response unparseable — so accept both.
double parseDecimal(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Expected a decimal number, got $value');
}

/// [parseDecimal] for optional fields: null stays [fallback].
double parseDecimalOr(Object? value, double fallback) =>
    value == null ? fallback : parseDecimal(value);
