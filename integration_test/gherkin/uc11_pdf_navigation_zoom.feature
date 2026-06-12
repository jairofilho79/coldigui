Feature: Navegação e zoom no leitor PDF
  Como usuário do PLPCG
  Quero navegar entre páginas e ajustar o encaixe do PDF
  Para ler partituras com conforto em diferentes modos de visualização

  Background:
    Given que o app está aberto
    And existe um PDF de teste em assets/fixtures/sample.pdf

  @UC-11 @alta
  Scenario: Alternar modo de encaixe page-fit e page-width
    When navego para "/leitor?file=asset:fixtures/sample.pdf&titulo=Fixture"
    And toco no botão de alternar encaixe da página na barra superior
    Then o modo de encaixe deve alternar entre altura e largura
    And a preferência deve ser salva para a próxima abertura do leitor

  @UC-11 @alta
  Scenario: Alternar navegação horizontal e vertical
    When navego para "/leitor?file=asset:fixtures/sample.pdf&titulo=Fixture"
    And toco no botão de alternar direção de navegação na barra superior
    Then o leitor deve alternar entre swipe horizontal e scroll vertical
    And a preferência deve ser salva para a próxima abertura do leitor

  @UC-11 @media
  Scenario: Navegar páginas com gesto de swipe ou scroll
    When navego para "/leitor?file=asset:fixtures/sample.pdf&titulo=Fixture"
    And deslizo ou rolo para ver outra página
    Then o indicador de página na barra superior deve atualizar

  @UC-11 @media
  Scenario: Pinch para zoom continua disponível
    When navego para "/leitor?file=asset:fixtures/sample.pdf&titulo=Fixture"
    And faço gesto de pinça na área do PDF
    Then devo conseguir ampliar e reduzir o documento manualmente
