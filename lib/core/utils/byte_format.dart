/// Formata bytes para exibição compacta (ex.: `6,2 GB`).
String formatCompactBytes(int bytes, {String decimalSeparator = ','}) {
  if (bytes < 1024) return '$bytes B';

  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = -1;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final formatted = value.toStringAsFixed(1).replaceAll('.', decimalSeparator);
  return '$formatted ${units[unitIndex]}';
}
