import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/branches/domain/entities/branch_profile.dart';
import 'package:jce_pos/features/pos/domain/entities/sale.dart';
import 'package:jce_pos/features/pos/domain/entities/sale_status.dart';
import 'package:jce_pos/features/pos/domain/services/receipt_renderer.dart';

void main() {
  final sale = SaleRecord(
    id: 'sale',
    branchId: 'branch',
    registerId: 'register',
    registerName: 'Register',
    receiptNumber: 'OLD-CODE-0001',
    status: SaleStatus.completed,
    cashierUserId: 'cashier',
    subtotalMinor: 0,
    discountMinor: 0,
    taxMinor: 0,
    totalMinor: 0,
    tenderedMinor: 0,
    changeMinor: 0,
    completedAt: DateTime.utc(2026),
    items: const [],
    payments: const [],
  );
  BranchProfile profile(String id) => BranchProfile(
    id: id,
    organizationId: 'org',
    code: 'NEW-CODE',
    name: 'Branch',
    timezone: 'Asia/Manila',
    isActive: true,
    version: 1,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    receiptDisplayName: 'JCE Branch Store',
    addressLineOne: '1 Main Street',
    city: 'Quezon City',
    province: 'Metro Manila',
    postalCode: '1100',
    phone: '+63 912 345 6789',
    email: 'branch@example.test',
  );

  test(
    'operational profile appears without renumbering historical receipts',
    () {
      final text = PlainTextReceiptRenderer(
        branchProfile: profile('branch'),
      ).render(sale, isReprint: true).plainText;
      expect(text, startsWith('JCE Branch Store\n1 Main Street'));
      expect(text, contains('Quezon City, Metro Manila, 1100'));
      expect(text, contains('branch@example.test'));
      expect(text, contains('Receipt OLD-CODE-0001'));
      expect(text, contains('REPRINT'));
      expect(text, isNot(contains('NEW-CODE')));
    },
  );
  test('another branch profile is never printed on a historical receipt', () {
    final text = PlainTextReceiptRenderer(
      header: 'Organization',
      branchProfile: profile('different'),
    ).render(sale).plainText;
    expect(text, startsWith('Organization\n'));
    expect(text, isNot(contains('1 Main Street')));
  });
}
