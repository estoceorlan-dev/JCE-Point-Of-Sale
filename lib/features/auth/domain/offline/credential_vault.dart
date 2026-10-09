abstract interface class CredentialVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

abstract interface class PinHasher {
  Future<Map<String, String>> hash(String pin);
  Future<bool> verify(String pin, Map<String, String> encoded);
}
