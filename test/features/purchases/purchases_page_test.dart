import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/auth/domain/entities/auth_session.dart';
import 'package:jce_pos/features/purchases/domain/entities/goods_receipt.dart';
import 'package:jce_pos/features/purchases/domain/entities/purchase_order.dart';
import 'package:jce_pos/features/purchases/presentation/pages/purchases_page.dart';
import 'package:jce_pos/features/purchases/presentation/providers/purchases_providers.dart';
import 'package:jce_pos/shared/models/access_role.dart';
import 'package:jce_pos/shared/models/app_user.dart';
import 'package:jce_pos/shared/models/branch.dart';
import 'package:jce_pos/shared/models/branch_access.dart';
import 'package:jce_pos/shared/models/organization.dart';
import 'package:jce_pos/shared/models/organization_access.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  testWidgets('purchase order list exposes receipt and cost history', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePurchaseSessionProvider.overrideWithValue(_session),
          purchaseOrdersProvider.overrideWith((ref) => Stream.value([_order])),
          suppliersProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: Scaffold(body: PurchasesPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PO-MAIN-20260831-00000001'), findsOneWidget);
    expect(find.text('Primary Supplier'), findsOneWidget);
    expect(find.text('Partially received'), findsOneWidget);

    final openButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Open purchase order'),
        matching: find.byType(IconButton),
      ),
    );
    openButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('SKU-1 — Purchase Product'), findsOneWidget);
    expect(find.text('Goods receipts and cost history'), findsOneWidget);
    expect(find.text('GR-MAIN-20260831-00000001'), findsOneWidget);
    await tester.tap(find.text('GR-MAIN-20260831-00000001'));
    await tester.pumpAndSettle();
    expect(find.textContaining('landed PHP 3.00 / unit'), findsOneWidget);
    expect(find.text('Avg PHP 2.00'), findsOneWidget);
  });
}

final _now = DateTime.utc(2026, 8, 31, 8);

final _order = PurchaseOrder(
  id: 'order',
  orderNumber: 'PO-MAIN-20260831-00000001',
  supplierId: 'supplier',
  supplierName: 'Primary Supplier',
  status: PurchaseOrderStatus.partiallyReceived,
  createdByUserId: 'user',
  approvedByUserId: 'user',
  version: 4,
  createdAt: _now,
  updatedAt: _now,
  lines: const [
    PurchaseOrderLine(
      id: 'item',
      productId: 'product',
      sku: 'SKU-1',
      productName: 'Purchase Product',
      orderedQuantityMilli: 5000,
      receivedQuantityMilli: 2000,
      cancelledQuantityMilli: 0,
      unitCostMinor: 200,
      estimatedLandedCostMinor: 300,
      version: 1,
    ),
  ],
  receipts: [
    GoodsReceipt(
      id: 'receipt',
      receiptNumber: 'GR-MAIN-20260831-00000001',
      stockLocationId: 'location',
      stockLocationName: 'Warehouse',
      receivedByUserId: 'user',
      receivedAt: _now,
      lines: const [
        GoodsReceiptLine(
          id: 'receipt-item',
          purchaseOrderItemId: 'item',
          productId: 'product',
          productName: 'Purchase Product',
          receivedQuantityMilli: 2000,
          unitCostMinor: 200,
          freightCostMinor: 200,
          dutyCostMinor: 0,
          otherLandedCostMinor: 0,
          landedUnitCostMinor: 300,
          weightedAverageCostMinorAfter: 200,
        ),
      ],
    ),
  ],
);

const _role = AccessRole(
  id: 'buyer',
  code: 'buyer',
  name: 'Buyer',
  permissions: {
    AppPermission.createPurchases,
    AppPermission.approvePurchases,
    AppPermission.receivePurchases,
    AppPermission.manageSuppliers,
  },
);

const _session = AuthSession(
  activeOrganizationId: 'organization',
  activeBranchId: 'branch',
  user: AppUser(
    firebaseUid: 'firebase-user',
    email: 'buyer@jce.test',
    displayName: 'Buyer',
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
