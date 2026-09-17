import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/device_snapshot.dart';

/// «Isto será enviado» (spec §6.3): mostra o que o bug carrega antes de
/// enviar — nada aqui identifica a pessoa, só o aparelho/app (spec §privacidade).
class DeviceConsentCard extends StatelessWidget {
  const DeviceConsentCard({
    required this.snapshot,
    required this.sameDevice,
    required this.otherDeviceNote,
    required this.onSameDevice,
    required this.onOtherDeviceNote,
    super.key,
  });

  /// `null` enquanto a coleta (assíncrona) ainda não terminou.
  final DeviceSnapshot? snapshot;
  final bool? sameDevice;
  final String otherDeviceNote;
  final ValueChanged<bool?> onSameDevice;
  final ValueChanged<String> onOtherDeviceNote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lines = snapshot?.humanLines() ?? const <(DeviceLine, String)>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.contributeDeviceTitle, style: AppTypography.headline),
            const SizedBox(height: 8),
            if (snapshot == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          _lineLabel(l10n, line.$1),
                          style: AppTypography.label,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _lineValue(l10n, line.$1, line.$2),
                          style: AppTypography.body,
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 12),
            Text(l10n.contributeSameDeviceQuestion, style: AppTypography.body),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(l10n.contributeSameDeviceYes),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(l10n.contributeSameDeviceNo),
                ),
              ],
              selected: sameDevice == null ? const {} : {sameDevice!},
              emptySelectionAllowed: true,
              onSelectionChanged: (selection) =>
                  onSameDevice(selection.isEmpty ? null : selection.first),
            ),
            if (sameDevice == false) ...[
              const SizedBox(height: 12),
              // `initialValue` (não `controller`): o estado mora no
              // `ContributeFormNotifier`; sem `TextEditingController` aqui,
              // o widget não perde o cursor a cada rebuild do `Consumer`.
              TextFormField(
                key: const Key('contribute-other-device'),
                initialValue: otherDeviceNote,
                decoration: InputDecoration(
                  labelText: l10n.contributeOtherDevice,
                  border: const OutlineInputBorder(),
                ),
                onChanged: onOtherDeviceNote,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rótulo de cada [DeviceLine] — `DeviceSnapshot` (domínio) não sabe de
/// l10n; só quem exibe mapeia o identificador para o texto no idioma certo.
String _lineLabel(AppLocalizations l10n, DeviceLine line) => switch (line) {
  DeviceLine.app => l10n.contributeDeviceLineApp,
  DeviceLine.platform => l10n.contributeDeviceLinePlatform,
  DeviceLine.device => l10n.contributeDeviceLineDevice,
  DeviceLine.system => l10n.contributeDeviceLineSystem,
  DeviceLine.browser => l10n.contributeDeviceLineBrowser,
  DeviceLine.screen => l10n.contributeDeviceLineScreen,
  DeviceLine.locale => l10n.contributeDeviceLineLocale,
  DeviceLine.online => l10n.contributeDeviceLineOnline,
  DeviceLine.pwa => l10n.contributeDeviceLinePwa,
};

/// Valor de cada linha — `online`/`pwa` chegam como `'true'`/`'false'`
/// (`DeviceSnapshot.humanLines`, de propósito: `'sim'/'não'` também é l10n).
/// `commonYes`/`commonNo` (não `contributeSameDeviceYes`/`No`): o texto do
/// `SegmentedButton` logo abaixo já usa exatamente "Sim"/"Não" — reaproveitar
/// a mesma chave faria o `find.text('Sim')` de um teste de widget bater em
/// dois lugares.
String _lineValue(AppLocalizations l10n, DeviceLine line, String raw) =>
    switch (line) {
      DeviceLine.online ||
      DeviceLine.pwa => raw == 'true' ? l10n.commonYes : l10n.commonNo,
      _ => raw,
    };
