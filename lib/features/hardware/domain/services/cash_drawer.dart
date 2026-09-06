import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/register_hardware_profile.dart';

abstract interface class CashDrawer {
  Future<Result<void, Failure>> open({
    required RegisterHardwareProfile profile,
  });
}
