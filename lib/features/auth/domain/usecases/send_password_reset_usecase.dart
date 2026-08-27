import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class SendPasswordResetUseCase {
  const SendPasswordResetUseCase(this._authRepository);

  final AuthRepository _authRepository;

  Future<Result<void, Failure>> call(String email) {
    final normalized = email.trim();
    if (normalized.isEmpty || !normalized.contains('@')) {
      return Future.value(
        const Result<void, Failure>.failure(
          ValidationFailure('Enter your email address first.'),
        ),
      );
    }
    return _authRepository.sendPasswordResetEmail(normalized);
  }
}
