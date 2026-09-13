import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../carousel/presentation/providers/carousel_items_provider.dart';
import '../../domain/entities/carousel_reader_position.dart';

/// Posição do material aberto no leitor dentro das entradas legíveis da lista
/// ativa (B.5).
///
/// Deriva de [carouselItemsProvider] — a view da lista ativa — em vez de um
/// repositório próprio: o leitor não tem estado de seleção nenhum.
///
/// Qual ocorrência é a corrente, com o mesmo louvor repetido na lista:
/// 1. a **focada**, quando ela é deste [currentMaterialId] — foi por ela que o
///    usuário chegou aqui (chip, seta, teclado);
/// 2. senão a **primeira** ocorrência do id (deep link, "seguir o áudio");
/// 3. senão — id que não está na lista, como uma cifra aberta de fora — a
///    ocorrência focada, para as setas continuarem levando a algum lugar.
final readerCarouselPositionProvider =
    Provider.family<CarouselReaderPosition?, String>((ref, currentMaterialId) {
      // Só o que se lê: uma entrada de áudio nunca é «anterior/próximo» do
      // leitor (spec 2026-09-12, §4). Como `index` é global, a posição aqui
      // é resolvida por **chave**, não por `item.index`.
      final items = ref.watch(readableCarouselItemsProvider);
      if (items.isEmpty) return null;

      final focused = ref.watch(focusedCarouselItemProvider);

      int index;
      if (focused != null && focused.materialId == currentMaterialId) {
        index = items.indexWhere((item) => item.key == focused.key);
      } else {
        index = items.indexWhere(
          (item) => item.materialId == currentMaterialId,
        );
        if (index < 0 && focused != null) {
          index = items.indexWhere((item) => item.key == focused.key);
        }
      }
      if (index < 0) index = 0;
      index = index.clamp(0, items.length - 1);

      final previous = index > 0 ? items[index - 1] : null;
      final next = index < items.length - 1 ? items[index + 1] : null;

      return CarouselReaderPosition(
        currentIndex: index + 1,
        total: items.length,
        currentKey: items[index].key,
        previousKey: previous?.key,
        nextKey: next?.key,
        previousMaterialId: previous?.materialId,
        nextMaterialId: next?.materialId,
      );
    });
