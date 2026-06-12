Feature: Ler PDF no leitor
  Como usuário do PLPCG
  Quero visualizar um louvor em PDF na tela de leitor
  Para ler partitura, cifra ou gestos em tela cheia

  @UC-11 @alta
  Scenario: Abrir PDF via rota leitor com fixture local
    Given que o app está aberto
    And existe um PDF de teste em assets/fixtures/sample.pdf
    When navego para "/leitor?file=asset:fixtures/sample.pdf&titulo=Fixture"
    Then devo ver o título "Fixture" na barra superior
    And o documento PDF deve ser renderizado na área de leitura

  @UC-11 @alta
  Scenario: Erro quando parâmetro file está ausente
    Given que o app está aberto
    When navego para "/leitor?titulo=SemArquivo"
    Then devo ver a mensagem de que o parâmetro file está ausente

  @UC-11 @alta
  Scenario: Erro para caminho PDF inválido
    Given que o app está aberto
    When navego para "/leitor?file=file:///etc/passwd"
    Then devo ver uma mensagem de erro sobre URL não permitida
    And posso tentar abrir novamente
