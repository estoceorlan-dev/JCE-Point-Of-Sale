import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:jce_pos/core/database/app_database.dart';
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
import 'native_auth_test_support.dart';

class _Network extends http.BaseClient {
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

void main() {
  final encoded = Platform.environment['JCE_AUTH_LIVE_PROFILE'];
  test(
    'Node deployment: SQLite offline checkout, original evidence, restart and lost-response retry',
    () async {
      final config = jsonDecode(encoded!) as Map;
      final key = Map<String, String>.from(config['verificationKey'] as Map);
      final profile = NativeAuthProfile(
        deploymentId: config['deploymentId'] as String,
        organizationCode: config['organizationCode'] as String,
        apiOrigin: Uri.parse(config['origin'] as String),
        offlineVerificationKeys: {key['kid']!: key},
        allowHttpLoopback: true,
      );
      final directory = await Directory.systemTemp.createTemp('jce-node-sale-');
      final file = File('${directory.path}/pos.sqlite');
      var database = AppDatabase.forTesting(NativeDatabase(file));
      final network = _Network();
      final vault = MemoryVault();
      final records = CredentialRecordStore(vault, profile.deploymentId);
      final installation = NativeInstallationStore(records);
      final api = NativeAuthApi(network, profile);
      final binding = InstallationBinding(api, records);
      api.beforeRequest = binding.verify;
      final sessions = NativeApiSessionRepository(api, records);
      final transport = NodeDeviceTransport(sessions, installation);
      final pins = SecureOfflinePinRepository(
        records: records,
        installation: installation,
        remote: NativeEnrollmentSource(
          sessions: sessions,
          installation: installation,
          platform: 'windows',
          displayName: 'Sale test',
        ),
        verifier: P256GrantVerifier(
          deploymentId: profile.deploymentId,
          trustedKeys: profile.offlineVerificationKeys,
        ),
        hasher: FastTestPinHasher(),
        now: DateTime.now,
      );
      final actor = NodeActorEvidence(transport, installation, pins);
      final auth = NodeAuthRepository(
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
      final commands = NodeCommandDataSource(transport);
      final remote = NodeSyncDataSource(transport);
      String id() => const Uuid().v4();
      try {
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
        expect(
          enrollment.isSuccess,
          true,
          reason: '${enrollment.failureOrNull}',
        );
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
        actor.clear();
        await database.close();
        database = AppDatabase.forTesting(NativeDatabase(file));
        final reopened =
            (await database.select(database.syncOutboxEntries).get())
                .singleWhere((row) => row.operationId == saleOperation);
        expect(reopened.evidenceJson, saved.evidenceJson);
        network.online = true;
        // No signed-in cashier/session: possession of the device and saved actor evidence suffice.
        expect((await commands.execute(reopened)).duplicate, false);
        expect((await commands.execute(reopened)).duplicate, true);
        final result = await remote.getProcessedOperation(
          organizationId: context.organizationId,
          branchId: context.branchId,
          operationId: saleOperation,
        );
        expect(result?.operationId, saleOperation);
        expect(await database.select(database.sales).get(), hasLength(1));
      } finally {
        await auth.dispose();
        await database.close();
        network.close();
        await directory.delete(recursive: true);
      }
    },
    skip: encoded == null,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
