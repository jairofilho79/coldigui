/// Áudio Coldigom baixado — índice + ficheiro válidos (spec §5.1).
class OfflineAudioEntry {
  const OfflineAudioEntry({
    required this.audioId,
    required this.r2Key,
    required this.storageKey,
    required this.fileSize,
    required this.downloadedAt,
  });

  final String audioId;
  final String r2Key;
  final String storageKey;
  final int fileSize;
  final DateTime downloadedAt;
}
