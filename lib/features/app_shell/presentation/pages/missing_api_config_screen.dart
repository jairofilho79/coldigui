import 'package:flutter/material.dart';

/// Exibida no boot quando algum dos dart-defines de URL base falta
/// (`PLPCG_API_BASE_URL`, `COLDIGOM_API_BASE_URL`).
///
/// Sem router e sem l10n de propósito: é diagnóstico de build, mostrado
/// antes de o app existir.
class MissingApiConfigScreen extends StatelessWidget {
  const MissingApiConfigScreen({required this.missingDefines, super.key});

  /// Nomes dos defines ausentes, na ordem em que devem aparecer.
  final List<String> missingDefines;

  @override
  Widget build(BuildContext context) {
    final names = missingDefines.join(', ');
    return Scaffold(
      appBar: AppBar(title: const Text('PLPCG')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SelectableText(
          '$names não está definido neste build.\n\n'
          'Reinstale com:\n'
          'flutter run --dart-define-from-file=dart_defines/plpcg.json\n\n'
          'ou:\n'
          'flutter build ios --dart-define-from-file=dart_defines/plpcg.json',
        ),
      ),
    );
  }
}
