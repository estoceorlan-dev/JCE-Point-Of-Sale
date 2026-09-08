import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/auth/domain/entities/auth_session.dart';
import 'package:jce_pos/features/branches/presentation/providers/branches_providers.dart';
import 'package:jce_pos/features/users/domain/entities/staff_account.dart';
import 'package:jce_pos/features/users/presentation/pages/users_page.dart';
import 'package:jce_pos/features/users/presentation/providers/users_providers.dart';
import 'package:jce_pos/shared/models/access_role.dart';
import 'package:jce_pos/shared/models/app_user.dart';
import 'package:jce_pos/shared/models/organization.dart';
import 'package:jce_pos/shared/models/organization_access.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  testWidgets('branch and role filters combine and clear; pending is visible', (
    tester,
  ) async {
    await _open(tester);
    await _select(tester, 'branch', 'Second branch');
    await _select(tester, 'role', 'Cashier');
    expect(find.text('Alice'), findsNothing);
    expect(find.text('Bob'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Pending sync'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);
    expect(find.text('2 pending sync'), findsOneWidget);
  });

  testWidgets('branch deep link can be cleared and status/search combine', (
    tester,
  ) async {
    await _open(tester, branchId: 'main');
    expect(find.text('Bob'), findsNothing);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await _select(tester, 'status', 'Suspended');
    expect(find.text('Alice'), findsNothing);
    expect(find.text('Bob'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'alice');
    await tester.pumpAndSettle();
    expect(find.text('No staff accounts match these filters.'), findsOneWidget);
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets('compact staff directory supports text scale $scale', (
      tester,
    ) async {
      await _open(
        tester,
        size: const Size(360, 640),
        scale: scale,
        longName: true,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('2 pending sync'), findsOneWidget);
    });
  }

  testWidgets(
    'role-only administrator does not load staff or branch directory',
    (tester) async {
      await _open(tester, permissions: {AppPermission.manageRoles});
      expect(find.text('New role'), findsOneWidget);
      await tester.tap(find.text('Staff directory'));
      await tester.pumpAndSettle();
      expect(find.textContaining('requires organization-wide'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
    },
  );
}

Future<void> _select(WidgetTester tester, String filter, String label) async {
  final field = find.byKey(Key('staff-$filter-filter'));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(1280, 900),
  String? branchId,
  double scale = 1,
  bool longName = false,
  Set<AppPermission> permissions = const {
    AppPermission.manageUsers,
    AppPermission.manageRoles,
  },
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final now = DateTime.utc(2026);
  final accounts = [
    for (final id in ['Alice', 'Bob'])
      StaffAccount(
        id: id,
        organizationId: 'org',
        email: '$id@example.test',
        displayName: longName
            ? '$id with a long staff display name for compact operations'
            : id,
        status: id == 'Alice'
            ? UserAccountStatus.active
            : UserAccountStatus.suspended,
        assignments: [
          StaffAssignment(
            id: 'assignment-$id',
            userId: id,
            roleId: 'cashier',
            roleName: 'Cashier',
            branchId: id == 'Alice' ? 'main' : 'second',
            branchName: id == 'Alice' ? 'Main branch' : 'Second branch',
            version: 0,
          ),
        ],
        version: 0,
        createdAt: now,
        updatedAt: now,
        pendingOperations: id == 'Alice' ? 2 : 0,
      ),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeUserAdminSessionProvider.overrideWith(
          (ref) => AuthSession(
            user: AppUser(
              firebaseUid: 'uid',
              email: 'admin@example.test',
              displayName: 'Admin',
              organizations: [
                OrganizationAccess(
                  appUserId: 'admin',
                  organization: const Organization(
                    id: 'org',
                    code: 'ORG',
                    name: 'Organization',
                    timezone: 'Asia/Manila',
                  ),
                  status: UserAccountStatus.active,
                  organizationRoles: [
                    AccessRole(
                      id: 'custom',
                      code: 'custom',
                      name: 'Custom',
                      permissions: permissions,
                    ),
                  ],
                  branches: [],
                ),
              ],
            ),
            activeOrganizationId: 'org',
            activeBranchId: 'main',
          ),
        ),
        staffDirectoryProvider.overrideWith((ref) {
          expect(permissions.contains(AppPermission.manageUsers), isTrue);
          return Stream.value(accounts);
        }),
        roleDirectoryProvider.overrideWith(
          (ref, archived) => Stream.value(const [
            RoleDefinition(
              id: 'cashier',
              organizationId: 'org',
              code: 'cashier',
              name: 'Cashier',
              permissions: {},
              isActive: true,
              version: 0,
              assignmentCount: 2,
            ),
          ]),
        ),
        branchDirectoryProvider.overrideWith((ref, query) {
          expect(permissions.contains(AppPermission.manageUsers), isTrue);
          return Stream.value([]);
        }),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: UsersPage(branchId: branchId)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
