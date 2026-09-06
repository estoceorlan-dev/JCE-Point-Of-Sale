import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/register_hardware_profile.dart';

abstract interface class ReceiptPrinter {
  Future<Result<void, Failure>> print({
    required String documentText,
    required RegisterHardwareProfile profile,
  });
}
