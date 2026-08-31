import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/auth/domain/entities/auth_session.dart';
import 'package:jce_pos/features/transfers/domain/entities/stock_transfer.dart';
import 'package:jce_pos/features/transfers/presentation/pages/transfers_page.dart';
import 'package:jce_pos/features/transfers/presentation/providers/transfers_providers.dart';
import 'package:jce_pos/shared/models/access_role.dart';
import 'package:jce_pos/shared/models/app_user.dart';
import 'package:jce_pos/shared/models/branch.dart';
import 'package:jce_pos/shared/models/branch_access.dart';
import 'package:jce_pos/shared/models/organization.dart';
import 'package:jce_pos/shared/models/organization_access.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  testWidgets('transfer list opens item custody and immutable history', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTransferSessionProvider.overrideWithValue(_session),
          stockTransfersProvider.overrideWith(
            (ref) => Stream.value([_transfer]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TransfersPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TR-SRC-20260831-0001'), findsOneWidget);
    expect(find.text('Source Branch → Destination Branch'), findsOneWidget);
    expect(find.text('In transit'), findsOneWidget);

    final openButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Open transfer'),
        matching: find.byType(IconButton),
      ),
    );
    openButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('SKU-1 — Transfer Product'), findsOneWidget);
    expect(find.text('Warehouse → Receiving'), findsOneWidget);
    expect(find.text('shipped'), findsOneWidget);
    expect(find.text('Approved → In transit'), findsOneWidget);
  });
}

final _now = DateTime.utc(2026, 8, 31, 8);

final _transfer = StockTransfer(
  id: 'transfer',
  transferNumber: 'TR-SRC-20260831-0001',
  sourceBranchId: 'source',
  sourceBranchName: 'Source Branch',
  destinationBranchId: 'destination',
  destinationBranchName: 'Destination Branch',
  status: StockTransferStatus.shipped,
  approvalRequired: true,
  createdByUserId: 'user',
  approvedByUserId: 'user',
  version: 3,
  createdAt: _now,
  updatedAt: _now,
  lines: [
    StockTransferLine(
      id: 'item',
      productId: 'product',
      sku: 'SKU-1',
      productName: 'Transfer Product',
      sourceStockLocationId: 'warehouse',
      sourceLocationName: 'Warehouse',
      destinationStockLocationId: 'receiving',
      destinationLocationName: 'Receiving',
      requestedQuantityMilli: 2000,
      shippedQuantityMilli: 2000,
      receivedQuantityMilli: 0,
      damagedQuantityMilli: 0,
      discrepancyQuantityMilli: 2000,
      version: 1,
    ),
  ],
  events: [
    TransferEvent(
      id: 'event',
      eventType: 'shipped',
      fromStatus: StockTransferStatus.approved,
      toStatus: StockTransferStatus.shipped,
      actorUserId: 'user',
      occurredAt: _now,
    ),
  ],
);

const _role = AccessRole(
  id: 'manager',
  code: 'manager',
  name: 'Manager',
  permissions: {AppPermission.manageInventory, AppPermission.approveTransfers},
);

const _session = AuthSession(
  activeOrganizationId: 'organization',
  activeBranchId: 'source',
  user: AppUser(
    firebaseUid: 'firebase-user',
    email: 'user@jce.test',
    displayName: 'Transfer User',
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
              id: 'source',
              organizationId: 'organization',
              code: 'SRC',
              name: 'Source Branch',
              timezone: 'Asia/Manila',
            ),
            roles: [_role],
          ),
          BranchAccess(
            branch: Branch(
              id: 'destination',
              organizationId: 'organization',
              code: 'DST',
              name: 'Destination Branch',
              timezone: 'Asia/Manila',
            ),
            roles: [_role],
          ),
        ],
      ),
    ],
  ),
);
