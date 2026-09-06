import 'dart:convert';
import 'dart:typed_data';

abstract final class ReceiptPdfGenerator {
  static Uint8List generate(String receiptText) {
    final lines = receiptText
        .replaceAll('₱', 'PHP ')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('…', '...')
        .split('\n');
    const linesPerPage = 58;
    final pages = <List<String>>[];
    for (var index = 0; index < lines.length; index += linesPerPage) {
      pages.add(
        lines.sublist(index, (index + linesPerPage).clamp(0, lines.length)),
      );
    }
    if (pages.isEmpty) pages.add(const <String>[]);

    final objects = <String>[
      '',
      '',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>',
    ];
    final pageIds = <int>[];
    for (final pageLines in pages) {
      final pageId = objects.length + 1;
      final contentId = pageId + 1;
      pageIds.add(pageId);
      objects.add(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 3 0 R >> >> '
        '/Contents $contentId 0 R >>',
      );
      final commands = StringBuffer('BT\n/F1 9 Tf\n36 806 Td\n12 TL\n');
      for (final line in pageLines) {
        commands.writeln('(${_escape(line)}) Tj T*');
      }
      commands.write('ET\n');
      final stream = commands.toString();
      objects.add(
        '<< /Length ${latin1.encode(stream).length} >>\nstream\n$stream'
        'endstream',
      );
    }
    objects[0] = '<< /Type /Catalog /Pages 2 0 R >>';
    objects[1] =
        '<< /Type /Pages /Count ${pageIds.length} /Kids '
        '[${pageIds.map((id) => '$id 0 R').join(' ')}] >>';

    final output = BytesBuilder(copy: false);
    void write(String value) => output.add(latin1.encode(value));
    write('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');
    final offsets = <int>[0];
    for (var index = 0; index < objects.length; index++) {
      offsets.add(output.length);
      write('${index + 1} 0 obj\n${objects[index]}\nendobj\n');
    }
    final xrefOffset = output.length;
    write('xref\n0 ${objects.length + 1}\n');
    write('0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    write(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xrefOffset\n%%EOF\n',
    );
    return output.takeBytes();
  }

  static String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('(', '\\(')
      .replaceAll(')', '\\)');
}
