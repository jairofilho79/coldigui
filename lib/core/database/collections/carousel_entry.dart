import 'package:isar/isar.dart';

part 'carousel_entry.g.dart';

/// Entrada do carousel temporário (UC-05).
///
/// [sortOrder] define a posição na seleção; [pdfId] referencia o louvor.
@Collection()
class CarouselEntry {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String pdfId;

  @Index()
  late int sortOrder;
}
