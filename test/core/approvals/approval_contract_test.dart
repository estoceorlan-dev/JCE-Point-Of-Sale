import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/approvals/domain/approval_challenge.dart';
import 'package:jce_pos/core/approvals/domain/approval_grant.dart';
import 'package:jce_pos/core/approvals/supervisor_approval_provider.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/shared/models/business_context.dart';

final _now = DateTime.utc(2026, 9, 7, 12);

void main() {
  final challenge = _challenge();
  final grant = ApprovalGrant(
    id: 'grant',
    challenge: challenge,
    approverUserId: 'supervisor',
    credentialId: 'credential',
    approvedAt: _now,
    expiresAt: _now.add(const Duration(minutes: 2)),
  );

  test('binding metadata rejects changes to every operation/context field', () {
    expect(grant.hasValidBinding(_challenge(), _now), isTrue);
    for (final field in [
      'id',
      'organizationId',
      'branchId',
      'requestedByUserId',
      'deviceId',
      'operationId',
      'operationType',
      'aggregateId',
      'operationDigest',
      'permissionCode',
    ]) {
      final changed = _challenge(
        overrides: {field: field == 'operationDigest' ? 'b' * 64 : 'different'},
      );
      expect(grant.hasValidBinding(changed, _now), isFalse, reason: field);
    }
    expect(
      grant.hasValidBinding(
        _challenge(expiresAt: _now.add(const Duration(minutes: 10))),
        _now,
      ),
      isFalse,
    );
    expect(
      grant.hasValidBinding(
        _challenge(createdAt: _now.subtract(const Duration(minutes: 1))),
        _now,
      ),
      isFalse,
    );
  });

  test('time boundaries reject future, expired, and malformed metadata', () {
    expect(
      grant.hasValidBinding(
        challenge,
        _now.subtract(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(grant.hasValidBinding(challenge, grant.expiresAt), isFalse);
    expect(challenge.isValidAt(challenge.expiresAt), isFalse);
    expect(_challenge(overrides: {'deviceId': ' '}).isValidAt(_now), isFalse);
    expect(
      _challenge(
        overrides: {'operationDigest': 'not-a-digest'},
      ).isValidAt(_now),
      isFalse,
    );
    final overlong = ApprovalGrant(
      id: 'g',
      challenge: challenge,
      approverUserId: 'supervisor',
      credentialId: 'c',
      approvedAt: _now,
      expiresAt: challenge.expiresAt.add(const Duration(seconds: 1)),
    );
    expect(overlong.hasValidBinding(challenge, _now), isFalse);
  });

  test(
    'default provider cannot enroll or approve even valid metadata',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(supervisorApprovalServiceProvider);
      final enrollment = await service.enroll(
        context: const BusinessContext(
          organizationId: 'org',
          branchId: 'branch',
          actorUserId: 'supervisor',
        ),
        deviceId: 'device',
        pin: '123456',
      );
      final approval = await service.approve(
        challenge: challenge,
        credentialId: 'credential',
        pin: '123456',
      );
      expect(enrollment.failureOrNull, isA<AuthorizationFailure>());
      expect(approval.failureOrNull, isA<AuthorizationFailure>());
      expect(approval.valueOrNull, isNull);
      expect(approval.failureOrNull!.message, isNot(contains('123456')));
    },
  );
}

ApprovalChallenge _challenge({
  Map<String, String> overrides = const {},
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  final fields = {
    'id': 'challenge',
    'organizationId': 'org',
    'branchId': 'branch',
    'requestedByUserId': 'cashier',
    'deviceId': 'device',
    'operationId': 'operation',
    'operationType': 'sale.discount',
    'aggregateId': 'sale',
    'operationDigest': 'a' * 64,
    'permissionCode': 'sales.discount.approve',
    ...overrides,
  };
  return ApprovalChallenge(
    id: fields['id']!,
    organizationId: fields['organizationId']!,
    branchId: fields['branchId']!,
    requestedByUserId: fields['requestedByUserId']!,
    deviceId: fields['deviceId']!,
    operationId: fields['operationId']!,
    operationType: fields['operationType']!,
    aggregateId: fields['aggregateId']!,
    operationDigest: fields['operationDigest']!,
    permissionCode: fields['permissionCode']!,
    createdAt: createdAt ?? _now,
    expiresAt: expiresAt ?? _now.add(const Duration(minutes: 5)),
  );
}
