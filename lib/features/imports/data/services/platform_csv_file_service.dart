import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/services/csv_file_service.dart';

class PlatformCsvFileService implements CsvFileService {
  const PlatformCsvFileService();
  @override
  Future<Result<String?, Failure>> open() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'CSV',
            extensions: ['csv'],
            mimeTypes: ['text/csv', 'text/plain'],
            uniformTypeIdentifiers: ['public.comma-separated-values-text'],
          ),
        ],
      );
      if (file == null) return const Result.success(null);
      if (await file.length() > 5 * 1024 * 1024) {
        return const Result.failure(
          ValidationFailure('Choose a CSV file smaller than 5 MB.'),
        );
      }
      return Result.success(
        utf8.decode(await file.readAsBytes(), allowMalformed: false),
      );
    } on FormatException {
      return const Result.failure(
        ValidationFailure('Save the file with UTF-8 encoding and try again.'),
      );
    } catch (error, stack) {
      return Result.failure(FailureMapper.fromException(error, stack));
    }
  }

  @override
  Future<Result<String?, Failure>> saveTemplate(
    String name,
    String content,
  ) async {
    try {
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(content)),
        name: name,
        mimeType: 'text/csv',
      );
      String destination;
      if (kIsWeb) {
        destination = name;
      } else if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        destination = path.join(
          (await getApplicationDocumentsDirectory()).path,
          name,
        );
      } else {
        final selected = await getSaveLocation(suggestedName: name);
        if (selected == null) return const Result.success(null);
        destination = selected.path;
      }
      await file.saveTo(destination);
      return Result.success(destination);
    } catch (error, stack) {
      return Result.failure(FailureMapper.fromException(error, stack));
    }
  }
}
