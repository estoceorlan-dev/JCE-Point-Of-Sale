import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/routing/app_navigation_item.dart';
import 'package:jce_pos/core/routing/app_route.dart';
import 'package:jce_pos/core/widgets/mobile_bottom_navigation.dart';
import 'package:jce_pos/features/auth/domain/entities/auth_session.dart';
import 'package:jce_pos/features/branches/domain/entities/branch_profile.dart';
import 'package:jce_pos/features/branches/presentation/pages/branch_details_page.dart';
import 'package:jce_pos/features/branches/presentation/pages/branches_page.dart';
import 'package:jce_pos/features/branches/presentation/providers/branches_providers.dart';
import 'package:jce_pos/shared/models/access_role.dart';
import 'package:jce_pos/shared/models/app_user.dart';
import 'package:jce_pos/shared/models/branch.dart';
import 'package:jce_pos/shared/models/branch_access.dart';
import 'package:jce_pos/shared/models/organization.dart';
import 'package:jce_pos/shared/models/organization_access.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  test(
    'limited administrators have explicit routes without cashier access',
    () {
      final roleAdmin = _session({AppPermission.manageRoles});
      expect(navigationItemsForSession(roleAdmin).map((item) => item.route), [
        AppRoute.users,
      ]);
      final registerAdmin = _session({AppPermission.manageRegisters});
      expect(
        navigationItemsForSession(registerAdmin).map((item) => item.route),
        [AppRoute.registers],
      );
      final branchAdmin = _session({AppPermission.manageBranches});
      expect(navigationItemsForSession(branchAdmin).map((item) => item.route), [
        AppRoute.branches,
      ]);
      expect(
        navigationItemsForSession(
          _session({
            AppPermission.manageBranches,
            AppPermission.manageRoles,
          }, branchOnly: true),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'compact navigation exposes permission-filtered grouped destinations',
    (tester) async {
      final session = _session({
        AppPermission.manageBranches,
        AppPermission.manageRoles,
      });
      AppRoute? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileBottomNavigation(
              items: navigationItemsForSession(session),
              selectedRoute: AppRoute.branches,
              onDestinationSelected: (item) => selected = item.route,
            ),
          ),
        ),
      );
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Administration'), findsOneWidget);
      expect(find.text('Operations'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Staff & Access'));
      await tester.pumpAndSettle();
      expect(selected, AppRoute.users);
    },
  );

  for (final size in [const Size(1280, 720), const Size(360, 640)]) {
    for (final details in [false, true]) {
      testWidgets(
        '${details ? 'branch details' : 'branch directory'} fits $size with pending state',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final profile = BranchProfile(
            id: 'pending',
            organizationId: 'org',
            code: 'NEW',
            name: 'New branch with a longer display name',
            timezone: 'Asia/Manila',
            isActive: true,
            version: 0,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            addressLineOne: '1 Main Street',
            receiptDisplayName: 'JCE New Branch',
            pendingOperations: 1,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                activeBranchAdminSessionProvider.overrideWith(
                  (ref) => _session(AppPermission.values.toSet()),
                ),
                branchProfileProvider.overrideWith(
                  (ref, id) => Stream.value(profile),
                ),
                branchDirectoryProvider.overrideWith(
                  (ref, query) => Stream.value([profile]),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: details
                      ? const BranchDetailsPage(branchId: 'pending')
                      : const BranchesPage(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('New branch'), findsWidgets);
          if (details) {
            expect(
              find.textContaining('refresh access before selecting'),
              findsOneWidget,
            );
            final registers = find.widgetWithText(
              OutlinedButton,
              'Registers & Hardware',
            );
            if (registers.evaluate().isNotEmpty) {
              expect(
                tester.widget<OutlinedButton>(registers).onPressed,
                isNull,
              );
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}

AuthSession _session(
  Set<AppPermission> permissions, {
  bool branchOnly = false,
}) {
  final role = AccessRole(
    id: 'role',
    code: 'custom',
    name: 'Custom',
    permissions: permissions,
  );
  return AuthSession(
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
          organizationRoles: branchOnly ? [] : [role],
          branches: [
            BranchAccess(
              branch: const Branch(
                id: 'main',
                organizationId: 'org',
                code: 'MAIN',
                name: 'Main branch',
                timezone: 'Asia/Manila',
              ),
              roles: branchOnly ? [role] : [],
            ),
          ],
        ),
      ],
    ),
    activeOrganizationId: 'org',
    activeBranchId: 'main',
  );
}
