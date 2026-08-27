import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readProductImageBytes(String path) {
  return File(path).readAsBytes();
}
