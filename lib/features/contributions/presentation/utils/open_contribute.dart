import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../domain/entities/contribution_kind.dart';
import '../../domain/entities/contribution_target.dart';

/// Abre o formulário com o alvo e a rota de origem (`from`), que vira
/// `app_route` no payload — é o que mais ajuda a reproduzir um bug.
void openContribute(BuildContext context, {ContributionTarget? target}) {
  final from = GoRouterState.of(context).uri.toString();
  final uri = Uri(
    path: RoutePaths.contribute,
    queryParameters: {
      if (target != null) 'source': target.source.wireName,
      if (target?.praiseId != null) 'praiseId': target!.praiseId,
      if (target?.materialId != null) 'materialId': target!.materialId,
      'from': from,
    },
  );
  context.push(uri.toString());
}

ContributionTarget? targetFromQuery(Map<String, String> q) {
  final source = ContributionSource.values
      .where((s) => s.wireName == q['source'])
      .firstOrNull;
  if (source == null) return null;
  return ContributionTarget(
    source: source,
    praiseId: q['praiseId'],
    materialId: q['materialId'],
  );
}
