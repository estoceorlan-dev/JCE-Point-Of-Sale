import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/register_hardware_profile.dart';
import '../../domain/services/cash_drawer.dart';
import 'esc_pos_encoder.dart';
import 'network_esc_pos_transport.dart';

class NetworkEscPosCashDrawer implements CashDrawer {
  const NetworkEscPosCashDrawer();

  @override
  Future<Result<void, Failure>> open({
    required RegisterHardwareProfile profile,
  }) async {
    final address = profile.printerAddress?.trim();
    if (!profile.cashDrawerEnabled ||
        profile.printerType != ReceiptPrinterType.networkEscPos ||
        address == null ||
        address.isEmpty) {
      return const Result.failure(
        ValidationFailure('A printer-connected cash drawer is not configured.'),
      );
    }
    try {
      await sendNetworkEscPosBytes(
        address: address,
        port: profile.printerPort,
        bytes: EscPosEncoder.drawerPulse(profile.cashDrawerPin),
      );
      return const Result.success(null);
    } catch (error, stackTrace) {
      return Result.failure(
        NetworkFailure(
          'The cash drawer did not respond.',
          code: 'cash-drawer-unavailable',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
