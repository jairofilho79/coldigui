Feature: Filtros por material e arranjo na Home
  Como músico ou regente
  Quero filtrar louvores por material e arranjo
  Para encontrar partituras, cifras ou gestos relevantes

  @UC-02 @alta
  Scenario: Filtrar apenas partituras
    Given o catálogo está carregado na Home
    And existe um louvor de partitura e um de gestos em gravura
    When eu expando os filtros
    And desmarco todos os materiais exceto Partitura
    And busco por um termo que encontre ambos
    Then só vejo resultados de partitura

  @UC-02 @alta
  Scenario: Cifra inclui níveis I e II
    Given o catálogo contém louvores em Cifra nível I e Cifra nível II
    When eu seleciono apenas o material Cifra
    Then vejo louvores de ambos os níveis

  @UC-02 @alta
  Scenario: Filtros sincronizados com URL
    Given selecionei Partitura e arranjo ColAdultos
    Then a URL contém materiais=Partitura
    And a URL contém arranjo=ColAdultos
