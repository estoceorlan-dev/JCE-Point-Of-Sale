import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart'
    hide Payment, Sale, SaleItem;
import '../../../../core/database/app_database.dart'
    as db
    show Branche, Register, Sale, SaleItem, SaleReturn, Shift;
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/database/models/outbox_command.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../../../inventory/data/services/inventory_ledger_writer.dart';
import '../../../inventory/domain/entities/inventory_movement.dart';
import '../../../inventory/domain/entities/inventory_transaction_type.dart';
import '../../domain/entities/cart.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_correction.dart';
import '../../domain/entities/sale_product.dart';
import '../../domain/entities/sale_status.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/value_objects/cart_pricing.dart';
import '../data_sources/sales_local_data_source.dart';
import '../services/receipt_number_allocator.dart';

class DriftSalesRepository implements SalesRepository {
  const DriftSalesRepository({
    required AppDatabase database,
    required SalesLocalDataSource localDataSource,
    required LocalMutationTransaction localMutationTransaction,
    required IdGenerator idGenerator,
    required AppClock clock,
  }) : _database = database,
       _localDataSource = localDataSource,
       _localMutationTransaction = localMutationTransaction,
       _idGenerator = idGenerator,
       _clock = clock;

  final AppDatabase _database;
  final SalesLocalDataSource _localDataSource;
  final LocalMutationTransaction _localMutationTransaction;
  final IdGenerator _idGenerator;
  final AppClock _clock;

  InventoryLedgerWriter get _ledgerWriter =>
      InventoryLedgerWriter(idGenerator: _idGenerator);

  ReceiptNumberAllocator get _receiptAllocator =>
      ReceiptNumberAllocator(idGenerator: _idGenerator);

  @override
  Stream<List<SaleProduct>> watchSaleProducts({
    required BusinessContext context,
    required String search,
  }) {
    return _localDataSource.watchSaleProducts(
      organizationId: context.organizationId,
      branchId: context.branchId,
      search: search,
      now: _clock.nowUtc(),
    );
  }

  @override
  Stream<List<SaleRecord>> watchRecentSales({
    required BusinessContext context,
  }) {
    return _localDataSource.watchRecentSales(
      organizationId: context.organizationId,
      branchId: context.branchId,
    );
  }

  @override
  Future<SaleRecord?> getSale({
    required BusinessContext context,
    required String saleId,
  }) {
    return _localDataSource.getSale(
      organizationId: context.organizationId,
      branchId: context.branchId,
      saleId: saleId,
    );
  }

  @override
  Future<DiscountPolicy?> getDiscountPolicy({
    required BusinessContext context,
  }) async {
    final branch = await _findBranch(_database, context);
    if (branch == null) return null;
    return DiscountPolicy(
      approvalThresholdBasisPoints: branch.discountApprovalThresholdBasisPoints,
    );
  }

