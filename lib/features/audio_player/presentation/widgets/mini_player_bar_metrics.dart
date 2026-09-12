/// Altura do [MiniPlayerBar] — compartilhada entre o overlay em si
/// (`shell_scaffold.dart`) e quem precisa reservar espaço para não ficar
/// coberto por ele em fullscreen (Important 3, onda 4: leitor PDF e cifra).
///
/// Constante isolada num arquivo próprio (em vez de em `mini_player_bar.dart`)
/// para não acoplar quem só quer o número ao widget inteiro.
const kMiniPlayerBarHeight = 44.0;
