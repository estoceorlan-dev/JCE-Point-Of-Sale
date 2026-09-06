import 'dart:convert';

import '../../../../core/database/daos/metadata_dao.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/organization_access.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/active_context_repository.dart';

class DriftActiveContextRepository implements ActiveContextRepository {
  const DriftActiveContextRepository({
    required MetadataDao metadataDao,
    required AppClock clock,
  }) : _metadataDao = metadataDao,
       _clock = clock;

  final MetadataDao _metadataDao;
  final AppClock _clock;

  @override
  Future<AuthSession> restore(AppUser user) async {
    final saved = await _metadataDao.readValue(_key(user.firebaseUid));
    if (saved != null) {
      try {
        final payload = jsonDecode(saved) as Map<String, dynamic>;
        final organizationId = payload['organizationId'] as String;
        final branchId = payload['branchId'] as String;
        final organization = user.organizationById(organizationId);
        if (organization != null &&
            organization.canSignIn &&
            organization.branchById(branchId) != null) {
          return AuthSession(
            user: user,
            activeOrganizationId: organizationId,
            activeBranchId: branchId,
          );
        }
      } catch (_) {
        await clear(user.firebaseUid);
      }
    }

    final organization = _firstUsableOrganization(user);
    if (organization == null) {
      throw StateError('No active branch assignment is available.');
    }
    final session = AuthSession(
      user: user,
      activeOrganizationId: organization.organization.id,
      activeBranchId: organization.branches
          .firstWhere((item) => item.branch.isActive)
          .branch
          .id,
    );
    await save(session);
    return session;
  }

  @override
  Future<void> save(AuthSession session) {
    return _metadataDao.writeValue(
      key: _key(session.user.firebaseUid),
      value: jsonEncode({
        'organizationId': session.activeOrganizationId,
        'branchId': session.activeBranchId,
      }),
      updatedAt: _clock.nowUtc(),
    );
  }

  @override
  Future<void> clear(String firebaseUid) {
    return _metadataDao.deleteValue(_key(firebaseUid)).then((_) {});
  }

  OrganizationAccess? _firstUsableOrganization(AppUser user) {
    for (final organization in user.organizations) {
      if (organization.canSignIn &&
          organization.branches.any((item) => item.branch.isActive)) {
        return organization;
      }
    }
    return null;
  }

  String _key(String firebaseUid) => 'auth.active_context.$firebaseUid';
}
