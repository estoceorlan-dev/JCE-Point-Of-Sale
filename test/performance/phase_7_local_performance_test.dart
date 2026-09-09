import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/imports/data/repositories/drift_csv_import_repository.dart';
import 'package:jce_pos/features/imports/domain/entities/csv_import.dart';
import 'package:jce_pos/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:jce_pos/features/pos/data/data_sources/sales_local_data_source.dart';
import 'package:jce_pos/features/pos/data/repositories/drift_sales_repository.dart';
import 'package:jce_pos/features/pos/domain/entities/cart.dart';
import 'package:jce_pos/features/pos/domain/entities/payment.dart';
import 'package:jce_pos/features/pos/domain/entities/sale.dart';
import 'package:jce_pos/features/products/data/data_sources/product_catalog_local_data_source.dart';
import 'package:jce_pos/features/products/data/repositories/drift_products_repository.dart';
import 'package:jce_pos/features/products/domain/entities/product_query.dart';
import 'package:jce_pos/shared/models/business_context.dart';

const _enabled = bool.fromEnvironment('JCE_RUN_PHASE_7_PERFORMANCE');
const _productCount = int.fromEnvironment(
  'JCE_PERFORMANCE_PRODUCT_COUNT',
  defaultValue: 10000,
);
const _sampleCount = 5;
const _barcodeTargetMs = 200.0;
const _textSearchTargetMs = 500.0;
const _checkoutTargetMs = 1000.0;

