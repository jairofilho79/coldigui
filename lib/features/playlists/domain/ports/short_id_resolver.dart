/// Resolve `shortId → pdfId` pelo catálogo PLPCG (spec short-id-share D8).
///
/// Devolve o mapa **depois** de o manifest existir — quem implementa aguarda
/// o carregamento, para um deep link que chega antes do catálogo não ser
/// descartado como «nenhum id conhecido». Vazio se o catálogo não tem
/// `shortId` (versão antiga do Worker).
typedef ShortIdResolver = Future<Map<String, String>> Function();
