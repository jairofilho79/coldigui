import 'package:coldigui/features/catalog/domain/utils/catalog_tag_hierarchy.dart';
import 'package:coldigui/features/catalog/domain/utils/legacy_category_tags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String section(String name) => 'Coletânea · $name';
  final morte = section('Morte Ressurreição e Salvação');
  final santificacao = section('Santificação e Derramamento do Espírito Santo');

  test('as 11 seções de nome igual viram Coletânea · <nome>', () {
    const sameName = [
      'Clamor',
      'Consolo e Encorajamento',
      'Contra-Capa',
      'Corinhos',
      'Crianças e Adolescentes',
      'Dedicação',
      'Grupo de Louvor',
      'Invocação e Comunhão',
      'Louvor',
      'Salmos de Louvor',
      'Volta de Jesus e Eternidade',
    ];
    for (final name in sameName) {
      expect(legacyCategoryToTags([name]), {
        coletaneaRootTag,
        section(name),
      }, reason: name);
    }
  });

  test('o rótulo usa a raiz e o separador da hierarquia de tags', () {
    expect(coletaneaRootTag, 'Coletânea');
    expect(legacyCategoryToTags(['Clamor']), {
      coletaneaRootTag,
      '$coletaneaRootTag${catalogTagHierarchySeparator}Clamor',
    });
  });

  test('a raiz Coletânea acompanha cada subtag convertida', () {
    expect(legacyCategoryToTags(['Clamor']), {
      coletaneaRootTag,
      section('Clamor'),
    });
    expect(legacyCategoryToTags(['Clamor', 'Louvor']), {
      coletaneaRootTag,
      section('Clamor'),
      section('Louvor'),
    });
    // Valor descartado (coleção): sem raiz, sem subtag.
    expect(legacyCategoryToTags(['Avulsos']), isEmpty);
  });

  test('Morte: as duas grafias inteiras (pref gravada)', () {
    expect(legacyCategoryToTags(['Morte, Ressureição e Salvação']), {
      coletaneaRootTag,
      morte,
    });
    expect(legacyCategoryToTags(['Morte, Ressurreição e Salvação']), {
      coletaneaRootTag,
      morte,
    });
  });

  test('Morte: pedaços partidos pela vírgula do CSV da URL', () {
    expect(legacyCategoryToTags(['Morte', 'Ressureição e Salvação']), {
      coletaneaRootTag,
      morte,
    });
    expect(legacyCategoryToTags(['Morte', 'Ressurreição e Salvação']), {
      coletaneaRootTag,
      morte,
    });
    expect(legacyCategoryToTags(['Ressureição e Salvação']), {
      coletaneaRootTag,
      morte,
    });
    expect(legacyCategoryToTags(['Morte']), {coletaneaRootTag, morte});
  });

  test('Santificação: as duas grafias', () {
    expect(legacyCategoryToTags(['Santificação e Derramamento']), {
      coletaneaRootTag,
      santificacao,
    });
    expect(
      legacyCategoryToTags(['Santificação e Derramamento do Espírito Santo']),
      {coletaneaRootTag, santificacao},
    );
  });

  test('coleções e valores desconhecidos são descartados', () {
    expect(
      legacyCategoryToTags([
        'Avulso',
        'Avulsos',
        'Avulso Cias',
        'Avulsos das Senhoras',
        'Adoração',
        '',
        '   ',
      ]),
      isEmpty,
    );
  });

  test('apara espaços, junta repetidos e mantém só as seções', () {
    expect(legacyCategoryToTags([' Clamor ', 'Avulsos', 'Clamor', 'Louvor']), {
      coletaneaRootTag,
      section('Clamor'),
      section('Louvor'),
    });
  });

  test('sem valores → vazio', () {
    expect(legacyCategoryToTags(const []), isEmpty);
  });
}
