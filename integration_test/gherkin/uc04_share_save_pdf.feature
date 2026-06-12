Feature: Compartilhar e baixar PDF
  Como usuário do PLPCG
  Quero compartilhar ou salvar um louvor em PDF
  Para enviar a outras pessoas ou guardar offline no dispositivo

  @UC-04 @alta
  Scenario: Compartilhar PDF a partir do leitor
    Given que o app está aberto
    And existe um PDF de teste em assets/fixtures/sample.pdf
    When navego para "/leitor?file=asset:fixtures/sample.pdf&titulo=Fixture"
    And toco no botão de compartilhar na barra superior
    Then devo ver confirmação de que o PDF está pronto para compartilhar

  @UC-04 @alta
  Scenario: Baixar PDF a partir do leitor
    Given que o app está aberto
    And existe um PDF de teste em assets/fixtures/sample.pdf
    When navego para "/leitor?file=asset:fixtures/sample.pdf&titulo=Fixture"
    And toco no botão de baixar na barra superior
    Then devo ver confirmação de que o PDF foi salvo
