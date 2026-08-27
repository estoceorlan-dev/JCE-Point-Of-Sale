import 'failure.dart';

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.cause, super.stackTrace});

  @override
  FailureType get type => FailureType.validation;
}

final class AuthenticationFailure extends Failure {
  const AuthenticationFailure(
    super.message, {
    this.code,
    super.cause,
    super.stackTrace,
  });

  final String? code;

  @override
  FailureType get type => FailureType.authentication;
}

final class AuthorizationFailure extends Failure {
  const AuthorizationFailure(
    super.message, {
    this.code,
    super.cause,
    super.stackTrace,
  });

  final String? code;

  @override
  FailureType get type => FailureType.authorization;
}

final class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.cause, super.stackTrace});

  @override
  FailureType get type => FailureType.database;
}

final class NetworkFailure extends Failure {
  const NetworkFailure(
    super.message, {
    this.code,
    super.cause,
    super.stackTrace,
  });

  final String? code;

  @override
  FailureType get type => FailureType.network;
}

final class SynchronizationFailure extends Failure {
  const SynchronizationFailure(super.message, {super.cause, super.stackTrace});

  @override
  FailureType get type => FailureType.synchronization;
}

final class ConflictFailure extends Failure {
  const ConflictFailure(super.message, {super.cause, super.stackTrace});

  @override
  FailureType get type => FailureType.conflict;
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause, super.stackTrace});

  @override
  FailureType get type => FailureType.unexpected;
}
