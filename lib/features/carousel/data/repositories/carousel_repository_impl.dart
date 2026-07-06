import '../../../../core/utils/pdf_id_codec.dart';
import '../../domain/entities/carousel_item.dart';
import '../../domain/repositories/carousel_repository.dart';
import '../datasources/carousel_local_datasource.dart';

/// Orquestra [CarouselLocalDatasource] (UC-05, Fase 4.1).
class CarouselRepositoryImpl implements CarouselRepository {
  const CarouselRepositoryImpl(this._local);

  final CarouselLocalDatasource _local;

  @override
  Future<List<CarouselItem>> getOrderedItems({
    required Map<String, CarouselItemMetadata> pdfIdToMetadata,
  }) async {
    final entries = await _local.findAllOrdered();
    return entries
        .map((e) {
          final meta = pdfIdToMetadata[e.pdfId];
          return CarouselItem(
            pdfId: e.pdfId,
            sortOrder: e.sortOrder,
            numero: meta?.numero ?? '',
            nome: meta?.nome ?? _fallbackNome(e.pdfId),
            categoria: meta?.categoria ?? '',
            classificacao: meta?.classificacao ?? '',
            source: meta?.source ?? louvorDataSourceFromPdfId(e.pdfId),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<String>> getOrderedPdfIds() async {
    final entries = await _local.findAllOrdered();
    return entries.map((e) => e.pdfId).toList(growable: false);
  }

  @override
  Future<void> add(String pdfId) => _local.add(pdfId);

  @override
  Future<void> remove(String pdfId) => _local.remove(pdfId);

  @override
  Future<bool> replacePdfId(String oldPdfId, String newPdfId) =>
      _local.replacePdfId(oldPdfId, newPdfId);

  @override
  Future<void> reorder(List<String> orderedPdfIds) =>
      _local.reorder(orderedPdfIds);

  @override
  Future<void> replaceAll(List<String> orderedPdfIds) =>
      _local.replaceAll(orderedPdfIds);

  @override
  Future<void> clear() => _local.clear();

  /// Fallback quando [pdfId] não está no manifest carregado.
  static String _fallbackNome(String pdfId) {
    if (pdfId.length <= 12) return pdfId;
    return '${pdfId.substring(0, 12)}…';
  }
}
