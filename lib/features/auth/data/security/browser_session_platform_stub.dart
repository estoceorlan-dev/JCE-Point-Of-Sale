import '../../domain/offline/credential_vault.dart';

CredentialVault browserMetadataVault() =>
    throw UnsupportedError('Browser only.');
String? browserCsrf() => null;
void requireBrowserOrigin(Uri origin) =>
    throw UnsupportedError('Browser only.');
