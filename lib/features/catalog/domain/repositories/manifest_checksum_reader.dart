/// Contrato de persistência do último checksum SHA-256 do manifest (UC-12 poll).
abstract interface class ManifestChecksumReader {
  Future<String?> getLastKnownChecksum();

  Future<void> saveChecksum(String checksum);
}
