import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/auth_session.dart';

Future<void> checkCashierExit(AppDatabase database, AuthSession session) async {
  final shift =
      await (database.select(database.shifts)
            ..where(
              (row) =>
                  row.organizationId.equals(session.activeOrganizationId) &
                  row.branchId.equals(session.activeBranchId) &
                  row.openedByUserId.equals(
                    session.activeOrganization.appUserId,
                  ) &
                  row.status.equals('open'),
            )
            ..limit(1))
          .getSingleOrNull();
  final recovery =
      await (database.select(database.posCarts)
            ..where(
              (row) =>
                  row.organizationId.equals(session.activeOrganizationId) &
                  row.branchId.equals(session.activeBranchId) &
                  row.ownerUserId.equals(session.activeOrganization.appUserId) &
                  row.checkoutOperationId.isNotNull(),
            )
            ..limit(1))
          .getSingleOrNull();
  if (shift != null || recovery != null) {
    throw const AuthorizationFailure(
      'Close your shift and finish payment recovery before switching cashiers.',
    );
  }
}
