import '../entities/auth_session.dart';

/// Installation identity is durable and independent from the active account.
abstract interface class TerminalInstallationRepository {
  Future<String> deviceId();

  /// Registers this account as the installation's latest verified user. It
  /// must not transfer ownership of the installation or its register claim.
  Future<void> register(AuthSession session);
}
