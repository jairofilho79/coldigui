import 'package:go_router/go_router.dart';

/// Opções globais (estáticas) do go_router — chamada uma vez em `main()`.
///
/// `optionURLReflectsImperativeAPIs`: os leitores (`/leitor`, `/cifra`,
/// `/audio`, `/gestos`) entram por `context.push`/`context.replace`, e o
/// go_router só escreve essas rotas na URL do navegador com esta opção. Sem
/// ela, F5 (ou a aba descartada pelo tablet e recarregada ao voltar do
/// WhatsApp) volta para a Home e a partitura aberta some; o link copiado da
/// barra também não leva ao louvor (auditoria P2, medido em v2.plpcg.com).
///
/// A alternativa idiomática — `context.go` nos openers, já que `/leitor` é
/// filha de `/` — fica para quando `feat/barra-lista-ativa` entrar, porque
/// toca os mesmos arquivos do carousel. Só afeta a web.
void configureGoRouterGlobals() {
  GoRouter.optionURLReflectsImperativeAPIs = true;
}
