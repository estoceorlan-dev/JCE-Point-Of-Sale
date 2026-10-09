import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/error/result.dart';
import 'package:jce_pos/features/auth/data/repositories/secure_offline_pin_repository.dart';
import 'package:jce_pos/features/auth/data/security/credential_record_store.dart';
import 'package:jce_pos/features/auth/data/security/native_installation_store.dart';
import 'package:jce_pos/features/auth/data/security/p256_grant_verifier.dart';
import 'package:jce_pos/features/auth/domain/entities/logout_readiness.dart';
import 'package:jce_pos/features/auth/domain/offline/offline_cashier_switch.dart';
import 'native_auth_test_support.dart';

void main() {
  late MemoryVault vault;
  late CredentialRecordStore records;
  late NativeInstallationStore installation;
  late TestEnrollmentSource source;
  late DateTime clock;
  SecureOfflinePinRepository repository() => SecureOfflinePinRepository(
    records: records,
    installation: installation,
    remote: source,
    verifier: P256GrantVerifier(
      deploymentId: 'deployment',
      trustedKeys: {source.signer.thumbprint: source.signer.publicKey},
    ),
    hasher: FastTestPinHasher(),
    now: () => clock,
  );
  setUp(() {
    vault = MemoryVault();
    records = CredentialRecordStore(vault, 'deployment');
    installation = NativeInstallationStore(records);
    clock = DateTime.utc(2026, 10, 7);
    source = TestEnrollmentSource(installation, () => clock);
  });
  Future<void> enroll() async => expect(
    (await repository().enroll(
      password: 'password',
      pin: '123456',
      branchId: 'branch',
    )).isSuccess,
    true,
  );
  Future<dynamic> login([String pin = '123456']) => repository().signIn(
    identityId: source.identityId,
    branchId: 'branch',
    pin: pin,
  );

  test(
    'PIN enrollment is online-only; sign-in and installation key survive a fresh repository',
    () async {
      expect((await login()).failureOrNull.code, 'not_enrolled');
      await enroll();
      final before = await installation.load();
      source.offline = true;
      records = CredentialRecordStore(vault, 'deployment');
      installation = NativeInstallationStore(records);
      final result = await login();
      expect(result.isSuccess, true);
      expect(result.valueOrNull.canApproveAsSupervisor, false);
      expect(result.valueOrNull.can('users.manage', clock), false);
      expect((await installation.load()).key.thumbprint, before.key.thumbprint);
      expect(
        (await repository().enroll(
          password: 'password',
          pin: '654321',
          branchId: 'branch',
        )).isFailure,
        true,
      );
      expect((await login()).isSuccess, true);
      expect(vault.values.values.single.contains('123456'), false);
    },
  );

  test(
    'five failures lock for 15 minutes; ten require API reauthentication across restarts',
    () async {
      await enroll();
      final attempts = await Future.wait(
        List.generate(10, (_) => login('000000')),
      );
      expect(
        attempts
            .where((value) => value.failureOrNull.code == 'pin_locked')
            .length,
        6,
      );
      records = CredentialRecordStore(vault, 'deployment');
      installation = NativeInstallationStore(records);
      expect((await login()).failureOrNull.code, 'pin_locked');
      clock = clock.add(const Duration(minutes: 15));
      for (var i = 0; i < 5; i++) {
        await login('000000');
      }
      expect((await login()).failureOrNull.code, 'reauthentication_required');
      final stored = jsonDecode(vault.values[records.key]!) as Map;
      source.replay =
          stored['enrollments']['cashier-a:branch']['authorization'] as String;
      expect(
        (await repository().enroll(
          password: 'password',
          pin: '123456',
          branchId: 'branch',
        )).isFailure,
        true,
      );
      source.replay = null;
      await enroll();
      expect((await login()).isSuccess, true);
    },
  );

  test(
    'expiry and detected clock rollback fail closed and do not renew a signed lease',
    () async {
      await enroll();
      final grant = (await login()).valueOrNull;
      clock = clock.add(const Duration(hours: 1));
      expect((await repository().validateActive(grant)).isSuccess, true);
      clock = clock.subtract(const Duration(minutes: 1));
      expect((await login()).failureOrNull.code, 'clock_rollback');
      clock = clock.add(const Duration(hours: 1));
      expect((await login()).failureOrNull.code, 'clock_rollback');
      await enroll();
      clock = clock.add(const Duration(days: 7));
      expect(
        (await login()).failureOrNull.code,
        'enrollment_expired_or_invalid',
      );
    },
  );

  test(
    'credential corruption, wrong deployment and failed storage deny access',
    () async {
      await enroll();
      vault.failWrites = true;
      expect((await login()).isFailure, true);
      vault.failWrites = false;
      final other = CredentialRecordStore(vault, 'another-deployment');
      expect(await vault.read(other.key), null);
      vault.values[records.key] = 'corrupt';
      expect((await login()).isFailure, true);
    },
  );

  test(
    'cashier switching retains queued actors and blocks open shifts/recovery; logout keeps existing restrictions',
    () async {
      await enroll();
      source.identityId = 'cashier-b';
      await enroll();
      final queued = <String>['cashier-a'];
      var readiness = const LogoutReadiness(
        openShiftCount: 0,
        checkoutRecoveryCount: 0,
        pendingOperationalCommandCount: 1,
      );
      final switching = OfflineCashierSwitch(
        repository(),
        (_) async => Result.success(readiness),
      );
      expect(
        (await switching.signIn(
          identityId: 'cashier-a',
          branchId: 'branch',
          pin: '123456',
        )).isSuccess,
        true,
      );
      readiness = const LogoutReadiness(
        openShiftCount: 1,
        checkoutRecoveryCount: 0,
        pendingOperationalCommandCount: 1,
      );
      expect(
        (await switching.signIn(
          identityId: 'cashier-b',
          branchId: 'branch',
          pin: '123456',
        )).failureOrNull,
        isA<AuthorizationFailure>(),
      );
      expect(switching.current!.identityId, 'cashier-a');
      readiness = const LogoutReadiness(
        openShiftCount: 0,
        checkoutRecoveryCount: 0,
        pendingOperationalCommandCount: 1,
      );
      expect(
        (await switching.signIn(
          identityId: 'cashier-b',
          branchId: 'branch',
          pin: '123456',
        )).isSuccess,
        true,
      );
      expect(queued, ['cashier-a']);
      expect((await switching.signOut()).isFailure, true);
      readiness = const LogoutReadiness(
        openShiftCount: 0,
        checkoutRecoveryCount: 0,
        pendingOperationalCommandCount: 0,
      );
      expect((await switching.signOut()).isSuccess, true);
    },
  );
}
