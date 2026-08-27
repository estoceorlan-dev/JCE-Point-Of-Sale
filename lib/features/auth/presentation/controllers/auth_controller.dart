import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/usecases/refresh_access_usecase.dart';
import '../providers/auth_providers.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() {
    final repository = ref.watch(authRepositoryProvider);
    final initial = Completer<AuthSession?>();
    final subscription = repository.authStateChanges().listen((result) {
      result.fold(
        onSuccess: (session) {
          if (initial.isCompleted) {
            final previous = state.asData?.value;
            state = AsyncData(session);
            unawaited(_recordStreamedRoleChange(previous, session));
          } else {
            initial.complete(session);
          }
        },
        onFailure: (failure) {
          final stackTrace = failure.stackTrace ?? StackTrace.current;
          if (initial.isCompleted) {
            state = AsyncError(failure, stackTrace);
          } else {
            initial.completeError(failure, stackTrace);
          }
        },
      );
    });
    ref.onDispose(subscription.cancel);
    return initial.future;
  }

  Future<Result<AuthSession, Failure>> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(signInUseCaseProvider)
        .call(email: email, password: password);
    _applySessionResult(result);
    return result;
  }

  Future<Result<void, Failure>> signOut() async {
    final session = state.asData?.value;
    final result = await ref.read(signOutUseCaseProvider).call(session);
    result.fold(
      onSuccess: (_) => state = const AsyncData(null),
      onFailure: _applyFailure,
    );
    return result;
  }

  Future<Result<AuthSession, Failure>> selectActiveBranch({
    required String organizationId,
    required String branchId,
  }) async {
    final previous = state.asData?.value;
    if (previous == null) {
      const failure = AuthenticationFailure('Authentication is required.');
      _applyFailure(failure);
      return const Result<AuthSession, Failure>.failure(failure);
    }
    final result = await ref
        .read(selectActiveBranchUseCaseProvider)
        .call(
          previous: previous,
          organizationId: organizationId,
          branchId: branchId,
        );
    _applySessionResult(result);
    return result;
  }

  Future<Result<AuthSession, Failure>> refreshAccess() async {
    final previous = state.asData?.value;
    if (previous == null) {
      const failure = AuthenticationFailure('Authentication is required.');
      _applyFailure(failure);
      return const Result<AuthSession, Failure>.failure(failure);
    }
    final result = await ref.read(refreshAccessUseCaseProvider).call(previous);
    _applySessionResult(result);
    return result;
  }

  Future<Result<void, Failure>> sendPasswordResetEmail(String email) {
    return ref.read(sendPasswordResetUseCaseProvider).call(email);
  }

  void _applySessionResult(Result<AuthSession, Failure> result) {
    result.fold(
      onSuccess: (session) => state = AsyncData(session),
      onFailure: _applyFailure,
    );
  }

  void _applyFailure(Failure failure) {
    state = AsyncError(failure, failure.stackTrace ?? StackTrace.current);
  }

  Future<void> _recordStreamedRoleChange(
    AuthSession? previous,
    AuthSession? current,
  ) async {
    if (previous == null || current == null) {
      return;
    }
    if (RefreshAccessUseCase.roleSignature(previous) ==
        RefreshAccessUseCase.roleSignature(current)) {
      return;
    }
    try {
      await ref
          .read(authAuditRepositoryProvider)
          .recordRoleChange(previous: previous, current: current);
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error(
            'Unable to record streamed role change.',
            scope: 'auth',
            error: error,
            stackTrace: stackTrace,
          );
    }
  }
}
