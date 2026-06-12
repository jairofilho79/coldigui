# language: pt
Feature: Buscar louvor na Home
  Como músico ou regente da ICM
  Quero buscar louvores por número ou título na home
  Para encontrar partituras e cifras rapidamente

  @UC-01 @alta
  Scenario: Busca vazia não exibe resultados
    Given o manifest de louvores está carregado
    And estou na tela inicial do aplicativo
    When não digito nenhum texto na busca
    Then a lista de resultados deve estar vazia

  @UC-01 @alta
  Scenario: Busca por número exato
    Given o manifest de louvores está carregado
    And estou na tela inicial do aplicativo
    When digito o número "123" no campo de busca
    And aguardo a busca ser processada
    Then devo ver o louvor de número "123" nos resultados

  @UC-01 @alta
  Scenario: Busca por texto no título
    Given o manifest de louvores está carregado
    And estou na tela inicial do aplicativo
    When digito "sao joao" no campo de busca
    And aguardo a busca ser processada
    Then devo ver louvores cujo título corresponda à busca

  @UC-01 @alta
  Scenario: URL reflete texto de busca
    Given o manifest de louvores está carregado
    And estou na tela inicial do aplicativo
    When digito "aleluia" no campo de busca
    And aguardo a sincronização com o endereço
    Then o endereço da página deve conter o parâmetro de pesquisa
