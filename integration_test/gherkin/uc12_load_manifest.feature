# language: pt
Feature: Carregar manifest de louvores
  Como músico da ICM
  Quero que o app carregue o catálogo ao iniciar
  Para pesquisar louvores mesmo após uso offline

  @UC-12 @alta
  Scenario: Carga inicial com internet disponível
    Given estou conectado à internet
    And o servidor PLPCG está acessível
    When eu abro o aplicativo
    Then o manifest de louvores deve ser carregado na memória local
    And devo poder pesquisar louvores na home

  @UC-12 @alta
  Scenario: Carga inicial offline com cache existente
    Given não estou conectado à internet
    And o manifest já foi carregado anteriormente neste dispositivo
    When eu abro o aplicativo
    Then o catálogo deve ser restaurado do armazenamento local
    And devo poder pesquisar louvores na home
