import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../../../shared/models/access_role.dart';
import '../../../../shared/models/app_user.dart' as model;
import '../../../../shared/models/branch.dart' as model;
import '../../../../shared/models/branch_access.dart';
import '../../../../shared/models/organization.dart' as model;
import '../../../../shared/models/organization_access.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/models/user_account_status.dart';

abstract interface class AccessLocalDataSource {
  Future<model.AppUser?> findByFirebaseUid(String firebaseUid);
  Future<void> replaceProfile(model.AppUser user);
  Future<DateTime?> lastVerifiedAt(String firebaseUid);
  Future<void> recordVerifiedAt(String firebaseUid, DateTime verifiedAt);
  Future<void> clearProfile(String firebaseUid);
}

class DriftAccessLocalDataSource implements AccessLocalDataSource {
  const DriftAccessLocalDataSource(this._database);

  final db.AppDatabase _database;

  String _verificationKey(String firebaseUid) =>
      'auth.access_verified_at.$firebaseUid';

  @override
  Future<model.AppUser?> findByFirebaseUid(String firebaseUid) async {
    if (await _database.metadataDao.readValue(
          'auth.access_revoked.$firebaseUid',
        ) ==
        'true') {
      return null;
    }
    final userRows =
        await (_database.select(_database.appUsers)..where(
              (row) =>
                  row.firebaseUid.equals(firebaseUid) & row.deletedAt.isNull(),
            ))
            .get();
    if (userRows.isEmpty) {
      return null;
    }

    final organizations = <OrganizationAccess>[];
    for (final userRow in userRows) {
      final organizationRow =
          await (_database.select(_database.organizations)..where(
                (row) =>
                    row.id.equals(userRow.organizationId) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (organizationRow == null) {
        continue;
      }

      final assignments =
          await (_database.select(_database.userRoleAssignments)..where(
                (row) => row.userId.equals(userRow.id) & row.revokedAt.isNull(),
              ))
              .get();
      final roleIds = assignments.map((item) => item.roleId).toSet();
      final rolesById = <String, AccessRole>{};
      for (final roleId in roleIds) {
        final roleRow =
            await (_database.select(_database.roles)..where(
                  (row) =>
                      row.id.equals(roleId) &
                      row.isActive.equals(true) &
                      row.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (roleRow == null) {
          continue;
        }
        final grants = await (_database.select(
          _database.rolePermissions,
        )..where((row) => row.roleId.equals(roleId))).get();
        rolesById[roleId] = AccessRole(
          id: roleRow.id,
          code: roleRow.code,
          name: roleRow.name,
          permissions: {
            for (final grant in grants)
              if (AppPermission.fromCode(grant.permissionCode)
                  case final permission?)
                permission,
          },
        );
      }

      final organizationRoles = assignments
          .where((assignment) => assignment.branchId == null)
          .map((assignment) => rolesById[assignment.roleId])
          .whereType<AccessRole>()
          .toList(growable: false);
      final explicitlyAssignedBranchIds = assignments
          .where((assignment) => rolesById.containsKey(assignment.roleId))
          .map((assignment) => assignment.branchId)
          .whereType<String>()
          .toSet();

      final branchQuery = _database.select(_database.branches)
        ..where(
          (row) =>
              row.organizationId.equals(organizationRow.id) &
              row.isActive.equals(true) &
              row.deletedAt.isNull(),
        );
      final branchRows = await branchQuery.get();
      final confirmedJson = await _database.metadataDao.readValue(
        'auth.confirmed_branches.$firebaseUid.${organizationRow.id}',
      );
      final confirmedIds = confirmedJson == null
          ? null
          : (jsonDecode(confirmedJson) as List).cast<String>().toSet();
      final unacceptedCreations =
          await (_database.select(_database.syncOutboxEntries)..where(
                (row) =>
                    row.organizationId.equals(organizationRow.id) &
                    row.commandType.equals('branch.create') &
                    row.status.equals('succeeded').not(),
              ))
              .get();
      final blockedIds = unacceptedCreations
          .map((row) => row.aggregateId)
          .toSet();
      branchRows.removeWhere(
        (branch) =>
            blockedIds.contains(branch.id) ||
            (confirmedIds != null && !confirmedIds.contains(branch.id)),
      );
      final accessibleBranchRows = organizationRoles.isNotEmpty
          ? branchRows
          : branchRows
                .where(
                  (branch) => explicitlyAssignedBranchIds.contains(branch.id),
                )
                .toList(growable: false);

      organizations.add(
        OrganizationAccess(
          appUserId: userRow.id,
          organization: model.Organization(
            id: organizationRow.id,
            code: organizationRow.code,
            name: organizationRow.name,
            timezone: organizationRow.timezone,
          ),
          status: UserAccountStatus.parse(userRow.status),
          organizationRoles: organizationRoles,
          branches: [
            for (final branchRow in accessibleBranchRows)
              BranchAccess(
                branch: model.Branch(
                  id: branchRow.id,
                  organizationId: branchRow.organizationId,
                  code: branchRow.code,
                  name: branchRow.name,
                  timezone: branchRow.timezone,
                  addressLineOne: branchRow.addressLineOne,
                  addressLineTwo: branchRow.addressLineTwo,
                  city: branchRow.city,
                  province: branchRow.province,
                  postalCode: branchRow.postalCode,
                  phone: branchRow.phone,
                  email: branchRow.email,
                  receiptDisplayName: branchRow.receiptDisplayName,
                  isActive: branchRow.isActive,
                  version: branchRow.version,
                ),
                roles: assignments
                    .where((assignment) => assignment.branchId == branchRow.id)
                    .map((assignment) => rolesById[assignment.roleId])
                    .whereType<AccessRole>()
                    .toList(growable: false),
              ),
          ],
        ),
      );
    }

    if (organizations.isEmpty) {
      return null;
    }
    final firstUser = userRows.first;
    return model.AppUser(
      firebaseUid: firebaseUid,
      email: firstUser.email,
      displayName: firstUser.displayName,
      organizations: organizations,
    );
  }

  @override
  Future<void> replaceProfile(model.AppUser user) {
    return _database.transaction(() async {
      await _database.metadataDao.deleteValue(
        'auth.access_revoked.${user.firebaseUid}',
      );
      final now = DateTime.now().toUtc();

      // Retain identity and historical assignment rows referenced by sales/audit.
      final previous = await (_database.select(
        _database.appUsers,
      )..where((row) => row.firebaseUid.equals(user.firebaseUid))).get();
      for (final row in previous) {
        await (_database.update(_database.userRoleAssignments)..where(
              (assignment) =>
                  assignment.userId.equals(row.id) &
                  assignment.revokedAt.isNull(),
            ))
            .write(db.UserRoleAssignmentsCompanion(revokedAt: Value(now)));
      }

      for (final access in user.organizations) {
        await _database.metadataDao.writeValue(
          key:
              'auth.confirmed_branches.${user.firebaseUid}.${access.organization.id}',
          value: jsonEncode(
            access.branches
                .where((item) => item.branch.isActive)
                .map((item) => item.branch.id)
                .toList(),
          ),
          updatedAt: now,
        );
        await _database
            .into(_database.organizations)
            .insertOnConflictUpdate(
              db.OrganizationsCompanion.insert(
                id: access.organization.id,
                code: access.organization.code,
                name: access.organization.name,
                timezone: Value(access.organization.timezone),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _database
            .into(_database.appUsers)
            .insertOnConflictUpdate(
              db.AppUsersCompanion.insert(
                id: access.appUserId,
                organizationId: access.organization.id,
                firebaseUid: Value(user.firebaseUid),
                email: user.email,
                displayName: user.displayName,
                status: access.status.name,
                createdAt: now,
                updatedAt: now,
              ),
            );

        final rolesById = <String, AccessRole>{
          for (final role in access.organizationRoles) role.id: role,
          for (final branch in access.branches)
            for (final role in branch.roles) role.id: role,
        };
        for (final branchAccess in access.branches) {
          final branch = branchAccess.branch;
          final pending =
              await (_database.select(_database.syncOutboxEntries)
                    ..where(
                      (row) =>
                          row.aggregateType.equals('branch') &
                          row.aggregateId.equals(branch.id) &
                          row.status.isIn(const [
                            'pending',
                            'processing',
                            'retryable_failure',
                            'permanent_failure',
                            'conflict',
                          ]),
                    )
                    ..limit(1))
                  .getSingleOrNull();
          if (pending != null) continue;
          final existing = await (_database.select(
            _database.branches,
          )..where((row) => row.id.equals(branch.id))).getSingleOrNull();
          if (existing != null && existing.version > branch.version) continue;
          await _database
              .into(_database.branches)
              .insertOnConflictUpdate(
                db.BranchesCompanion.insert(
                  id: branch.id,
                  organizationId: access.organization.id,
                  code: branch.code,
                  name: branch.name,
                  timezone: Value(branch.timezone),
                  addressLineOne: Value(branch.addressLineOne),
                  addressLineTwo: Value(branch.addressLineTwo),
                  city: Value(branch.city),
                  province: Value(branch.province),
                  postalCode: Value(branch.postalCode),
                  phone: Value(branch.phone),
                  email: Value(branch.email),
                  receiptDisplayName: Value(branch.receiptDisplayName),
                  isActive: Value(branch.isActive),
                  version: Value(branch.version),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
        for (final role in rolesById.values) {
          await _database
              .into(_database.roles)
              .insertOnConflictUpdate(
                db.RolesCompanion.insert(
                  id: role.id,
                  organizationId: access.organization.id,
                  code: role.code,
                  name: role.name,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          await (_database.delete(
            _database.rolePermissions,
          )..where((row) => row.roleId.equals(role.id))).go();
          for (final permission in role.permissions) {
            await _database
                .into(_database.permissions)
                .insertOnConflictUpdate(
                  db.PermissionsCompanion.insert(
                    code: permission.code,
                    name: permission.code,
                    createdAt: now,
                  ),
                );
            await _database
                .into(_database.rolePermissions)
                .insert(
                  db.RolePermissionsCompanion.insert(
                    roleId: role.id,
                    permissionCode: permission.code,
                    grantedAt: now,
                  ),
                );
          }
        }

        for (final role in access.organizationRoles) {
          await _insertAssignment(
            access: access,
            role: role,
            branchId: null,
            now: now,
          );
        }
        for (final branchAccess in access.branches) {
          for (final role in branchAccess.roles) {
            await _insertAssignment(
              access: access,
              role: role,
              branchId: branchAccess.branch.id,
              now: now,
            );
          }
        }
      }
    });
  }

  @override
  Future<DateTime?> lastVerifiedAt(String firebaseUid) async {
    final value = await _database.metadataDao.readValue(
      _verificationKey(firebaseUid),
    );
    return value == null ? null : DateTime.tryParse(value)?.toUtc();
  }

  @override
  Future<void> recordVerifiedAt(String firebaseUid, DateTime verifiedAt) {
    return _database.metadataDao.writeValue(
      key: _verificationKey(firebaseUid),
      value: verifiedAt.toUtc().toIso8601String(),
      updatedAt: verifiedAt.toUtc(),
    );
  }

  Future<void> _insertAssignment({
    required OrganizationAccess access,
    required AccessRole role,
    required String? branchId,
    required DateTime now,
  }) async {
    final scope = branchId ?? 'organization';
    final existing =
        await (_database.select(_database.userRoleAssignments)
              ..where(
                (row) =>
                    row.userId.equals(access.appUserId) &
                    row.roleId.equals(role.id) &
                    (branchId == null
                        ? row.branchId.isNull()
                        : row.branchId.equals(branchId)),
              )
              ..limit(1))
            .getSingleOrNull();
    await _database
        .into(_database.userRoleAssignments)
        .insertOnConflictUpdate(
          db.UserRoleAssignmentsCompanion.insert(
            id: existing?.id ?? '${access.appUserId}:$scope:${role.id}',
            organizationId: access.organization.id,
            branchId: Value(branchId),
            userId: access.appUserId,
            roleId: role.id,
            assignedAt: now,
            revokedAt: const Value(null),
          ),
        );
  }

  @override
  Future<void> clearProfile(String firebaseUid) async {
    await _database.metadataDao.writeValue(
      key: 'auth.access_revoked.$firebaseUid',
      value: 'true',
      updatedAt: DateTime.now().toUtc(),
    );
    await _database.metadataDao.deleteValue(_verificationKey(firebaseUid));
  }
}
