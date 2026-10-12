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

  factory ContributionTarget.fromJson(Map<String, dynamic> json) =>
      ContributionTarget(
        source: ContributionSource.values.firstWhere(
          (s) => s.wireName == json['source'],
          orElse: () => ContributionSource.coldigom,
        ),
        praiseId: json['praiseId'] as String?,
        materialId: json['materialId'] as String?,
      );

  ContributionTarget copyWith({String? praiseId, String? materialId}) =>
      ContributionTarget(
        source: source,
        praiseId: praiseId ?? this.praiseId,
        materialId: materialId ?? this.materialId,
      );
}
