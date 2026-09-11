/// Fora da web não existe `navigator.connection` — nunca há economia de dados.
///
/// Par nativo de `save_data_web.dart` (import condicional).
bool isSaveDataEnabled() => false;
