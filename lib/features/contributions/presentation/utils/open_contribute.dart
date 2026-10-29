import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../domain/entities/contribution_kind.dart';
import '../../domain/entities/contribution_target.dart';

/// Abre o formulário com o alvo e a rota de origem (`from`), que vira
/// `app_route` no payload — é o que mais ajuda a reproduzir um bug.
///
/// `GoRouter.of(context).routerDelegate.currentConfiguration.uri` (não
/// `GoRouterState.of(context)`): esse `context` pode estar dentro de uma
/// rota modal (ex.: bottom sheet da Tarefa 5), onde não há `GoRouteState`
/// ancestral e `GoRouterState.of` lança.
void openContribute(BuildContext context, {ContributionTarget? target}) {
  final from = GoRouter.of(context).routerDelegate.currentConfiguration.uri
      .toString();
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
