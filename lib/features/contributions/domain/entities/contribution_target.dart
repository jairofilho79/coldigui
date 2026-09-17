import 'contribution_kind.dart';

/// Louvor/material sobre o qual a contribuição fala. `null` = geral.
class ContributionTarget {
  const ContributionTarget({
    required this.source,
    this.praiseId,
    this.materialId,
  });

  final ContributionSource source;
  final String? praiseId;
  final String? materialId;

  Map<String, dynamic> toJson() => {
    'source': source.wireName,
    'praiseId': praiseId,
    'materialId': materialId,
  };

  ContributionTarget copyWith({String? materialId}) => ContributionTarget(
    source: source,
    praiseId: praiseId,
    materialId: materialId ?? this.materialId,
  );
}
