import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/logout_readiness.dart';

abstract interface class SessionExitRepository {
  Future<Result<LogoutReadiness, Failure>> prepareLogout({
    required BusinessContext context,
  });
}
