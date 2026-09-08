import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/cart.dart';
import '../../domain/entities/checkout_attempt.dart';
import '../../domain/entities/held_cart.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/sale_product.dart';
import '../../domain/repositories/pos_cart_repository.dart';
import '../data_sources/sales_local_data_source.dart';

class DriftPosCartRepository implements PosCartRepository {
  const DriftPosCartRepository({
    required AppDatabase database,
    required SalesLocalDataSource salesLocalDataSource,
    required IdGenerator idGenerator,
    required AppClock clock,
  }) : _database = database,
       _salesLocalDataSource = salesLocalDataSource,
       _idGenerator = idGenerator,
       _clock = clock;

  final AppDatabase _database;
  final SalesLocalDataSource _salesLocalDataSource;
  final IdGenerator _idGenerator;
  final AppClock _clock;

  @override
  Future<Cart> loadActive({
    required BusinessContext context,
    required String deviceId,
  }) async {
    final row = await _activeQuery(context, deviceId).getSingleOrNull();
    return row == null ? const Cart() : _loadCart(context, row);
  }

  @override
  Future<void> saveActive({
    required BusinessContext context,
    required String deviceId,
    required Cart cart,
  }) async {
    await _database.transaction(() async {
      final existing = await _activeQuery(context, deviceId).getSingleOrNull();
      if (cart.isEmpty && cart.customerId == null) {
        if (existing != null) {
          await (_database.delete(
            _database.posCarts,
          )..where((row) => row.id.equals(existing.id))).go();
        }
        return;
      }
      final now = _clock.nowUtc();
      final id = existing?.id ?? _idGenerator.newId();
      await _database
          .into(_database.posCarts)
          .insertOnConflictUpdate(
            PosCartsCompanion.insert(
              id: id,
              organizationId: context.organizationId,
              branchId: context.branchId,
              deviceId: deviceId,
              status: 'active',
              customerId: Value(cart.customerId),
              saleDiscountMinor: Value(cart.saleDiscountMinor),
              saleDiscountReason: Value(cart.saleDiscountReason),
              activeScope: Value(_activeScope(context, deviceId)),
              checkoutOperationId: Value(cart.checkoutAttempt?.operationId),
              checkoutTendersJson: Value(
                cart.checkoutAttempt == null
                    ? null
                    : _encodeTenders(cart.checkoutAttempt!.tenders),
              ),
              externalPaymentApproved: Value(
                cart.checkoutAttempt?.externalPaymentApproved ?? false,
              ),
              checkoutAttemptedAt: Value(cart.checkoutAttempt?.attemptedAt),
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
            ),
          );
      await _replaceItems(id, cart, now);
    });
  }

