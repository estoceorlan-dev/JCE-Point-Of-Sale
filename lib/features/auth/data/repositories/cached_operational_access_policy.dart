import '../../../../core/database/daos/metadata_dao.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/operational_access_policy.dart';

class CachedOperationalAccessPolicy implements OperationalAccessPolicy {
  const CachedOperationalAccessPolicy({
    required MetadataDao metadataDao,
    required AppClock clock,
    required Duration maxOfflineAge,
  }) : _metadataDao = metadataDao,
       _clock = clock,
       _maxOfflineAge = maxOfflineAge;

  final MetadataDao _metadataDao;
  final AppClock _clock;
  final Duration _maxOfflineAge;

  @override
  Future<Result<void, Failure>> verifyCanStart(AuthSession session) async {
    final raw = await _metadataDao.readValue(
      'auth.access_verified_at.${session.user.firebaseUid}',
    );
    final verifiedAt = raw == null ? null : DateTime.tryParse(raw)?.toUtc();
    if (verifiedAt == null ||
        _clock.nowUtc().isAfter(verifiedAt.add(_maxOfflineAge))) {
      return const Result.failure(
        AuthorizationFailure(
          'Online access verification is required before starting a new shift or sale.',
          code: 'online-verification-required',
        ),
      );
    }
    return const Result.success(null);
  }
}
