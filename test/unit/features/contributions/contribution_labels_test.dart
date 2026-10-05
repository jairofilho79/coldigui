import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/presentation/utils/contribution_labels.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  group('contributionAutoTitle', () {
    test('retorna vazio quando kind é other', () {
      expect(contributionAutoTitle(pt, ContributionKind.other, null), isEmpty);
    });

    test('retorna vazio quando subkind é null', () {
      expect(contributionAutoTitle(pt, ContributionKind.bug, null), isEmpty);
      expect(
        contributionAutoTitle(pt, ContributionKind.wrongInfo, null),
        isEmpty,
      );
      expect(
        contributionAutoTitle(pt, ContributionKind.content, null),
        isEmpty,
      );
      expect(
        contributionAutoTitle(pt, ContributionKind.improvement, null),
        isEmpty,
      );
    });

    test('combina kind e subkind para bug', () {
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.bug,
          ContributionSubkind.bugScreen,
        ),
        'Bug na app - Uma tela',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.bug,
          ContributionSubkind.bugReader,
        ),
        'Bug na app - Leitor',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.bug,
          ContributionSubkind.bugAudio,
        ),
        'Bug na app - Áudio',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.bug,
          ContributionSubkind.bugSearch,
        ),
        'Bug na app - Busca',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.bug,
          ContributionSubkind.bugOffline,
        ),
        'Bug na app - Offline',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.bug,
          ContributionSubkind.bugLogin,
        ),
        'Bug na app - Login',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.bug,
          ContributionSubkind.bugPlaylistLive,
        ),
        'Bug na app - Listas / ao vivo',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.bug,
          ContributionSubkind.bugOther,
        ),
        'Bug na app - Outro',
      );
    });

    test('combina kind e subkind para informação errada', () {
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.wrongInfo,
          ContributionSubkind.wrongMetadata,
        ),
        'Informação errada - Título, número, tom…',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.wrongInfo,
          ContributionSubkind.wrongLyrics,
        ),
        'Informação errada - Letra',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.wrongInfo,
          ContributionSubkind.wrongMaterial,
        ),
        'Informação errada - Material de outro louvor',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.wrongInfo,
          ContributionSubkind.wrongKind,
        ),
        'Informação errada - Tipo de material errado',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.wrongInfo,
          ContributionSubkind.duplicate,
        ),
        'Informação errada - Louvor duplicado',
      );
    });

    test('combina kind e subkind para conteúdo', () {
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.content,
          ContributionSubkind.addMaterial,
        ),
        'Conteúdo - Adicionar material',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.content,
          ContributionSubkind.addPraise,
        ),
        'Conteúdo - Adicionar louvor',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.content,
          ContributionSubkind.replaceMaterial,
        ),
        'Conteúdo - Substituir material',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.content,
          ContributionSubkind.remove,
        ),
        'Conteúdo - Remover',
      );
    });

    test('combina kind e subkind para melhoria', () {
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.improvement,
          ContributionSubkind.feature,
        ),
        'Melhoria - Funcionalidade nova',
      );
      expect(
        contributionAutoTitle(
          pt,
          ContributionKind.improvement,
          ContributionSubkind.behavior,
        ),
        'Melhoria - Mudar um comportamento',
      );
    });
  });
}
