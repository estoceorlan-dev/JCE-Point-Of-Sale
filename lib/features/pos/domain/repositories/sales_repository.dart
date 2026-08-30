import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/sale.dart';
import '../entities/sale_product.dart';
import '../entities/sale_correction.dart';

abstract interface class SalesRepository {
  Stream<List<SaleProduct>> watchSaleProducts({
    required BusinessContext context,
    required String search,
  });

  Stream<List<SaleRecord>> watchRecentSales({required BusinessContext context});

  Future<SaleRecord?> getSale({
    required BusinessContext context,
    required String saleId,
  });

  Future<DiscountPolicy?> getDiscountPolicy({required BusinessContext context});

  Future<Result<void, Failure>> configureDiscountPolicy({
    required BusinessContext context,
    required DiscountPolicy policy,
  });

  Future<Result<CheckoutResult, Failure>> checkout({
    required BusinessContext context,
    required CheckoutDraft draft,
    String? discountApprovedByUserId,
  });

  Future<List<ReturnDestination>> getReturnDestinations({
    required BusinessContext context,
  });

  Future<SaleCorrectionPolicy?> getCorrectionPolicy({
    required BusinessContext context,
  });

  Future<Result<void, Failure>> configureCorrectionPolicy({
    required BusinessContext context,
    required SaleCorrectionPolicy policy,
  });

  Future<Result<SaleCorrectionResult, Failure>> correctSale({
    required BusinessContext context,
    required SaleCorrectionDraft draft,
    String? approvedByUserId,
  });
}
