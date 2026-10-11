import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/database/models/outbox_command.dart';
import 'package:jce_pos/core/remote/node_command_data_source.dart';
import 'package:jce_pos/core/remote/node_sync_data_source.dart';
import 'package:jce_pos/core/remote/node_bootstrap_data_source.dart';
import 'package:jce_pos/core/sync/node_actor_evidence.dart';
import 'package:jce_pos/core/sync/node_device_transport.dart';
import 'package:jce_pos/core/sync/drift_pos_bootstrap_repository.dart';
import 'package:jce_pos/core/sync/remote_change_applier.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/auth/domain/offline/native_auth_profile.dart';
import 'package:jce_pos/features/auth/data/datasources/native_auth_api.dart';
import 'package:jce_pos/features/auth/data/datasources/native_enrollment_source.dart';
import 'package:jce_pos/features/auth/data/datasources/access_local_data_source.dart';
import 'package:jce_pos/features/auth/data/repositories/native_api_session_repository.dart';
import 'package:jce_pos/features/auth/data/repositories/node_auth_repository.dart';
import 'package:jce_pos/features/auth/data/repositories/node_device_registration_repository.dart';
import 'package:jce_pos/features/auth/data/repositories/secure_offline_pin_repository.dart';
import 'package:jce_pos/features/auth/data/security/credential_record_store.dart';
import 'package:jce_pos/features/auth/data/security/native_installation_store.dart';
import 'package:jce_pos/features/auth/data/security/installation_binding.dart';
import 'package:jce_pos/features/auth/data/security/p256_grant_verifier.dart';
import 'package:jce_pos/features/pos/data/repositories/drift_sales_repository.dart';
import 'package:jce_pos/features/pos/data/data_sources/sales_local_data_source.dart';
import 'package:jce_pos/features/pos/domain/entities/cart.dart';
import 'package:jce_pos/features/pos/domain/entities/sale.dart'
    show CheckoutDraft;
import 'package:jce_pos/features/pos/domain/entities/payment.dart'
    show PaymentTender, SalePaymentMethod;
import 'package:jce_pos/shared/models/business_context.dart';
import 'package:jce_pos/features/auth/domain/offline/credential_vault.dart';

class SaleTestNetwork extends http.BaseClient {
  final delegate = http.Client();
  bool online = true;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!online) throw http.ClientException('API unavailable');
    return delegate.send(request);
  }

  @override
  void close() => delegate.close();
}

/// Shared live API scenario; callers choose real or in-memory credentials.
class NodeSaleScenario {
  NodeSaleScenario({
    required this.config,
    required this.directory,
    required CredentialVault vault,
    required PinHasher hasher,
  }) {
    final key = Map<String, String>.from(config['verificationKey'] as Map);
    profile = NativeAuthProfile(
      deploymentId: config['deploymentId'] as String,
      organizationCode: config['organizationCode'] as String,
      apiOrigin: Uri.parse(config['origin'] as String),
      offlineVerificationKeys: {key['kid']!: key},
      allowHttpLoopback: true,
    );
    final file = File('${directory.path}/pos.sqlite');
    database = AppDatabase.forTesting(NativeDatabase(file));

    records = CredentialRecordStore(vault, profile.deploymentId);
    installation = NativeInstallationStore(records);
    final api = NativeAuthApi(network, profile);
    binding = InstallationBinding(api, records);
    api.beforeRequest = binding.verify;
    sessions = NativeApiSessionRepository(api, records);
    final transport = NodeDeviceTransport(sessions, installation);
    final pins = SecureOfflinePinRepository(
      records: records,
      installation: installation,
      remote: NativeEnrollmentSource(
        sessions: sessions,
        installation: installation,
        platform: 'windows',
        displayName: 'Disposable sale acceptance test',
      ),
      verifier: P256GrantVerifier(
        deploymentId: profile.deploymentId,
        trustedKeys: profile.offlineVerificationKeys,
      ),
      hasher: hasher,
      now: DateTime.now,
    );
    actor = NodeActorEvidence(transport, installation, pins);
    auth = NodeAuthRepository(
      sessions,
      NodeDeviceRegistrationRepository(
        sessions,
        installation,
        database.metadataDao,
        'windows',
      ),
      DriftAccessLocalDataSource(database),
      actor,
      pins,
    );
    commands = NodeCommandDataSource(transport);
    remote = NodeSyncDataSource(transport);
  }
  final Map config;
  final Directory directory;
  final network = SaleTestNetwork();
  late final NativeAuthProfile profile;
  late final AppDatabase database;
  late final CredentialRecordStore records;
  late final NativeApiSessionRepository sessions;
  late final NativeInstallationStore installation;
  late final InstallationBinding binding;
  late final NodeAuthRepository auth;
  late final NodeActorEvidence actor;
  late final NodeCommandDataSource commands;
  late final NodeSyncDataSource remote;
  String id() => const Uuid().v4();

