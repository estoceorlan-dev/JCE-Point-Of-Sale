import '../../../../shared/models/business_context.dart';

abstract interface class ImageUploadProcessor {
  Future<int> processPending(BusinessContext context);
}
