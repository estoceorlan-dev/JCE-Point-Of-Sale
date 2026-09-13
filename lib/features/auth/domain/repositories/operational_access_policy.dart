import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/auth_session.dart';

/// Controls only the start of new money-moving operations. Recovery and shift
/// closure deliberately do not use this gate.
abstract interface class OperationalAccessPolicy {
  Future<Result<void, Failure>> verifyCanStart(AuthSession session);
}
