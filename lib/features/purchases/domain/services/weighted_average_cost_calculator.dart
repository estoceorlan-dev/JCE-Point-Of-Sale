import '../../../../core/error/failures.dart';

class WeightedAverageCostCalculator {
  const WeightedAverageCostCalculator();

  int landedUnitCostMinor({
    required int quantityMilli,
    required int unitCostMinor,
    required int freightCostMinor,
    required int dutyCostMinor,
    required int otherLandedCostMinor,
  }) {
    if (quantityMilli <= 0 ||
        unitCostMinor < 0 ||
        freightCostMinor < 0 ||
        dutyCostMinor < 0 ||
        otherLandedCostMinor < 0) {
      throw const ValidationFailure(
        'Receipt quantities must be positive and costs cannot be negative.',
      );
    }
    final baseCostMinor = _roundDivide(quantityMilli * unitCostMinor, 1000);
    final totalCostMinor =
        baseCostMinor + freightCostMinor + dutyCostMinor + otherLandedCostMinor;
    return _roundDivide(totalCostMinor * 1000, quantityMilli);
  }

  int weightedAverageCostMinor({
    required int currentQuantityMilli,
    required int currentAverageCostMinor,
    required int receivedQuantityMilli,
    required int receivedLandedUnitCostMinor,
  }) {
    if (currentAverageCostMinor < 0 ||
        receivedQuantityMilli <= 0 ||
        receivedLandedUnitCostMinor < 0) {
      throw const ValidationFailure(
        'Weighted-average cost inputs are invalid.',
      );
    }
    if (currentQuantityMilli <= 0) return receivedLandedUnitCostMinor;
    final combinedQuantity = currentQuantityMilli + receivedQuantityMilli;
    return _roundDivide(
      currentQuantityMilli * currentAverageCostMinor +
          receivedQuantityMilli * receivedLandedUnitCostMinor,
      combinedQuantity,
    );
  }

  int _roundDivide(int numerator, int denominator) =>
      (numerator + denominator ~/ 2) ~/ denominator;
}
