/// O que o player precisa para tocar do aparelho: onde estão os bytes.
///
/// Nativo: [storageKey] é um path absoluto (`Uri.file`); web: chave da Cache
/// API — o player lê os bytes pelo `AudioStoragePort` e cria um blob URL.
class LocalAudioSource {
  const LocalAudioSource({required this.audioId, required this.storageKey});

  final String audioId;
  final String storageKey;
}
