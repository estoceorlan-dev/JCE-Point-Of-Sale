// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

Future<String> saveReceiptPdf(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    html.AnchorElement(href: url)
      ..download = fileName
      ..click();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
  return fileName;
}
