import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<String> saveReceiptPdf(Uint8List bytes, String fileName) async {
  final directory =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final file = File(path.join(directory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
