import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/auth/domain/entities/auth_session.dart';
import 'package:jce_pos/features/customers/domain/entities/customer.dart';
import 'package:jce_pos/features/customers/domain/entities/loyalty_account.dart';
import 'package:jce_pos/features/customers/presentation/pages/customers_page.dart';
import 'package:jce_pos/features/customers/presentation/providers/customers_providers.dart';
import 'package:jce_pos/shared/models/access_role.dart';
import 'package:jce_pos/shared/models/app_user.dart';
import 'package:jce_pos/shared/models/branch.dart';
import 'package:jce_pos/shared/models/branch_access.dart';
import 'package:jce_pos/shared/models/organization.dart';
import 'package:jce_pos/shared/models/organization_access.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  testWidgets('customer directory exposes private profile and history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeCustomerSessionProvider.overrideWithValue(_session),
          customerDirectoryProvider.overrideWith(
            (ref, query) => Stream.value([_customer]),
          ),
          customerProfileProvider.overrideWith(
            (ref, customerId) => Stream.value(_profile),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: CustomersPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customers & loyalty'), findsOneWidget);
    expect(find.text('Ana Reyes'), findsOneWidget);
    expect(find.text('CUS-00000001'), findsOneWidget);
    expect(find.text('125'), findsOneWidget);

    await tester.tap(find.byTooltip('Open customer'));
    await tester.pumpAndSettle();

    expect(find.text('Customer details'), findsOneWidget);
    expect(find.text('125 loyalty points'), findsOneWidget);
    expect(find.text('Branch purchase history'), findsOneWidget);
    expect(find.text('MAIN-REG-00000001'), findsOneWidget);
    expect(find.text('Immutable loyalty ledger'), findsOneWidget);
    expect(find.text('Welcome credit'), findsOneWidget);
    expect(find.text('Private branch notes'), findsOneWidget);
    expect(find.text('Prefers SMS updates'), findsOneWidget);
  });
}

final _now = DateTime.utc(2026, 9, 1, 8);

final _customer = CustomerSummary(
  id: 'customer',
  customerNumber: 'CUS-00000001',
  displayName: 'Ana Reyes',
  email: 'ana@example.com',
  phone: '+63 917 555 0101',
  status: CustomerStatus.active,
  version: 1,
  loyaltyPoints: 125,
  createdAt: _now,
  updatedAt: _now,
);

final _profile = CustomerProfile(
  customer: _customer,
  addresses: const [
    CustomerAddress(
      id: 'address',
      label: 'Home',
      lineOne: '123 Main Street',
      city: 'Manila',
      countryCode: 'PH',
      isPrimary: true,
      version: 0,
    ),
  ],
  notes: [
    CustomerNote(
      id: 'note',
      body: 'Prefers SMS updates',
      createdByUserId: 'user',
      createdAt: _now,
    ),
  ],
  purchases: [
    CustomerPurchase(
      saleId: 'sale',
      receiptNumber: 'MAIN-REG-00000001',
      status: 'completed',
      totalMinor: 10000,
      completedAt: _now,
    ),
  ],
  loyaltyAccount: LoyaltyAccount(
    id: 'loyalty',
    status: 'active',
    pointsBalance: 125,
    lifetimeEarnedPoints: 125,
    lifetimeRedeemedPoints: 0,
    version: 1,
    entries: [
      LoyaltyLedgerEntry(
        id: 'entry',
        operationId: 'operation',
        type: LoyaltyEntryType.adjustment,
        pointsDelta: 125,
        balanceAfter: 125,
        reason: 'Welcome credit',
        createdByUserId: 'user',
        occurredAt: _now,
      ),
    ],
  ),
);

const _customerRole = AccessRole(
  id: 'customer-manager',
  code: 'customer_manager',
  name: 'Customer manager',
  permissions: {
    AppPermission.viewCustomers,
    AppPermission.manageCustomers,
    AppPermission.anonymizeCustomers,
    AppPermission.manageLoyalty,
  },
);

const _session = AuthSession(
  activeOrganizationId: 'organization',
  activeBranchId: 'branch',
  user: AppUser(
    firebaseUid: 'firebase-user',
    email: 'manager@jce.test',
    displayName: 'Customer Manager',
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
            roles: [_customerRole],
          ),
        ],
      ),
    ],
  ),
);
