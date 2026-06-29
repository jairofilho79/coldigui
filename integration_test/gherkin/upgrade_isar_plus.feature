@UC-12 @UC-10
Feature: Upgrade para isar_plus
  Como usuário do PLPCG que atualizou o app
  Quero que o catálogo volte a funcionar após a migração de banco
  Para continuar pesquisando e gerenciando louvores offline

  Scenario: Usuário existente após atualização do app
    Given o app tinha PDFs offline e playlists salvas na versão anterior
    When o usuário abre o app após a atualização
    Then o catálogo carrega quando há rede
    And playlists e carousel aparecem vazios
    And PDFs offline exigem novo download para abrir sem rede