  @override
  Stream<List<HeldCart>> watchHeld({
    required BusinessContext context,
    required String deviceId,
  }) {
    final query = _database.select(_database.posCarts)
      ..where(
        (row) =>
            row.organizationId.equals(context.organizationId) &
            row.branchId.equals(context.branchId) &
            row.deviceId.equals(deviceId) &
            row.status.equals('held'),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return query.watch().asyncMap((rows) async {
      return Future.wait([
        for (final row in rows)
          _loadCart(context, row).then(
            (cart) => HeldCart(
              id: row.id,
              title: row.title ?? 'Held sale',
              cart: cart,
              updatedAt: row.updatedAt,
            ),
          ),
      ]);
    });
  }

  @override
  Future<String?> holdActive({
    required BusinessContext context,
    required String deviceId,
    required Cart cart,
    required String title,
  }) async {
    if (cart.isEmpty) return null;
    await saveActive(context: context, deviceId: deviceId, cart: cart);
    return _database.transaction(() async {
      final active = await _activeQuery(context, deviceId).getSingleOrNull();
      if (active == null) return null;
      await (_database.update(
        _database.posCarts,
      )..where((row) => row.id.equals(active.id))).write(
        PosCartsCompanion(
          status: const Value('held'),
          title: Value(title.trim().isEmpty ? 'Held sale' : title.trim()),
          activeScope: const Value(null),
          updatedAt: Value(_clock.nowUtc()),
        ),
      );
      return active.id;
    });
  }

  @override
  Future<Cart?> resume({
    required BusinessContext context,
    required String deviceId,
    required String heldCartId,
  }) async {
    return _database.transaction(() async {
      final held =
          await (_database.select(_database.posCarts)..where(
                (row) =>
                    row.id.equals(heldCartId) &
                    row.organizationId.equals(context.organizationId) &
                    row.branchId.equals(context.branchId) &
                    row.deviceId.equals(deviceId) &
                    row.status.equals('held'),
              ))
              .getSingleOrNull();
      if (held == null) return null;
      final active = await _activeQuery(context, deviceId).getSingleOrNull();
      if (active != null) {
        await (_database.delete(
          _database.posCarts,
        )..where((row) => row.id.equals(active.id))).go();
      }
      await (_database.update(
        _database.posCarts,
      )..where((row) => row.id.equals(held.id))).write(
        PosCartsCompanion(
          status: const Value('active'),
          title: const Value(null),
          activeScope: Value(_activeScope(context, deviceId)),
          updatedAt: Value(_clock.nowUtc()),
        ),
      );
      return _loadCart(context, held);
    });
  }

  @override
  Future<void> deleteHeld({
    required BusinessContext context,
    required String deviceId,
    required String heldCartId,
  }) async {
    await (_database.delete(_database.posCarts)..where(
          (row) =>
              row.id.equals(heldCartId) &
              row.organizationId.equals(context.organizationId) &
              row.branchId.equals(context.branchId) &
              row.deviceId.equals(deviceId) &
              row.status.equals('held'),
        ))
        .go();
  }

  @override
  Future<Result<CheckoutAttempt, Failure>> prepareCheckoutAttempt({
    required BusinessContext context,
    required String deviceId,
    required List<PaymentTender> tenders,
    required bool externalPaymentsConfirmed,
  }) async {
    try {
      if (tenders.isEmpty) {
        return const Result.failure(
          ValidationFailure('Add at least one payment.'),
        );
      }
      final methods = <SalePaymentMethod>{};
      for (final tender in tenders) {
        if (!methods.add(tender.method)) {
          return const Result.failure(
            ValidationFailure('Use each payment method only once.'),
          );
        }
        if (tender.tenderedAmountMinor <= 0) {
          return const Result.failure(
            ValidationFailure('Payment amounts must be greater than zero.'),
          );
        }
      }
      final hasExternal = tenders.any(
        (tender) => tender.method != SalePaymentMethod.cash,
      );
      if (hasExternal && !externalPaymentsConfirmed) {
        return const Result.failure(
          ValidationFailure(
            'Confirm every external payment before completing the sale.',
          ),
        );
      }
      return _database.transaction(() async {
        final active = await _activeQuery(context, deviceId).getSingleOrNull();
        if (active == null) {
          return const Result.failure(
            DatabaseFailure(
              'The active cart is not saved yet. Wait a moment and retry.',
            ),
          );
        }
        final existing = _attemptFromRow(active);
        if (existing?.externalPaymentApproved == true &&
            !existing!.hasSameTenders(tenders)) {
          return const Result.failure(
            ConflictFailure(
              'An externally approved payment is awaiting reconciliation. '
              'Retry with the saved amounts and references; do not charge again.',
            ),
          );
        }
        final attempt = CheckoutAttempt(
          operationId: existing?.operationId ?? _idGenerator.newId(),
          tenders: List.unmodifiable(tenders),
          externalPaymentApproved:
              existing?.externalPaymentApproved == true || hasExternal,
          attemptedAt: existing?.attemptedAt ?? _clock.nowUtc(),
        );
        await (_database.update(
          _database.posCarts,
        )..where((row) => row.id.equals(active.id))).write(
          PosCartsCompanion(
            checkoutOperationId: Value(attempt.operationId),
            checkoutTendersJson: Value(_encodeTenders(attempt.tenders)),
            externalPaymentApproved: Value(attempt.externalPaymentApproved),
            checkoutAttemptedAt: Value(attempt.attemptedAt),
            updatedAt: Value(_clock.nowUtc()),
          ),
        );
        return Result.success(attempt);
      });
    } on Failure catch (failure) {
      return Result.failure(failure);
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          'The checkout attempt could not be saved.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  SimpleSelectStatement<$PosCartsTable, PosCart> _activeQuery(
    BusinessContext context,
    String deviceId,
  ) {
    return _database.select(_database.posCarts)..where(
      (row) =>
          row.organizationId.equals(context.organizationId) &
          row.branchId.equals(context.branchId) &
          row.deviceId.equals(deviceId) &
          row.status.equals('active'),
    );
  }

  Future<void> _replaceItems(String cartId, Cart cart, DateTime now) async {
    await (_database.delete(
      _database.posCartItems,
    )..where((row) => row.cartId.equals(cartId))).go();
    for (var index = 0; index < cart.lines.length; index++) {
      final line = cart.lines[index];
      await _database
          .into(_database.posCartItems)
          .insert(
            PosCartItemsCompanion.insert(
              id: _idGenerator.newId(),
              cartId: cartId,
              productId: line.product.id,
              snapshotSku: line.product.sku,
              snapshotName: line.product.name,
              quantityMilli: line.quantityMilli,
              itemDiscountMinor: Value(line.itemDiscountMinor),
              discountReason: Value(line.discountReason),
              position: index,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<Cart> _loadCart(BusinessContext context, PosCart row) async {
    final items =
        await (_database.select(_database.posCartItems)
              ..where((item) => item.cartId.equals(row.id))
              ..orderBy([(item) => OrderingTerm.asc(item.position)]))
            .get();
    final lines = <CartLine>[];
    for (final item in items) {
      final current = await _salesLocalDataSource.getSaleProduct(
        organizationId: context.organizationId,
        branchId: context.branchId,
        productId: item.productId,
        now: _clock.nowUtc(),
      );
      final validation = current == null
          ? '${item.snapshotName} is archived or unavailable at this branch.'
          : current.unitPriceMinor <= 0
          ? '${current.name} has no active selling price.'
          : item.quantityMilli > current.availableQuantityMilli
          ? '${current.name} exceeds currently available stock.'
          : null;
      lines.add(
        CartLine(
          product: current ?? _placeholder(item),
          quantityMilli: item.quantityMilli,
          itemDiscountMinor: item.itemDiscountMinor,
          discountReason: item.discountReason,
          validationMessage: validation,
        ),
      );
    }
    return Cart(
      lines: lines,
      saleDiscountMinor: row.saleDiscountMinor,
      saleDiscountReason: row.saleDiscountReason,
      customerId: row.customerId,
      checkoutAttempt: _attemptFromRow(row),
    );
  }

  CheckoutAttempt? _attemptFromRow(PosCart row) {
    final operationId = row.checkoutOperationId;
    final tendersJson = row.checkoutTendersJson;
    final attemptedAt = row.checkoutAttemptedAt;
    if (operationId == null || tendersJson == null || attemptedAt == null) {
      return null;
    }
    final decoded = jsonDecode(tendersJson);
    if (decoded is! List<Object?>) {
      throw const FormatException('Checkout tenders must be a JSON list.');
    }
    final tenders = <PaymentTender>[];
    final methods = <SalePaymentMethod>{};
    for (final item in decoded) {
      if (item is! Map<String, Object?>) {
        throw const FormatException('Checkout tender entry is invalid.');
      }
      final method = item['method'];
      final amount = item['amountMinor'];
      final reference = item['reference'];
      if (method is! String ||
          amount is! int ||
          (reference != null && reference is! String)) {
        throw const FormatException('Checkout tender fields are invalid.');
      }
      final paymentMethod = SalePaymentMethod.values.firstWhere(
        (candidate) => candidate.databaseValue == method,
        orElse: () =>
            throw FormatException('Unknown checkout payment method: $method.'),
      );
      if (!methods.add(paymentMethod)) {
        throw const FormatException('Checkout payment methods must be unique.');
      }
      if (amount <= 0) {
        throw const FormatException(
          'Checkout payment amounts must be greater than zero.',
        );
      }
      tenders.add(
        PaymentTender(
          method: paymentMethod,
          tenderedAmountMinor: amount,
          reference: reference as String?,
        ),
      );
    }
    return CheckoutAttempt(
      operationId: operationId,
      tenders: List.unmodifiable(tenders),
      externalPaymentApproved: row.externalPaymentApproved,
      attemptedAt: attemptedAt,
    );
  }

  String _encodeTenders(List<PaymentTender> tenders) => jsonEncode([
    for (final tender in tenders)
      {
        'method': tender.method.databaseValue,
        'amountMinor': tender.tenderedAmountMinor,
        'reference': _normalizedReference(tender.reference),
      },
  ]);

  SaleProduct _placeholder(PosCartItem item) => SaleProduct(
    id: item.productId,
    sku: item.snapshotSku,
    name: item.snapshotName,
    unitName: 'unit',
    stockLocationId: '',
    stockLocationName: 'Unavailable',
    unitPriceMinor: 0,
    unitCostMinor: 0,
    taxRateBasisPoints: 0,
    taxInclusive: false,
    availableQuantityMilli: 0,
    inventoryVersion: 0,
  );

  String _activeScope(BusinessContext context, String deviceId) =>
      '${context.organizationId}|${context.branchId}|$deviceId';
}

String? _normalizedReference(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