void main() {
  test(
    'file-backed Windows pilot performance targets',
    () async {
      expect(_productCount, greaterThanOrEqualTo(10000));
      final directory = await Directory.systemTemp.createTemp(
        'jce-phase-7-performance-',
      );
      final databaseFile = File(
        '${directory.path}${Platform.pathSeparator}jce-performance.sqlite',
      );
      final database = AppDatabase.forTesting(
        NativeDatabase.createInBackground(databaseFile),
      );
      final clock = FixedAppClock(DateTime.utc(2026, 9, 9, 8));
      try {
        await _seedContext(database, clock.nowUtc());
        final csv = _catalogCsv(_productCount);
        DriftProductsRepository productsFactory(IdGenerator ids) =>
            DriftProductsRepository(
              localDataSource: ProductCatalogLocalDataSource(database),
              localMutationTransaction: LocalMutationTransaction(database),
              idGenerator: ids,
              clock: clock,
            );
        InventoryRepository inventoryFactory(IdGenerator _) =>
            throw UnsupportedError('Opening-stock import is not benchmarked.');
        final imports = DriftCsvImportRepository(
          database: database,
          clock: clock,
          productsFactory: productsFactory,
          inventoryFactory: inventoryFactory,
        );

        late CsvImportPreview preview;
        final previewMs = await _measure(() async {
          final result = await imports.preview(
            context: _context,
            kind: CsvImportKind.catalog,
            source: csv,
          );
          expect(
            result.isSuccess,
            isTrue,
            reason: result.failureOrNull?.message,
          );
          preview = result.valueOrNull!;
          expect(preview.rows, hasLength(_productCount));
          expect(preview.canConfirm, isTrue);
        });
        final importCommitMs = await _measure(() async {
          final result = await imports.confirm(
            context: _context,
            preview: preview,
          );
          expect(
            result.isSuccess,
            isTrue,
            reason: result.failureOrNull?.message,
          );
          expect(result.valueOrNull, _productCount);
        });

        final products = await database.select(database.products).get();
        expect(products, hasLength(_productCount));
        final target = products.singleWhere(
          (row) => row.normalizedSku == _targetSku,
        );
        await _seedCheckoutData(
          database,
          productId: target.id,
          now: clock.nowUtc(),
        );

        final productRepository = productsFactory(_SequenceIds('catalog'));
        final salesRepository = DriftSalesRepository(
          database: database,
          localDataSource: SalesLocalDataSource(database),
          localMutationTransaction: LocalMutationTransaction(database),
          idGenerator: _SequenceIds('sale'),
          clock: clock,
        );
        await productRepository
            .watchProducts(
              context: _context,
              query: const ProductQuery(search: 'Catalog Item 00000'),
            )
            .first;
        await salesRepository
            .watchSaleProducts(context: _context, search: _targetBarcode)
            .first;

        final textSamples = <double>[];
        final barcodeSamples = <double>[];
        for (var sample = 0; sample < _sampleCount; sample++) {
          textSamples.add(
            await _measure(() async {
              final page = await productRepository
                  .watchProducts(
                    context: _context,
                    query: ProductQuery(search: _targetProductName),
                  )
                  .first;
              expect(page.items.single.id, target.id);
            }),
          );
          barcodeSamples.add(
            await _measure(() async {
              final result = await salesRepository
                  .watchSaleProducts(context: _context, search: _targetBarcode)
                  .first;
              expect(result.single.id, target.id);
            }),
          );
        }

        final pendingCountMs = await _measure(() async {
          expect(await database.outboxDao.pendingCount(), _productCount);
        });
        final outboxClaimMs = await _measure(() async {
          final claimed = await database.outboxDao.claimEligibleBatch(
            now: clock.nowUtc(),
            organizationId: _context.organizationId,
            branchId: _context.branchId,
            actorUserId: _context.actorUserId,
          );
          expect(claimed, hasLength(25));
        });

        final saleProduct =
            (await salesRepository
                    .watchSaleProducts(
                      context: _context,
                      search: _targetBarcode,
                    )
                    .first)
                .single;
        final checkoutMs = await _measure(() async {
          final result = await salesRepository.checkout(
            context: _context,
            draft: CheckoutDraft(
              operationId: 'performance-checkout',
              deviceId: _deviceId,
              cart: Cart(
                lines: [CartLine(product: saleProduct, quantityMilli: 1000)],
              ),
              tenders: const [
                PaymentTender(
                  method: SalePaymentMethod.cash,
                  tenderedAmountMinor: 1000,
                ),
              ],
            ),
          );
          expect(
            result.isSuccess,
            isTrue,
            reason: result.failureOrNull?.message,
          );
        });

        final metrics = <String, Object>{
          'measuredAtUtc': DateTime.now().toUtc().toIso8601String(),
          'platform': Platform.operatingSystem,
          'platformVersion': Platform.operatingSystemVersion,
          'processors': Platform.numberOfProcessors,
          'database':
              'file-backed SQLite via NativeDatabase background isolate',
          'productCount': _productCount,
          'catalogImportPreviewMs': previewMs,
          'catalogImportCommitMs': importCommitMs,
          'textSearchSamplesMs': textSamples,
          'textSearchWorstMs': _worst(textSamples),
          'barcodeLookupSamplesMs': barcodeSamples,
          'barcodeLookupWorstMs': _worst(barcodeSamples),
          'outboxPendingCountMs': pendingCountMs,
          'outboxClaim25Ms': outboxClaimMs,
          'checkoutCommitMs': checkoutMs,
          'targetsMs': const {
            'barcodeLookup': _barcodeTargetMs,
            'textSearch': _textSearchTargetMs,
            'checkoutCommit': _checkoutTargetMs,
          },
        };
        final output = File('build/phase_7_performance.json');
        await output.parent.create(recursive: true);
        await output.writeAsString(
          const JsonEncoder.withIndent('  ').convert(metrics),
        );
        stdout.writeln(jsonEncode(metrics));

        expect(_worst(barcodeSamples), lessThan(_barcodeTargetMs));
        expect(_worst(textSamples), lessThan(_textSearchTargetMs));
        expect(checkoutMs, lessThan(_checkoutTargetMs));
      } finally {
        await database.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
    skip: _enabled
        ? false
        : 'Set JCE_RUN_PHASE_7_PERFORMANCE=true for the opt-in benchmark.',
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

const _context = BusinessContext(
  organizationId: 'performance-organization',
  branchId: 'performance-branch',
  actorUserId: 'performance-user',
);
const _deviceId = 'performance-device';
String get _targetSku => 'SKU${(_productCount - 1).toString().padLeft(5, '0')}';
String get _targetProductName =>
    'Target Item ${(_productCount - 1).toString().padLeft(5, '0')}';
String get _targetBarcode =>
    '9${(_productCount - 1).toString().padLeft(11, '0')}';

String _catalogCsv(int count) {
  final result = StringBuffer(
    'sku,name,unit_code,price,barcodes,primary_barcode\n',
  );
  for (var index = 0; index < count; index++) {
    final sequence = index.toString().padLeft(5, '0');
    final sku = 'SKU$sequence';
    final name = index == count - 1
        ? 'Target Item $sequence'
        : 'Catalog Item $sequence';
    final barcode = '9${index.toString().padLeft(11, '0')}';
    result.writeln('$sku,$name,PC,10.00,$barcode,$barcode');
  }
  return result.toString();
}

Future<double> _measure(Future<void> Function() action) async {
  final stopwatch = Stopwatch()..start();
  await action();
  stopwatch.stop();
  return double.parse(
    (stopwatch.elapsedMicroseconds / Duration.microsecondsPerMillisecond)
        .toStringAsFixed(3),
  );
}

double _worst(List<double> samples) =>
    samples.reduce((current, next) => current > next ? current : next);

Future<void> _seedContext(AppDatabase database, DateTime now) async {
  await database.batch((batch) {
    batch.insert(
      database.organizations,
      OrganizationsCompanion.insert(
        id: _context.organizationId,
        code: 'PERF',
        name: 'Performance Organization',
        createdAt: now,
        updatedAt: now,
      ),
    );
    batch.insert(
      database.branches,
      BranchesCompanion.insert(
        id: _context.branchId,
        organizationId: _context.organizationId,
        code: 'PERF',
        name: 'Performance Branch',
        createdAt: now,
        updatedAt: now,
      ),
    );
    batch.insert(
      database.units,
      UnitsCompanion.insert(
        id: 'performance-unit',
        organizationId: _context.organizationId,
        code: 'PC',
        name: 'Piece',
        abbreviation: 'pc',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });
}

Future<void> _seedCheckoutData(
  AppDatabase database, {
  required String productId,
  required DateTime now,
}) async {
  await database.batch((batch) {
    batch.insert(
      database.stockLocations,
      StockLocationsCompanion.insert(
        id: 'performance-location',
        organizationId: _context.organizationId,
        branchId: _context.branchId,
        code: 'FLOOR',
        name: 'Sales Floor',
        locationType: const Value('sales_floor'),
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
    );
    batch.insert(
      database.inventoryBalances,
      InventoryBalancesCompanion.insert(
        id: 'performance-balance',
        organizationId: _context.organizationId,
        branchId: _context.branchId,
        stockLocationId: 'performance-location',
        productId: productId,
        onHandMilli: const Value(100000),
        updatedAt: now,
      ),
    );
    batch.insert(
      database.registers,
      RegistersCompanion.insert(
        id: 'performance-register',
        organizationId: _context.organizationId,
        branchId: _context.branchId,
        code: 'REG',
        name: 'Performance Register',
        assignedDeviceId: const Value(_deviceId),
        createdAt: now,
        updatedAt: now,
      ),
    );
    batch.insert(
      database.shifts,
      ShiftsCompanion.insert(
        id: 'performance-shift',
        organizationId: _context.organizationId,
        branchId: _context.branchId,
        registerId: 'performance-register',
        deviceId: _deviceId,
        operationId: 'performance-shift-open',
        openingCashMinor: 0,
        openedByUserId: _context.actorUserId,
        openedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });
}

class _SequenceIds implements IdGenerator {
  _SequenceIds(this.prefix);

  final String prefix;
  var _value = 0;

  @override
  String newId() => '$prefix-${_value++}';
}
