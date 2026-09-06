import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';

abstract interface class CsvFileService {
  Future<Result<String?, Failure>> open();
  Future<Result<String?, Failure>> saveTemplate(String name, String content);
}