  @override
  Future<List<ReturnDestination>> getReturnDestinations({
    required BusinessContext context,
  }) async {
    final rows =
        await (_database.select(_database.stockLocations)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.branchId.equals(context.branchId) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([
                (row) => OrderingTerm.desc(row.isDefault),
                (row) => OrderingTerm.asc(row.name),
              ]))
            .get();
    return rows
        .map(
          (row) => ReturnDestination(
            stockLocationId: row.id,
            name: row.name,
            locationType: row.locationType,
            isDefault: row.isDefault,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<SaleCorrectionPolicy?> getCorrectionPolicy({
    required BusinessContext context,
  }) async {
    final branch = await _findBranch(_database, context);
    if (branch == null) return null;
    return SaleCorrectionPolicy(
      returnApprovalThresholdMinor: branch.returnApprovalThresholdMinor,
      voidWindowMinutes: branch.voidWindowMinutes,
    );
  }

  @override
  Future<Result<void, Failure>> configureCorrectionPolicy({
    required BusinessContext context,
    required SaleCorrectionPolicy policy,
  }) async {
    if (policy.returnApprovalThresholdMinor case final threshold?
        when threshold < 0) {
      return const Result.failure(
        ValidationFailure('Return approval threshold cannot be negative.'),
      );
    }
    if (policy.voidWindowMinutes < 0) {
      return const Result.failure(
        ValidationFailure('Void window cannot be negative.'),
      );
    }
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final changed =
            await (database.update(database.branches)..where(
                  (row) =>
                      row.id.equals(context.branchId) &
                      row.organizationId.equals(context.organizationId),
                ))
                .write(
                  BranchesCompanion(
                    returnApprovalThresholdMinor: Value(
                      policy.returnApprovalThresholdMinor,
                    ),
                    voidWindowMinutes: Value(policy.voidWindowMinutes),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) {
          throw const AuthorizationFailure(
            'The active branch is not available locally.',
          );
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.update,
        entityName: 'branch_correction_policy',
        entityId: context.branchId,
        metadata: {
          'returnApprovalThresholdMinor': policy.returnApprovalThresholdMinor,
          'voidWindowMinutes': policy.voidWindowMinutes,
        },
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'branch.correction_policy.update',
        aggregateType: 'branch',
        aggregateId: context.branchId,
        payload: {
          'returnApprovalThresholdMinor': policy.returnApprovalThresholdMinor,
          'voidWindowMinutes': policy.voidWindowMinutes,
        },
        now: now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> configureDiscountPolicy({
    required BusinessContext context,
    required DiscountPolicy policy,
  }) async {
    final threshold = policy.approvalThresholdBasisPoints;
    if (threshold != null && (threshold < 0 || threshold > 10000)) {
      return const Result.failure(
        ValidationFailure('Discount approval threshold must be 0–100 percent.'),
      );
    }
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final changed =
            await (database.update(database.branches)..where(
                  (row) =>
                      row.id.equals(context.branchId) &
                      row.organizationId.equals(context.organizationId),
                ))
                .write(
                  BranchesCompanion(
                    discountApprovalThresholdBasisPoints: Value(threshold),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) {
          throw const AuthorizationFailure(
            'The active branch is not available locally.',
          );
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.update,
        entityName: 'branch_discount_policy',
        entityId: context.branchId,
        metadata: {'approvalThresholdBasisPoints': threshold},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        aggregateId: context.branchId,
        commandType: 'branch.discount_policy.update',
        aggregateType: 'branch',
        payload: {'approvalThresholdBasisPoints': threshold},
        now: now,
      ),
    );
  }

  @override
  Future<Result<CheckoutResult, Failure>> checkout({
    required BusinessContext context,
    required CheckoutDraft draft,
    String? discountApprovedByUserId,
  }) async {
    final operationId = draft.operationId ?? _idGenerator.newId();
    final existing = await _saleForOperation(context, operationId);
    if (existing != null) {
      return Result.success(
        CheckoutResult(
          saleId: existing.id,
          receiptNumber: existing.receiptNumber ?? 'Pending',
        ),
      );
    }
    late final CartPricing pricing;
    late final PaymentReconciliation reconciliation;
    try {
      final canonicalCart = await _canonicalCart(context, draft.cart);
      pricing = CartPricingCalculator.calculate(canonicalCart);
      reconciliation = PaymentCalculator.reconcile(
        totalMinor: pricing.totalMinor,
        tenders: draft.tenders,
      );
      _validateUniqueProducts(pricing);
    } on Failure catch (failure) {
      return Result.failure(failure);
    }
    final saleId = _idGenerator.newId();
    final inventoryTransactionId = _idGenerator.newId();
    final itemIds = [for (final _ in pricing.lines) _idGenerator.newId()];
    final now = _clock.nowUtc();
    final mutation = await _localMutationTransaction.execute(
      businessWrite: (database) async {
        final scope = await _resolveRegisterAndShift(
          database,
          context,
          draft.deviceId,
        );
        final branch = scope.branch;
        final threshold = branch.discountApprovalThresholdBasisPoints;
        if (threshold != null &&
            pricing.discountMinor * 10000 > pricing.subtotalMinor * threshold &&
            discountApprovedByUserId == null) {
          throw const AuthorizationFailure(
            'This discount exceeds the branch approval threshold.',
            code: 'sale-discount-approval-required',
          );
        }
        final receiptNumber = await _receiptAllocator.allocate(
          database: database,
          context: context,
          register: scope.register,
          branchCode: branch.code,
          now: now,
        );
        await _ledgerWriter.post(
          database: database,
          context: context,
          draft: InventoryMovementDraft(
            type: InventoryTransactionType.sale,
            referenceType: 'sale',
            referenceId: saleId,
            occurredAt: now,
            lines: [
              for (final priced in pricing.lines)
                InventoryMovementLineDraft(
                  stockLocationId: priced.line.product.stockLocationId,
                  productId: priced.line.product.id,
                  quantityDeltaMilli: -priced.line.quantityMilli,
                  expectedBalanceVersion: priced.line.product.inventoryVersion,
                ),
            ],
          ),
          transactionId: inventoryTransactionId,
          operationId: '$operationId:inventory',
          now: now,
        );
        await database
            .into(database.sales)
            .insert(
              SalesCompanion.insert(
                id: saleId,
                organizationId: context.organizationId,
                branchId: context.branchId,
                registerId: scope.register.id,
                shiftId: Value(scope.shift?.id),
                inventoryTransactionId: Value(inventoryTransactionId),
                operationId: operationId,
                receiptNumber: Value(receiptNumber),
                status: Value(SaleStatus.completed.databaseValue),
                cashierUserId: context.actorUserId,
                subtotalMinor: Value(pricing.subtotalMinor),
                discountMinor: Value(pricing.discountMinor),
                taxMinor: Value(pricing.taxMinor),
                totalMinor: Value(pricing.totalMinor),
                tenderedMinor: Value(reconciliation.tenderedMinor),
                changeMinor: Value(reconciliation.changeMinor),
                discountApprovedByUserId: Value(discountApprovedByUserId),
                discountApprovedAt: Value(
                  discountApprovedByUserId == null ? null : now,
                ),
                completedAt: Value(now),
                createdAt: now,
                updatedAt: now,
              ),
            );
        for (var index = 0; index < pricing.lines.length; index++) {
          final priced = pricing.lines[index];
          final product = priced.line.product;
          await database
              .into(database.saleItems)
              .insert(
                SaleItemsCompanion.insert(
                  id: itemIds[index],
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  saleId: saleId,
                  productId: product.id,
                  stockLocationId: product.stockLocationId,
                  lineNumber: index + 1,
                  productNameSnapshot: product.name,
                  skuSnapshot: product.sku,
                  barcodeSnapshot: Value(product.primaryBarcode),
                  unitNameSnapshot: product.unitName,
                  quantityMilli: priced.line.quantityMilli,
                  unitPriceMinorSnapshot: product.unitPriceMinor,
                  unitCostMinorSnapshot: product.unitCostMinor,
                  taxRateBasisPointsSnapshot: product.taxRateBasisPoints,
                  taxInclusiveSnapshot: product.taxInclusive,
                  grossAmountMinor: priced.grossAmountMinor,
                  discountAmountMinor: priced.discountAmountMinor,
                  netAmountMinor: priced.netAmountMinor,
                  taxAmountMinor: priced.taxAmountMinor,
                  totalAmountMinor: priced.totalAmountMinor,
                  createdAt: now,
                ),
              );
          if (priced.itemDiscountMinor > 0) {
            await _insertDiscount(
              database: database,
              context: context,
              saleId: saleId,
              saleItemId: itemIds[index],
              scope: 'item',
              amountMinor: priced.itemDiscountMinor,
              reason: priced.line.discountReason!,
              approvedByUserId: discountApprovedByUserId,
              now: now,
            );
          }
        }
        if (draft.cart.saleDiscountMinor > 0) {
          await _insertDiscount(
            database: database,
            context: context,
            saleId: saleId,
            scope: 'sale',
            amountMinor: draft.cart.saleDiscountMinor,
            reason: draft.cart.saleDiscountReason!,
            approvedByUserId: discountApprovedByUserId,
            now: now,
          );
        }
        for (final payment in reconciliation.payments) {
          await database
              .into(database.payments)
              .insert(
                PaymentsCompanion.insert(
                  id: _idGenerator.newId(),
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  saleId: saleId,
                  shiftId: Value(scope.shift?.id),
                  paymentMethod: payment.method.databaseValue,
                  tenderedAmountMinor: payment.tenderedAmountMinor,
                  appliedAmountMinor: payment.appliedAmountMinor,
                  changeAmountMinor: Value(payment.changeAmountMinor),
                  reference: Value(_trimmedOrNull(payment.reference)),
                  createdAt: now,
                ),
              );
        }
        return CheckoutResult(saleId: saleId, receiptNumber: receiptNumber);
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.sale,
        entityName: 'sale',
        entityId: saleId,
        metadata: {
          'subtotalMinor': pricing.subtotalMinor,
          'discountMinor': pricing.discountMinor,
          'taxMinor': pricing.taxMinor,
          'totalMinor': pricing.totalMinor,
          'changeMinor': reconciliation.changeMinor,
          'lineCount': pricing.lines.length,
          'discountApprovedByUserId': discountApprovedByUserId,
        },
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'sale.complete',
        aggregateType: 'sale',
        aggregateId: saleId,
        payload: _salePayload(
          saleId: saleId,
          inventoryTransactionId: inventoryTransactionId,
          pricing: pricing,
          reconciliation: reconciliation,
          deviceId: draft.deviceId,
          approvedByUserId: discountApprovedByUserId,
          saleDiscountReason: draft.cart.saleDiscountReason,
          now: now,
        ),
        now: now,
      ),
    );
    if (mutation.isFailure) {
      final concurrent = await _saleForOperation(context, operationId);
      if (concurrent != null) {
        return Result.success(
          CheckoutResult(
            saleId: concurrent.id,
            receiptNumber: concurrent.receiptNumber ?? 'Pending',
          ),
        );
      }
    }
    return mutation;
  }

  @override
  Future<Result<SaleCorrectionResult, Failure>> correctSale({
    required BusinessContext context,
    required SaleCorrectionDraft draft,
    String? approvedByUserId,
  }) async {
    final operationId = draft.operationId ?? _idGenerator.newId();
    final existing = await _correctionForOperation(context, operationId);
    if (existing != null) {
      return Result.success(
        SaleCorrectionResult(
          correctionId: existing.id,
          returnNumber: existing.returnNumber,
        ),
      );
    }
    if (draft.saleId.trim().isEmpty || draft.reasonCode.trim().isEmpty) {
      return const Result.failure(
        ValidationFailure('A sale and reason code are required.'),
      );
    }
    if (draft.lines.isEmpty) {
      return const Result.failure(
        ValidationFailure('Select at least one item to correct.'),
      );
    }

    final sale =
        await (_database.select(_database.sales)..where(
              (row) =>
                  row.id.equals(draft.saleId) &
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId),
            ))
            .getSingleOrNull();
    if (sale == null) {
      return const Result.failure(
        ValidationFailure('The sale is not available on this branch.'),
      );
    }
    if (sale.status != SaleStatus.completed.databaseValue) {
      return const Result.failure(
        ConflictFailure('Only completed sales can be returned or voided.'),
      );
    }
    final rejectedCorrection =
        await (_database.select(_database.saleReturns)
              ..where(
                (row) =>
                    row.saleId.equals(sale.id) &
                    row.status.equals('sync_rejected'),
              )
              ..limit(1))
            .getSingleOrNull();
    if (rejectedCorrection != null) {
      return const Result.failure(
        ConflictFailure(
          'Resolve the rejected correction before creating another return or void.',
        ),
      );
    }
    final latestCorrection =
        await (_database.select(_database.saleReturns)
              ..where((row) => row.saleId.equals(sale.id))
              ..orderBy([(row) => OrderingTerm.desc(row.completedAt)])
              ..limit(1))
            .getSingleOrNull();
    final dependencyOperationId =
        latestCorrection?.operationId ?? sale.operationId;
    final saleItems =
        await (_database.select(_database.saleItems)
              ..where((row) => row.saleId.equals(sale.id))
              ..orderBy([(row) => OrderingTerm.asc(row.lineNumber)]))
            .get();
    final prior = await _priorCorrections(sale.id);
    late final List<_CorrectionLine> lines;
    try {
      lines = await _validateCorrectionLines(
        context: context,
        type: draft.type,
        drafts: draft.lines,
        saleItems: saleItems,
        prior: prior,
      );
    } on Failure catch (failure) {
      return Result.failure(failure);
    }
    final subtotalMinor = lines.fold<int>(
      0,
      (total, line) => total + line.subtotalMinor,
    );
    final discountMinor = lines.fold<int>(
      0,
      (total, line) => total + line.discountMinor,
    );
    final taxMinor = lines.fold<int>(0, (total, line) => total + line.taxMinor);
    final totalMinor = lines.fold<int>(
      0,
      (total, line) => total + line.totalMinor,
    );
    if (totalMinor <= 0) {
      return const Result.failure(
        ValidationFailure('The selected items have no refundable value.'),
      );
    }
    final refundMethods = <RefundMethod>{};
    var refundTotal = 0;
    for (final refund in draft.refunds) {
      if (!refundMethods.add(refund.method)) {
        return const Result.failure(
          ValidationFailure('Use each refund method only once.'),
        );
      }
      if (refund.amountMinor <= 0) {
        return const Result.failure(
          ValidationFailure('Refund amounts must be greater than zero.'),
        );
      }
      refundTotal += refund.amountMinor;
    }
    if (refundTotal != totalMinor) {
      return Result.failure(
        ValidationFailure(
          'Refund payments must equal the correction total of $totalMinor minor units.',
        ),
      );
    }

    final branch = await _findBranch(_database, context);
    if (branch == null) {
      return const Result.failure(
        AuthorizationFailure('The active branch is not available locally.'),
      );
    }
    final now = _clock.nowUtc();
    final exceedsReturnThreshold =
        branch.returnApprovalThresholdMinor != null &&
        totalMinor > branch.returnApprovalThresholdMinor!;
    final completedAt = sale.completedAt ?? sale.createdAt;
    final outsideVoidWindow =
        draft.type == SaleCorrectionType.voidSale &&
        now.difference(completedAt).inMinutes > branch.voidWindowMinutes;
    final requiresApproval = exceedsReturnThreshold || outsideVoidWindow;
    if (requiresApproval && approvedByUserId == null) {
      return Result.failure(
        AuthorizationFailure(
          outsideVoidWindow
              ? 'The void window has elapsed. Manager approval is required.'
              : 'This return exceeds the branch approval threshold.',
          code: 'sale-correction-approval-required',
        ),
      );
    }

    _CheckoutScope? cashScope;
    if (refundMethods.contains(RefundMethod.cash)) {
      try {
        cashScope = await _resolveRegisterAndShift(
          _database,
          context,
          draft.deviceId,
        );
      } on Failure catch (failure) {
        return Result.failure(failure);
      }
      if (cashScope.shift == null) {
        return const Result.failure(
          AuthorizationFailure(
            'Open a shift on this register before issuing a cash refund.',
            code: 'cash-refund-open-shift-required',
          ),
        );
      }
    }

    final correctionId = _idGenerator.newId();
    final inventoryTransactionId =
        lines.any((line) => line.disposition.changesInventory)
        ? _idGenerator.newId()
        : null;
    final approvalRequestId = requiresApproval ? _idGenerator.newId() : null;
    final itemIds = [for (final _ in lines) _idGenerator.newId()];
    final refundIds = [for (final _ in draft.refunds) _idGenerator.newId()];
    final cashMovementId = refundMethods.contains(RefundMethod.cash)
        ? _idGenerator.newId()
        : null;
    final prefix = draft.type == SaleCorrectionType.voidSale ? 'VOID' : 'RET';
    final receipt = sale.receiptNumber ?? sale.id;
    final suffix = correctionId.replaceAll('-', '').toUpperCase();
    final returnNumber = '$prefix-$receipt-$suffix';

    final mutation = await _localMutationTransaction.execute(
      businessWrite: (database) async {
        final rejectedCorrection =
            await (database.select(database.saleReturns)
                  ..where(
                    (row) =>
                        row.saleId.equals(sale.id) &
                        row.status.equals('sync_rejected'),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (rejectedCorrection != null) {
          throw const ConflictFailure(
            'Resolve the rejected correction before creating another return or void.',
          );
        }
        final currentPrior = await _priorCorrections(
          sale.id,
          database: database,
        );
        for (final line in lines) {
          final returned = currentPrior[line.saleItem.id]?.quantityMilli ?? 0;
          if (returned + line.quantityMilli > line.saleItem.quantityMilli) {
            throw const ConflictFailure(
              'Another correction changed the returnable quantity. Refresh and retry.',
            );
          }
        }
        if (draft.type == SaleCorrectionType.voidSale &&
            currentPrior.values.any((value) => value.quantityMilli > 0)) {
          throw const ConflictFailure(
            'A sale with an existing return can no longer be voided.',
          );
        }

        if (approvalRequestId != null) {
          await database
              .into(database.approvalRequests)
              .insert(
                ApprovalRequestsCompanion.insert(
                  id: approvalRequestId,
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  operationId: '$operationId:approval',
                  requestType: draft.type == SaleCorrectionType.voidSale
                      ? 'sale_void'
                      : 'sale_return',
                  entityType: 'sale',
                  entityId: sale.id,
                  status: const Value('approved'),
                  requestedByUserId: context.actorUserId,
                  reason: draft.reasonCode.trim(),
                  thresholdMinor: Value(branch.returnApprovalThresholdMinor),
                  actualAmountMinor: totalMinor,
                  requestedAt: now,
                  resolvedAt: Value(now),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          await database
              .into(database.approvalDecisions)
              .insert(
                ApprovalDecisionsCompanion.insert(
                  id: _idGenerator.newId(),
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  approvalRequestId: approvalRequestId,
                  decision: 'approved',
                  decidedByUserId: approvedByUserId!,
                  notes: Value(_trimmedOrNull(draft.notes)),
                  decidedAt: now,
                  createdAt: now,
                ),
              );
        }

        if (inventoryTransactionId != null) {
          await _ledgerWriter.post(
            database: database,
            context: context,
            draft: InventoryMovementDraft(
              type: InventoryTransactionType.saleReturn,
              reasonCode: draft.reasonCode,
              notes: draft.notes,
              referenceType: 'sale_correction',
              referenceId: correctionId,
              occurredAt: now,
              approvedByUserId: approvedByUserId,
              lines: [
                for (final line in lines)
                  if (line.disposition.changesInventory)
                    InventoryMovementLineDraft(
                      stockLocationId: line.destinationStockLocationId!,
                      productId: line.saleItem.productId,
                      quantityDeltaMilli: line.quantityMilli,
                    ),
              ],
            ),
            transactionId: inventoryTransactionId,
            operationId: '$operationId:inventory',
            now: now,
            allowInactiveProducts: true,
          );
        }

        final cashRefund = draft.refunds
            .where((refund) => refund.method == RefundMethod.cash)
            .firstOrNull;
        if (cashRefund != null) {
          await database
              .into(database.cashMovements)
              .insert(
                CashMovementsCompanion.insert(
                  id: cashMovementId!,
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  registerId: cashScope!.register.id,
                  shiftId: cashScope.shift!.id,
                  operationId: '$operationId:cash_refund',
                  movementType: 'cash_out',
                  amountMinor: -cashRefund.amountMinor,
                  reason: 'Refund $returnNumber: ${draft.reasonCode.trim()}',
                  createdByUserId: context.actorUserId,
                  approvedByUserId: Value(approvedByUserId),
                  approvedAt: Value(approvedByUserId == null ? null : now),
                  occurredAt: now,
                  createdAt: now,
                ),
              );
        }

        await database
            .into(database.saleReturns)
            .insert(
              SaleReturnsCompanion.insert(
                id: correctionId,
                organizationId: context.organizationId,
                branchId: context.branchId,
                saleId: sale.id,
                operationId: operationId,
                returnNumber: returnNumber,
                correctionType: draft.type.databaseValue,
                reasonCode: draft.reasonCode.trim(),
                notes: Value(_trimmedOrNull(draft.notes)),
                inventoryTransactionId: Value(inventoryTransactionId),
                approvalRequestId: Value(approvalRequestId),
                subtotalMinor: subtotalMinor,
                discountMinor: discountMinor,
                taxMinor: taxMinor,
                totalMinor: totalMinor,
                createdByUserId: context.actorUserId,
                approvedByUserId: Value(
                  requiresApproval ? approvedByUserId : null,
                ),
                approvedAt: Value(requiresApproval ? now : null),
                completedAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
        for (var index = 0; index < lines.length; index++) {
          final line = lines[index];
          await database
              .into(database.saleReturnItems)
              .insert(
                SaleReturnItemsCompanion.insert(
                  id: itemIds[index],
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  saleReturnId: correctionId,
                  saleItemId: line.saleItem.id,
                  productId: line.saleItem.productId,
                  disposition: line.disposition.databaseValue,
                  destinationStockLocationId: Value(
                    line.destinationStockLocationId,
                  ),
                  quantityMilli: line.quantityMilli,
                  subtotalMinor: line.subtotalMinor,
                  discountMinor: line.discountMinor,
                  taxMinor: line.taxMinor,
                  totalMinor: line.totalMinor,
                  createdAt: now,
                ),
              );
        }
        for (var index = 0; index < draft.refunds.length; index++) {
          final refund = draft.refunds[index];
          await database
              .into(database.refundPayments)
              .insert(
                RefundPaymentsCompanion.insert(
                  id: refundIds[index],
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  saleReturnId: correctionId,
                  shiftId: Value(
                    refund.method == RefundMethod.cash
                        ? cashScope!.shift!.id
                        : null,
                  ),
                  cashMovementId: Value(
                    refund.method == RefundMethod.cash ? cashMovementId : null,
                  ),
                  refundMethod: refund.method.databaseValue,
                  amountMinor: refund.amountMinor,
                  reference: Value(_trimmedOrNull(refund.reference)),
                  createdAt: now,
                ),
              );
        }
        return SaleCorrectionResult(
          correctionId: correctionId,
          returnNumber: returnNumber,
        );
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.sale,
        entityName: 'sale_correction',
        entityId: correctionId,
        metadata: {
          'saleId': sale.id,
          'correctionType': draft.type.databaseValue,
          'reasonCode': draft.reasonCode.trim(),
          'totalMinor': totalMinor,
          'lineCount': lines.length,
          'approvedByUserId': requiresApproval ? approvedByUserId : null,
        },
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: draft.type == SaleCorrectionType.voidSale
            ? 'sale.void'
            : 'sale.return',
        aggregateType: 'sale_correction',
        aggregateId: correctionId,
        dependsOnOperationId: dependencyOperationId,
        payload: {
          'id': correctionId,
          'saleId': sale.id,
          'returnNumber': returnNumber,
          'correctionType': draft.type.databaseValue,
          'reasonCode': draft.reasonCode.trim(),
          'notes': _trimmedOrNull(draft.notes),
          'deviceId': draft.deviceId.trim(),
          'completedAt': now.toIso8601String(),
          'inventoryTransactionId': inventoryTransactionId,
          'approvalRequestId': approvalRequestId,
          'approvedByUserId': requiresApproval ? approvedByUserId : null,
          'subtotalMinor': subtotalMinor,
          'discountMinor': discountMinor,
          'taxMinor': taxMinor,
          'totalMinor': totalMinor,
          'items': [
            for (final line in lines)
              {
                'lineNumber': line.saleItem.lineNumber,
                'productId': line.saleItem.productId,
                'quantityMilli': line.quantityMilli,
                'disposition': line.disposition.databaseValue,
                'destinationStockLocationId': line.destinationStockLocationId,
                'subtotalMinor': line.subtotalMinor,
                'discountMinor': line.discountMinor,
                'taxMinor': line.taxMinor,
                'totalMinor': line.totalMinor,
              },
          ],
          'refunds': [
            for (final refund in draft.refunds)
              {
                'method': refund.method.databaseValue,
                'amountMinor': refund.amountMinor,
                'reference': _trimmedOrNull(refund.reference),
              },
          ],
        },
        now: now,
      ),
    );
    if (mutation.isFailure) {
      final concurrent = await _correctionForOperation(context, operationId);
      if (concurrent != null) {
        return Result.success(
          SaleCorrectionResult(
            correctionId: concurrent.id,
            returnNumber: concurrent.returnNumber,
          ),
        );
      }
    }
    return mutation;
  }

  Future<Cart> _canonicalCart(BusinessContext context, Cart cart) async {
    final lines = <CartLine>[];
    for (final line in cart.lines) {
      final product = await _localDataSource.getSaleProduct(
        organizationId: context.organizationId,
        branchId: context.branchId,
        productId: line.product.id,
        now: _clock.nowUtc(),
      );
      if (product == null || product.unitPriceMinor <= 0) {
        throw ValidationFailure(
          '${line.product.name} is no longer configured for sale on this branch.',
        );
      }
      lines.add(
        CartLine(
          product: product,
          quantityMilli: line.quantityMilli,
          itemDiscountMinor: line.itemDiscountMinor,
          discountReason: line.discountReason,
        ),
      );
    }
    return Cart(
      lines: lines,
      saleDiscountMinor: cart.saleDiscountMinor,
      saleDiscountReason: cart.saleDiscountReason,
    );
  }

  Future<db.SaleReturn?> _correctionForOperation(
    BusinessContext context,
    String operationId,
  ) {
    return (_database.select(_database.saleReturns)..where(
          (row) =>
              row.organizationId.equals(context.organizationId) &
              row.operationId.equals(operationId),
        ))
        .getSingleOrNull();
  }

  Future<Map<String, _PriorCorrection>> _priorCorrections(
    String saleId, {
    AppDatabase? database,
  }) async {
    final db = database ?? _database;
    final rows = await db
        .customSelect(
          '''
SELECT
  sri.sale_item_id,
  COALESCE(SUM(sri.quantity_milli), 0) AS quantity_milli,
  COALESCE(SUM(sri.subtotal_minor), 0) AS subtotal_minor,
  COALESCE(SUM(sri.discount_minor), 0) AS discount_minor,
  COALESCE(SUM(sri.tax_minor), 0) AS tax_minor,
  COALESCE(SUM(sri.total_minor), 0) AS total_minor
FROM sale_return_items sri
JOIN sale_returns sr ON sr.id = sri.sale_return_id
WHERE sr.sale_id = ? AND sr.status = 'completed'
GROUP BY sri.sale_item_id
''',
          variables: [Variable<String>(saleId)],
          readsFrom: {db.saleReturns, db.saleReturnItems},
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('sale_item_id'): _PriorCorrection(
          quantityMilli: row.read<int>('quantity_milli'),
          subtotalMinor: row.read<int>('subtotal_minor'),
          discountMinor: row.read<int>('discount_minor'),
          taxMinor: row.read<int>('tax_minor'),
          totalMinor: row.read<int>('total_minor'),
        ),
    };
  }

  Future<List<_CorrectionLine>> _validateCorrectionLines({
    required BusinessContext context,
    required SaleCorrectionType type,
    required List<SaleCorrectionLineDraft> drafts,
    required List<db.SaleItem> saleItems,
    required Map<String, _PriorCorrection> prior,
  }) async {
    final byId = {for (final item in saleItems) item.id: item};
    final seen = <String>{};
    if (type == SaleCorrectionType.voidSale &&
        prior.values.any((value) => value.quantityMilli > 0)) {
      throw const ConflictFailure(
        'A sale with an existing return can no longer be voided.',
      );
    }
    if (type == SaleCorrectionType.voidSale &&
        drafts.length != saleItems.length) {
      throw const ValidationFailure('A void must reverse every sale item.');
    }
    final result = <_CorrectionLine>[];
    for (final draft in drafts) {
      if (!seen.add(draft.saleItemId)) {
        throw const ValidationFailure(
          'Each sale item may appear only once in a correction.',
        );
      }
      final item = byId[draft.saleItemId];
      if (item == null) {
        throw const AuthorizationFailure(
          'A correction item is outside the selected sale.',
          code: 'cross-sale-return-item',
        );
      }
      final priorItem = prior[item.id] ?? const _PriorCorrection();
      final remaining = item.quantityMilli - priorItem.quantityMilli;
      if (draft.quantityMilli <= 0 || draft.quantityMilli > remaining) {
        throw ValidationFailure(
          '${item.productNameSnapshot} has only $remaining milli-units returnable.',
        );
      }
      if (type == SaleCorrectionType.voidSale &&
          draft.quantityMilli != item.quantityMilli) {
        throw const ValidationFailure('A void must reverse every sale item.');
      }

      String? destinationId;
      if (draft.disposition.changesInventory) {
        destinationId = draft.destinationStockLocationId?.trim();
        if ((destinationId ?? '').isEmpty &&
            draft.disposition == ReturnDisposition.restock) {
          destinationId = item.stockLocationId;
        }
        if ((destinationId ?? '').isEmpty) {
          throw ValidationFailure(
            'Choose a ${draft.disposition.label.toLowerCase()} destination for ${item.productNameSnapshot}.',
          );
        }
        final location =
            await (_database.select(_database.stockLocations)..where(
                  (row) =>
                      row.id.equals(destinationId!) &
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.isActive.equals(true) &
                      row.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (location == null) {
          throw const AuthorizationFailure(
            'A return destination is outside the active branch.',
            code: 'cross-scope-return-destination',
          );
        }
        if (draft.disposition == ReturnDisposition.damaged &&
            location.locationType != 'damaged') {
          throw const ValidationFailure(
            'Damaged merchandise must enter a damaged stock location.',
          );
        }
        if (draft.disposition == ReturnDisposition.restock &&
            location.locationType == 'damaged') {
          throw const ValidationFailure(
            'Restock merchandise cannot enter a damaged stock location.',
          );
        }
      } else if (draft.destinationStockLocationId != null) {
        throw const ValidationFailure(
          'Non-restock items cannot have a stock destination.',
        );
      }

      final isFinal = draft.quantityMilli == remaining;
      result.add(
        _CorrectionLine(
          saleItem: item,
          quantityMilli: draft.quantityMilli,
          disposition: draft.disposition,
          destinationStockLocationId: destinationId,
          subtotalMinor: _proratedAmount(
            original: item.grossAmountMinor,
            prior: priorItem.subtotalMinor,
            soldQuantity: item.quantityMilli,
            quantity: draft.quantityMilli,
            isFinal: isFinal,
          ),
          discountMinor: _proratedAmount(
            original: item.discountAmountMinor,
            prior: priorItem.discountMinor,
            soldQuantity: item.quantityMilli,
            quantity: draft.quantityMilli,
            isFinal: isFinal,
          ),
          taxMinor: _proratedAmount(
            original: item.taxAmountMinor,
            prior: priorItem.taxMinor,
            soldQuantity: item.quantityMilli,
            quantity: draft.quantityMilli,
            isFinal: isFinal,
          ),
          totalMinor: _proratedAmount(
            original: item.totalAmountMinor,
            prior: priorItem.totalMinor,
            soldQuantity: item.quantityMilli,
            quantity: draft.quantityMilli,
            isFinal: isFinal,
          ),
        ),
      );
    }
    return result;
  }

  Future<_CheckoutScope> _resolveRegisterAndShift(
    AppDatabase database,
    BusinessContext context,
    String deviceId,
  ) async {
    final normalizedDeviceId = deviceId.trim();
    final register =
        await (database.select(database.registers)..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId) &
                  row.assignedDeviceId.equals(normalizedDeviceId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (register == null) {
      throw const AuthorizationFailure(
        'Assign this device to an active register before checkout.',
        code: 'register-device-mismatch',
      );
    }
    final branch = await _findBranch(database, context);
    if (branch == null) {
      throw const AuthorizationFailure(
        'The active branch is not available locally.',
      );
    }
    final shift =
        await (database.select(database.shifts)..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId) &
                  row.registerId.equals(register.id) &
                  row.deviceId.equals(normalizedDeviceId) &
                  row.status.equals('open'),
            ))
            .getSingleOrNull();
    if (shift == null && !branch.allowSalesWithoutOpenShift) {
      throw const AuthorizationFailure(
        'Open a shift on this register before checkout.',
        code: 'open-shift-required',
      );
    }
    if (shift != null && shift.openedByUserId != context.actorUserId) {
      throw const AuthorizationFailure(
        'This register has a shift opened by another user.',
        code: 'shift-owner-mismatch',
      );
    }
    return _CheckoutScope(branch: branch, register: register, shift: shift);
  }

  Future<void> _insertDiscount({
    required AppDatabase database,
    required BusinessContext context,
    required String saleId,
    required String scope,
    required int amountMinor,
    required String reason,
    required DateTime now,
    String? saleItemId,
    String? approvedByUserId,
  }) async {
    await database
        .into(database.saleDiscounts)
        .insert(
          SaleDiscountsCompanion.insert(
            id: _idGenerator.newId(),
            organizationId: context.organizationId,
            branchId: context.branchId,
            saleId: saleId,
            saleItemId: Value(saleItemId),
            discountScope: scope,
            amountMinor: amountMinor,
            reason: reason.trim(),
            approvedByUserId: Value(approvedByUserId),
            approvedAt: Value(approvedByUserId == null ? null : now),
            createdAt: now,
          ),
        );
  }

  Future<db.Sale?> _saleForOperation(
    BusinessContext context,
    String operationId,
  ) {
    return (_database.select(_database.sales)..where(
          (row) =>
              row.organizationId.equals(context.organizationId) &
              row.operationId.equals(operationId),
        ))
        .getSingleOrNull();
  }

  void _validateUniqueProducts(CartPricing pricing) {
    final keys = <String>{};
    for (final priced in pricing.lines) {
      final product = priced.line.product;
      if (!keys.add('${product.stockLocationId}:${product.id}')) {
        throw const ValidationFailure(
          'Combine duplicate products into one cart line.',
        );
      }
    }
  }

  AuditLogEntry _audit({
    required BusinessContext context,
    required String operationId,
    required AuditActionType action,
    required String entityName,
    required String entityId,
    required Map<String, Object?> metadata,
    required DateTime now,
  }) {
    return AuditLogEntry(
      id: _idGenerator.newId(),
      operationId: operationId,
      organizationId: context.organizationId,
      actorUserId: context.actorUserId,
      branchId: context.branchId,
      actionType: action,
      entityName: entityName,
      entityId: entityId,
      metadata: metadata,
      createdAt: now,
    );
  }

  OutboxCommand _outbox({
    required BusinessContext context,
    required String operationId,
    required String commandType,
    required String aggregateType,
    required String aggregateId,
    required Map<String, Object?> payload,
    required DateTime now,
    String? dependsOnOperationId,
  }) {
    return OutboxCommand(
      operationId: operationId,
      organizationId: context.organizationId,
      branchId: context.branchId,
      actorUserId: context.actorUserId,
      commandType: commandType,
      aggregateType: aggregateType,
      aggregateId: aggregateId,
      dependsOnOperationId: dependsOnOperationId,
      payload: payload,
      createdAt: now,
    );
  }

  Map<String, Object?> _salePayload({
    required String saleId,
    required String inventoryTransactionId,
    required CartPricing pricing,
    required PaymentReconciliation reconciliation,
    required String deviceId,
    required DateTime now,
    String? approvedByUserId,
    String? saleDiscountReason,
  }) {
    return {
      'id': saleId,
      'inventoryTransactionId': inventoryTransactionId,
      'deviceId': deviceId,
      'completedAt': now.toIso8601String(),
      'subtotalMinor': pricing.subtotalMinor,
      'discountMinor': pricing.discountMinor,
      'taxMinor': pricing.taxMinor,
      'totalMinor': pricing.totalMinor,
      'tenderedMinor': reconciliation.tenderedMinor,
      'changeMinor': reconciliation.changeMinor,
      'discountApprovedByUserId': approvedByUserId,
      'saleDiscountReason': saleDiscountReason,
      'items': [
        for (final priced in pricing.lines)
          {
            'productId': priced.line.product.id,
            'stockLocationId': priced.line.product.stockLocationId,
            'quantityMilli': priced.line.quantityMilli,
            'unitPriceMinor': priced.line.product.unitPriceMinor,
            'unitCostMinor': priced.line.product.unitCostMinor,
            'taxRateBasisPoints': priced.line.product.taxRateBasisPoints,
            'taxInclusive': priced.line.product.taxInclusive,
            'productName': priced.line.product.name,
            'sku': priced.line.product.sku,
            'barcode': priced.line.product.primaryBarcode,
            'unitName': priced.line.product.unitName,
            'grossAmountMinor': priced.grossAmountMinor,
            'discountAmountMinor': priced.discountAmountMinor,
            'itemDiscountMinor': priced.itemDiscountMinor,
            'allocatedSaleDiscountMinor': priced.allocatedSaleDiscountMinor,
            'itemDiscountReason': priced.line.discountReason,
            'netAmountMinor': priced.netAmountMinor,
            'taxAmountMinor': priced.taxAmountMinor,
            'totalAmountMinor': priced.totalAmountMinor,
          },
      ],
      'payments': [
        for (final payment in reconciliation.payments)
          {
            'method': payment.method.databaseValue,
            'tenderedAmountMinor': payment.tenderedAmountMinor,
            'appliedAmountMinor': payment.appliedAmountMinor,
            'changeAmountMinor': payment.changeAmountMinor,
            'reference': payment.reference,
          },
      ],
    };
  }
}

Future<db.Branche?> _findBranch(AppDatabase database, BusinessContext context) {
  return (database.select(database.branches)..where(
        (row) =>
            row.id.equals(context.branchId) &
            row.organizationId.equals(context.organizationId) &
            row.deletedAt.isNull(),
      ))
      .getSingleOrNull();
}

class _CheckoutScope {
  const _CheckoutScope({
    required this.branch,
    required this.register,
    required this.shift,
  });

  final db.Branche branch;
  final db.Register register;
  final db.Shift? shift;
}

class _PriorCorrection {
  const _PriorCorrection({
    this.quantityMilli = 0,
    this.subtotalMinor = 0,
    this.discountMinor = 0,
    this.taxMinor = 0,
    this.totalMinor = 0,
  });

  final int quantityMilli;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
}

class _CorrectionLine {
  const _CorrectionLine({
    required this.saleItem,
    required this.quantityMilli,
    required this.disposition,
    required this.destinationStockLocationId,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
  });

  final db.SaleItem saleItem;
  final int quantityMilli;
  final ReturnDisposition disposition;
  final String? destinationStockLocationId;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
}

int _proratedAmount({
  required int original,
  required int prior,
  required int soldQuantity,
  required int quantity,
  required bool isFinal,
}) {
  if (isFinal) return original - prior;
  return (original * quantity + soldQuantity ~/ 2) ~/ soldQuantity;
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
