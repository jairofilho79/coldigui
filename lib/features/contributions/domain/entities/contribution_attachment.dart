import 'dart:typed_data';

/// Arquivo escolhido pelo usuário para anexar à contribuição, ainda em
/// memória — o upload em si é responsabilidade do datasource (task seguinte).
class ContributionAttachment {
  const ContributionAttachment({
    required this.name,
    required this.size,
    required this.bytes,
  });

  final String name;
  final int size;
  final Uint8List bytes;

  String get extension =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
}
