import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/auth_session.dart';

abstract interface class AuthRepository {
  Stream<Result<AuthSession?, Failure>> authStateChanges();
  Future<Result<AuthSession, Failure>> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<Result<AuthSession, Failure>> selectActiveBranch({
    required String organizationId,
    required String branchId,
  });
  Future<Result<AuthSession, Failure>> refreshAccess();
  Future<Result<void, Failure>> sendPasswordResetEmail(String email);
  Future<Result<void, Failure>> signOut();
  Future<void> dispose();
}
