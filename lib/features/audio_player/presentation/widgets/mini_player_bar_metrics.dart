/// Altura do [MiniPlayerBar] (D5) — compartilhada entre o overlay em si
/// (`shell_scaffold.dart`) e quem precisa reservar espaço para não ficar
/// coberto por ele em fullscreen (leitor PDF e cifra; o FAB de sair sobe por
/// cima dele).
///
/// Constante isolada num arquivo próprio (em vez de em `mini_player_bar.dart`)
/// para não acoplar quem só quer o número ao widget inteiro.
const double kMiniPlayerBarHeight = 44;
