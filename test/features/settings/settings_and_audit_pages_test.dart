import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart' show SyncConflict;
import 'package:jce_pos/core/error/result.dart';
import 'package:jce_pos/core/sync/sync_controller.dart';
import 'package:jce_pos/features/auth/domain/entities/auth_session.dart';
import 'package:jce_pos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:jce_pos/features/logs/presentation/pages/logs_page.dart';
import 'package:jce_pos/features/logs/presentation/providers/logs_providers.dart';
import 'package:jce_pos/features/settings/domain/entities/operational_setting.dart';
import 'package:jce_pos/features/settings/presentation/pages/settings_page.dart';
import 'package:jce_pos/features/settings/presentation/providers/settings_providers.dart';
import 'package:jce_pos/shared/models/access_role.dart';
import 'package:jce_pos/shared/models/app_user.dart';
import 'package:jce_pos/shared/models/audit_log_entry.dart';
import 'package:jce_pos/shared/models/branch.dart';
import 'package:jce_pos/shared/models/branch_access.dart';
import 'package:jce_pos/shared/models/organization.dart';
import 'package:jce_pos/shared/models/organization_access.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  testWidgets('settings page exposes precedence, reasons, and feature flags', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          operationalSettingsProvider.overrideWith(
            (ref) => Stream.value(OperationalSettings.defaults()),
          ),
          reasonCodesProvider.overrideWith((ref) => Stream.value(const [])),
          featureFlagsProvider.overrideWith((ref) => Stream.value(const [])),
          unresolvedSyncConflictsProvider.overrideWith(
            (ref) => Stream.value(const <SyncConflict>[]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operational settings'), findsOneWidget);
    expect(find.text('Organization default'), findsOneWidget);
    expect(find.text('Branch override'), findsOneWidget);
    expect(find.text('Behavior and policies'), findsOneWidget);
    expect(find.text('Reason codes'), findsOneWidget);
    expect(find.text('Feature flags'), findsOneWidget);
    expect(find.text('Sync conflicts'), findsOneWidget);
  });

  testWidgets('audit page filters and opens safe event details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final event = AuditLogEntry(
      id: 'audit',
      operationId: 'operation-14',
      organizationId: 'organization',
      actorUserId: 'user',
      branchId: 'branch',
      deviceId: 'device-14',
      actionType: AuditActionType.settingChange,
      entityName: 'setting',
      entityId: 'receipt.footer',
      metadata: const {'before': 'Thanks', 'after': 'Salamat'},
      createdAt: DateTime.utc(2026, 9, 2, 9),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          auditTrailProvider.overrideWith(
            (ref) => Stream.value(Result.success([event])),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LogsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Audit logs'), findsOneWidget);
    expect(find.text('Setting Change · Setting'), findsOneWidget);
    await tester.tap(find.text('Setting Change · Setting'));
    await tester.pumpAndSettle();
    expect(find.text('Safe metadata'), findsOneWidget);
    expect(find.textContaining('operation-14'), findsOneWidget);
    expect(find.textContaining('device-14'), findsOneWidget);
  });
}

class _FakeAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async => _session;
}

const _role = AccessRole(
  id: 'administrator',
  code: 'administrator',
  name: 'Administrator',
  permissions: {AppPermission.manageSettings, AppPermission.viewAuditLogs},
);

const _session = AuthSession(
  activeOrganizationId: 'organization',
  activeBranchId: 'branch',
  user: AppUser(
    firebaseUid: 'firebase-user',
    email: 'admin@jce.test',
    displayName: 'Administrator',
    organizations: [
      OrganizationAccess(
        appUserId: 'user',
        organization: Organization(
          id: 'organization',
          code: 'JCE',
          name: 'JCE',
          timezone: 'Asia/Manila',
        ),
        status: UserAccountStatus.active,
        organizationRoles: [],
        branches: [
          BranchAccess(
            branch: Branch(
              id: 'branch',
              organizationId: 'organization',
              code: 'MAIN',
              name: 'Main Branch',
              timezone: 'Asia/Manila',
            ),
            roles: [_role],
          ),
        ],
      ),
    ],
  ),
);
