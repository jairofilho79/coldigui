# language: pt
Feature: PLPCG Flutter — Use Cases
  Como músico ou regente da ICM
  Quero pesquisar e ler louvores offline
  Para usar durante ensaios e cultos

  @UC-01 @alta
  Scenario: Buscar louvor por número na home
    Given o manifest de louvores está carregado
    When eu digito "123" na barra de busca
    Then devo ver o louvor número 123 nos resultados

  @UC-09 @alta
  Scenario: Configurar modo offline pela primeira vez
    Given estou conectado à internet
    When eu seleciono a categoria Partitura para download offline
    Then os PDFs da categoria devem ficar disponíveis sem conexão

  @UC-11 @alta
  Scenario: Ler PDF no leitor com zoom
    Given um PDF está disponível offline
    When eu abro o louvor no leitor
    Then devo conseguir navegar entre as páginas e ajustar o zoom