  Future<Map<String, String>> prepare() async {
    await binding.initialize();
    final login = await auth.signInWithEmailAndPassword(
      email: config['email'] as String,
      password: config['password'] as String,
    );
    expect(login.isSuccess, true, reason: '${login.failureOrNull}');
    final session = login.valueOrNull!;
    final context = BusinessContext(
      organizationId: session.activeOrganizationId,
      branchId: session.activeBranchId,
      actorUserId: session.activeOrganization.appUserId,
    );
    database.signOutboxCommand = actor.sign;
    Future<void> execute(
      String type,
      String aggregate,
      String entity,
      Map<String, Object?> payload,
    ) async {
      final operation = id();
      await database.outboxDao.enqueue(
        OutboxCommand(
          operationId: operation,
          organizationId: context.organizationId,
          branchId: context.branchId,
          actorUserId: context.actorUserId,
          commandType: type,
          aggregateType: aggregate,
          aggregateId: entity,
          payload: payload,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      final row = (await database.select(database.syncOutboxEntries).get())
          .singleWhere((row) => row.operationId == operation);
      await commands.execute(row);
      await database.outboxDao.markSucceeded(
        operationId: operation,
        now: DateTime.now().toUtc(),
      );
    }

    final unit = id(), product = id(), location = id(), register = id();
    await execute('unit.create', 'unit', unit, {
      'code': 'pc',
      'name': 'Piece',
      'abbreviation': 'pc',
      'allowsFractional': false,
    });
    await execute('product.create', 'product', product, {
      'id': product,
      'unitId': unit,
      'sku': 'LIVE-1',
      'name': 'Live item',
      'unitPriceMinor': 5000,
      'priceScope': 'organization',
      'barcodes': ['4800001'],
    });
    await execute('stock_location.create', 'stock_location', location, {
      'id': location,
      'code': 'FLOOR',
      'name': 'Floor',
      'locationType': 'sales_floor',
      'isDefault': true,
    });
    final stock = id();
    await execute(
      'inventory.transaction.post',
      'inventory_transaction',
      stock,
      {
        'id': stock,
        'transactionType': 'opening_balance',
        'lines': [
          {
            'productId': product,
            'stockLocationId': location,
            'quantityDeltaMilli': 10000,
          },
        ],
      },
    );
    await execute('register.create', 'register', register, {
      'id': register,
      'code': 'TILL',
      'name': 'Till',
    });
    final bootstrap = DriftPosBootstrapRepository(
      database: database,
      remote: NodeBootstrapDataSource(sessions),
    );
    final provision = await bootstrap.provision(context, force: true);
    expect(provision.isSuccess, true, reason: '${provision.failureOrNull}');
    final device = await installation.load();
    final claim = id();
    await execute('register.claim', 'register', claim, {
      'claimId': claim,
      'registerId': register,
      'deviceId': device.deviceId,
      'expectedVersion': 0,
    });
    final shift = id();
    await execute('shift.open', 'shift', shift, {
      'id': shift,
      'registerId': register,
      'deviceId': device.deviceId,
      'openingCashMinor': 0,
    });
    final changes = await remote.pullChanges(
      organizationId: context.organizationId,
      branchId: context.branchId,
      afterSequence: 0,
    );
    final applier = DriftRemoteChangeApplier(database);
    for (final change in changes) {
      await applier.apply(change);
    }
    final enrollment = await auth.enrollPin(
      config['password'] as String,
      '123456',
    );
    expect(enrollment.isSuccess, true, reason: '${enrollment.failureOrNull}');
    network.online = false;
    final offline = await auth.signInWithPin(
      identityId: session.user.identityId,
      branchId: context.branchId,
      pin: '123456',
    );
    expect(offline.isSuccess, true, reason: '${offline.failureOrNull}');
    final repository = DriftSalesRepository(
      database: database,
      localDataSource: SalesLocalDataSource(database),
      localMutationTransaction: LocalMutationTransaction(database),
      idGenerator: const UuidIdGenerator(),
      clock: const SystemAppClock(),
    );
    final products = await repository
        .watchSaleProducts(context: context, search: '4800001')
        .first;
    expect(products, hasLength(1));
    final saleOperation = id();
    final sale = await repository.checkout(
      context: context,
      draft: CheckoutDraft(
        operationId: saleOperation,
        deviceId: device.deviceId,
        cart: Cart(
          lines: [CartLine(product: products.single, quantityMilli: 1000)],
        ),
        tenders: const [
          PaymentTender(
            method: SalePaymentMethod.cash,
            tenderedAmountMinor: 5000,
          ),
        ],
      ),
    );
    expect(sale.isSuccess, true, reason: '${sale.failureOrNull}');
    expect(await database.select(database.sales).get(), hasLength(1));
    expect(await database.select(database.payments).get(), hasLength(1));
    expect(
      (await database.select(database.inventoryBalances).getSingle())
          .onHandMilli,
      9000,
    );
    final saved = (await database.select(database.syncOutboxEntries).get())
        .singleWhere((row) => row.operationId == saleOperation);
    expect(saved.evidenceJson, isNotNull);

    // Persist one failure so a new process must retain the retry counter.
    final wrong = await auth.signInWithPin(
      identityId: session.user.identityId,
      branchId: context.branchId,
      pin: '000000',
    );
    expect(
      wrong.failureOrNull,
      isA<AuthenticationFailure>().having(
        (failure) => failure.code,
        'code',
        'invalid_pin',
      ),
    );
    expect(
      await records.transact((state) async => state['session'] == null),
      true,
    );
    actor.clear();
    return {
      'saleOperation': saleOperation,
      'identityId': session.user.identityId,
      'organizationId': context.organizationId,
      'branchId': context.branchId,
      'deviceId': device.deviceId,
      'keyThumbprint': device.key.thumbprint,
      'evidenceDigest': sha256
          .convert(utf8.encode(saved.evidenceJson!))
          .toString(),
    };
  }

  Future<void> resume(Map<String, dynamic> checkpoint) async {
    network.online = false;
    await binding.initialize();
    final device = await installation.load();
    expect(device.deviceId, checkpoint['deviceId']);
    expect(device.key.thumbprint, checkpoint['keyThumbprint']);
    final enrollmentKey =
        '${checkpoint['identityId']}:${checkpoint['branchId']}';
    final failureCount = await records.transact(
      (state) async =>
          ((state['enrollments'] as Map)[enrollmentKey] as Map)['failures'],
    );
    expect(failureCount, 1);
    expect(
      await records.transact((state) async => state['session'] == null),
      true,
    );
    final offline = await auth.signInWithPin(
      identityId: checkpoint['identityId'] as String,
      branchId: checkpoint['branchId'] as String,
      pin: '123456',
    );
    expect(offline.isSuccess, true, reason: '${offline.failureOrNull}');
    actor.clear();
    final saleOperation = checkpoint['saleOperation'] as String;
    final reopened = (await database.select(database.syncOutboxEntries).get())
        .singleWhere((row) => row.operationId == saleOperation);
    expect(
      sha256.convert(utf8.encode(reopened.evidenceJson!)).toString(),
      checkpoint['evidenceDigest'],
    );
    expect(await database.select(database.sales).get(), hasLength(1));
    expect(await database.select(database.payments).get(), hasLength(1));
    expect(
      (await database.select(database.inventoryBalances).getSingle())
          .onHandMilli,
      9000,
    );
    network.online = true;
    // Persisted device key + original actor evidence, with no bearer session.
    expect((await commands.execute(reopened)).duplicate, false);
    expect((await commands.execute(reopened)).duplicate, true);
    final result = await remote.getProcessedOperation(
      organizationId: checkpoint['organizationId'] as String,
      branchId: checkpoint['branchId'] as String,
      operationId: saleOperation,
    );
    expect(result?.operationId, saleOperation);
    await database.outboxDao.markSucceeded(
      operationId: saleOperation,
      now: DateTime.now().toUtc(),
    );
  }

  Future<void> close() async {
    await auth.dispose();
    await database.close();
    network.close();
  }
}
