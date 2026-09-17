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
    final lines = snapshot?.humanLines() ?? const <(String, String)>[];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.contributeDeviceTitle, style: AppTypography.headline),
            const SizedBox(height: 6),
            if (snapshot == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              // `Wrap` (não uma linha por rótulo): as ~7 linhas de
              // `humanLines()` cabem lado a lado — evita um cartão alto
              // demais para o formulário inteiro caber sem rolar.
              Wrap(
                spacing: 12,
                runSpacing: 2,
                children: [
                  for (final line in lines)
                    Text(
                      '${line.$1}: ${line.$2}',
                      style: AppTypography.body.copyWith(fontSize: 12),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Text(l10n.contributeSameDeviceQuestion, style: AppTypography.body),
            const SizedBox(height: 4),
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
