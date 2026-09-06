import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../../../shared/models/business_context.dart';

/// Runs inside the surrounding SQLite transaction. A failed guard rolls back
/// the access change together with its audit and outbox writes.
class StaffAccessGuard {
  const StaffAccessGuard(this.database);
  final AppDatabase database;

  Future<T> run<T>(
    BusinessContext context,
    Future<T> Function() mutation,
  ) async {
    final before = await _actorPermissions(context);
    final value = await mutation();
    final after = await _actorPermissions(context);
    if (!after.containsAll(before)) {
      throw const ValidationFailure(
        'This change would remove your own administration access.',
      );
    }
    final administrators = await database
        .customSelect(
          """
      SELECT ura.user_id FROM user_role_assignments ura
      JOIN app_users au ON au.id = ura.user_id AND au.organization_id = ura.organization_id
        AND au.status = 'active' AND au.deleted_at IS NULL
      JOIN roles r ON r.id = ura.role_id AND r.organization_id = ura.organization_id
        AND r.is_active = 1 AND r.deleted_at IS NULL
      JOIN role_permissions rp ON rp.role_id = r.id
      WHERE ura.organization_id = ? AND ura.branch_id IS NULL AND ura.revoked_at IS NULL
        AND rp.permission_code IN ('users.manage', 'roles.manage', 'branches.manage')
      GROUP BY ura.user_id HAVING count(DISTINCT rp.permission_code) = 3 LIMIT 1
    """,
          variables: [Variable.withString(context.organizationId)],
        )
        .get();
    if (administrators.isEmpty) {
      throw const ValidationFailure(
        'Keep at least one active full organization administrator.',
      );
    }
    return value;
  }

  Future<Set<String>> _actorPermissions(BusinessContext context) async {
    final rows = await database
        .customSelect(
          """
      SELECT DISTINCT rp.permission_code FROM user_role_assignments ura
      JOIN app_users au ON au.id = ura.user_id AND au.organization_id = ura.organization_id
        AND au.status = 'active' AND au.deleted_at IS NULL
      JOIN roles r ON r.id = ura.role_id AND r.organization_id = ura.organization_id
        AND r.is_active = 1 AND r.deleted_at IS NULL
      JOIN role_permissions rp ON rp.role_id = r.id
      WHERE ura.organization_id = ? AND ura.user_id = ? AND ura.branch_id IS NULL
        AND ura.revoked_at IS NULL
        AND rp.permission_code IN ('users.manage', 'roles.manage', 'branches.manage')
    """,
          variables: [
            Variable.withString(context.organizationId),
            Variable.withString(context.actorUserId),
          ],
        )
        .get();
    return {for (final row in rows) row.read<String>('permission_code')};
  }
}
