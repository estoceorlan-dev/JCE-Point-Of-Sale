import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/register.dart';

enum RegisterAction { edit, archive, restore, unassignDevice }

abstract interface class RegisterAdministrationRepository {
  Stream<List<Register>> watchAll(BusinessContext context);

  Future<Result<void, Failure>> mutate({
    required BusinessContext context,
    required Register register,
    required RegisterAction action,
    RegisterDraft? draft,
  });
}
