import 'package:coldigui/features/contributions/data/datasources/contribution_draft_local_datasource.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_draft.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_target.dart';
import 'package:coldigui/features/contributions/presentation/providers/contribute_form_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const argsGeneral = ContributeFormArgs();
  const argsTarget = ContributeFormArgs(
    target: ContributionTarget(
      source: ContributionSource.coldigom,
      praiseId: 'p1',
      materialId: 'm1',
    ),
    from: '/leitor',
  );

  group('SharedPreferencesContributionDraftLocalDatasource', () {
    late SharedPreferences prefs;
    late SharedPreferencesContributionDraftLocalDatasource ds;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      ds = SharedPreferencesContributionDraftLocalDatasource(prefs);
    });

    test('read sem nada salvo retorna null', () {
      expect(ds.read(argsGeneral), isNull);
      expect(ds.read(argsTarget), isNull);
    });

    test('write persiste e read restaura rascunho', () async {
      const draft = ContributionDraft(
        kind: ContributionKind.improvement,
        subkind: ContributionSubkind.feature,
        title: 'Tema escuro customizado',
        body: 'Poderia ter fundo sépia.',
        links: ['https://youtu.be/123'],
      );

      await ds.write(argsGeneral, draft);

      final read = ds.read(argsGeneral);
      expect(read, isNotNull);
      expect(read!.title, 'Tema escuro customizado');
      expect(read.body, 'Poderia ter fundo sépia.');
      expect(read.kind, ContributionKind.improvement);
      expect(read.subkind, ContributionSubkind.feature);
      expect(read.links, ['https://youtu.be/123']);
    });

    test('alvos diferentes gravam em chaves isoladas', () async {
      const draft1 = ContributionDraft(
        kind: ContributionKind.other,
        title: 'Geral',
      );
      const draft2 = ContributionDraft(
        kind: ContributionKind.wrongInfo,
        title: 'Específico',
      );

      await ds.write(argsGeneral, draft1);
      await ds.write(argsTarget, draft2);

      expect(ds.read(argsGeneral)?.title, 'Geral');
      expect(ds.read(argsTarget)?.title, 'Específico');
    });

    test('clear remove o rascunho daquele alvo', () async {
      const draft = ContributionDraft(
        kind: ContributionKind.other,
        title: 'Para apagar',
      );
      await ds.write(argsGeneral, draft);
      expect(ds.read(argsGeneral), isNotNull);

      await ds.clear(argsGeneral);
      expect(ds.read(argsGeneral), isNull);
    });
  });

  group('InMemoryContributionDraftLocalDatasource', () {
    test('read, write e clear funcionam em memória', () async {
      final mem = InMemoryContributionDraftLocalDatasource();
      expect(mem.read(argsGeneral), isNull);

      const draft = ContributionDraft(
        kind: ContributionKind.other,
        title: 'Memória',
      );
      await mem.write(argsGeneral, draft);
      expect(mem.read(argsGeneral)?.title, 'Memória');

      await mem.clear(argsGeneral);
      expect(mem.read(argsGeneral), isNull);
    });
  });
}
