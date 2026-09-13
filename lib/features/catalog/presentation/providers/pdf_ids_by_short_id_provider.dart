import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'louvores_manifest_provider.dart';

/// `shortId → pdfId` do manifest PLPCG, construído **uma vez por manifest**
/// (mesmo padrão de `louvoresByPdfIdProvider`, A4). Vazio enquanto o
/// manifest não carregou. Só o que tem `shortId` entra.
final pdfIdsByShortIdProvider = Provider<Map<String, String>>((ref) {
  final louvores = ref.watch(
    louvoresManifestProvider.select((manifest) => manifest.value?.louvores),
  );
  if (louvores == null) return const {};
  return Map<String, String>.unmodifiable({
    for (final louvor in louvores)
      if (louvor.shortId case final shortId?) shortId: louvor.pdfId,
  });
});
