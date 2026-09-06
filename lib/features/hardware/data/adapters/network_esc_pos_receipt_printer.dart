import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/register_hardware_profile.dart';
import '../../domain/services/receipt_printer.dart';
import 'esc_pos_encoder.dart';
import 'network_esc_pos_transport.dart';

class NetworkEscPosReceiptPrinter implements ReceiptPrinter {
  const NetworkEscPosReceiptPrinter();

  @override
  Future<Result<void, Failure>> print({
    required String documentText,
    required RegisterHardwareProfile profile,
  }) async {
    final address = profile.printerAddress?.trim();
    if (profile.printerType != ReceiptPrinterType.networkEscPos ||
        address == null ||
        address.isEmpty) {
      return const Result.failure(
        ValidationFailure('A network ESC/POS printer is not configured.'),
      );
    }
    try {
      await sendNetworkEscPosBytes(
        address: address,
        port: profile.printerPort,
        bytes: EscPosEncoder.receipt(documentText),
      );
      return const Result.success(null);
    } catch (error, stackTrace) {
      return Result.failure(
        NetworkFailure(
          'The receipt printer did not accept the print job.',
          code: 'printer-unavailable',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
