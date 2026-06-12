import '../../../../l10n/app_localizations.dart';

/// Dia da semana em caixa alta para o cabeçalho do folheto (UC-08).
///
/// Usa chaves `leafletWeekdayMonday`…`leafletWeekdaySunday` de [AppLocalizations].
String leafletWeekdayName(AppLocalizations l10n, DateTime date) {
  return switch (date.weekday) {
    DateTime.monday => l10n.leafletWeekdayMonday,
    DateTime.tuesday => l10n.leafletWeekdayTuesday,
    DateTime.wednesday => l10n.leafletWeekdayWednesday,
    DateTime.thursday => l10n.leafletWeekdayThursday,
    DateTime.friday => l10n.leafletWeekdayFriday,
    DateTime.saturday => l10n.leafletWeekdaySaturday,
    DateTime.sunday => l10n.leafletWeekdaySunday,
    _ => l10n.leafletWeekdayMonday,
  };
}

/// Formata linha de data do cabeçalho — ex.: `QUINTA-FEIRA 11/06/2026`.
///
/// Padrão fixo `dd/MM/yyyy` (paridade PWA); sem dependência de pacote `intl`.
String formatLeafletHeaderDate(AppLocalizations l10n, DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '${leafletWeekdayName(l10n, date)} $day/$month/${date.year}';
}
