import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/louvor.dart';
import '../../domain/entities/louvor_group.dart';
import 'louvor_group_card.dart';

/// Item de louvor em lista — UC-01, UC-03, UC-04, UC-05.
///
/// Wrapper de [LouvorGroupCard] para um único [Louvor] (grupo de 1 material).
/// Preferir [LouvorGroupCard] diretamente nas listas agrupadas.
class LouvorCard extends ConsumerWidget {
  const LouvorCard({required this.louvor, super.key});

  final Louvor louvor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = LouvorGroup.fromLouvores([louvor]).first;
    return LouvorGroupCard(group: group);
  }
}
