import 'package:flutter/foundation.dart';

import '../../../../core/utils/pdf_id_codec.dart';
import '../../../catalog/domain/legacy_ids/legacy_id_store.dart';
import '../../domain/repositories/offline_pdf_repository.dart';

/// `OfflinePdfIndex` (spec 2026-09-23 §6.2).
///
/// Resolvido → [OfflinePdfRepository.remapPdfId]: o ficheiro fica onde está e
/// só a chave muda (se o id coldigom já estava indexado, a linha legada sai e
/// a que fica herda `isPersistent` dela).
/// Desconhecido → a linha sai; o ficheiro órfão é limpo pelo reconcile
/// (`listOrphans`). Reescreve sob o lock de manutenção: com outro dono (um
/// download, o reconcile) não mexe, e a próxima rodada tenta de novo.
class OfflineIndexLegacyIdStore implements LegacyIdStore {
  const OfflineIndexLegacyIdStore(
    this._repository, {
    required bool Function() tryLock,
    required void Function() unlock,
  }) : _tryLock = tryLock, // ignore: prefer_initializing_formals
       _unlock = unlock; // ignore: prefer_initializing_formals

  final OfflinePdfRepository _repository;
  final bool Function() _tryLock;
  final void Function() _unlock;

  @override
  String get name => 'offline';

  @override
  Future<Set<String>> collectLegacyIds() async => {
    for (final entry in await _repository.listAll())
      if (isLegacyPdfId(entry.pdfId)) entry.pdfId,
  };

  @override
  Future<int> rewrite(LegacyIdResolution resolution) async {
    if (!_tryLock()) {
      debugPrint('[legacy-ids] offline: manutenção ocupada, fica para depois');
      return 0;
    }
    try {
      var changed = 0;
      final unknown = <String>{};
      for (final entry in await _repository.listAll()) {
        final id = entry.pdfId;
        final mapped = resolution.resolved[id];
        if (mapped != null) {
          await _repository.remapPdfId(fromPdfId: id, toPdfId: mapped);
          changed++;
        } else if (resolution.isUnknown(id)) {
          unknown.add(id);
        }
      }
      if (unknown.isNotEmpty) {
        changed += await _repository.removeIndexEntries(unknown);
      }
      return changed;
    } finally {
      _unlock();
    }
  }
}
