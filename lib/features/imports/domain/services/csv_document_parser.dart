/// Strict CSV parser with quoted fields, embedded newlines, and UTF-8 BOM support.
class CsvDocumentParser {
  const CsvDocumentParser();

  List<Map<String, String>> parse(
    String source, {
    required Set<String> requiredHeaders,
    required Set<String> allowedHeaders,
    int maximumRows = 10000,
  }) {
    if (source.contains('\u0000') || source.contains('\uFFFD')) {
      throw const FormatException(
        'Use a UTF-8 CSV file without invalid encoding characters.',
      );
    }
    final input = source.startsWith('\uFEFF') ? source.substring(1) : source;
    final records = <List<String>>[];
    var fields = <String>[];
    var value = StringBuffer();
    var quoted = false;
    var closedQuote = false;
    for (var index = 0; index < input.length; index++) {
      final char = input[index];
      if (quoted) {
        if (char == '"') {
          if (index + 1 < input.length && input[index + 1] == '"') {
            value.write('"');
            index++;
          } else {
            quoted = false;
            closedQuote = true;
          }
        } else {
          value.write(char);
        }
        continue;
      }
      if (char == '"') {
        if (value.isNotEmpty || closedQuote) {
          throw FormatException(
            'Unexpected quote near record ${records.length + 1}.',
          );
        }
        quoted = true;
      } else if (char == ',' || char == '\r' || char == '\n') {
        fields.add(value.toString());
        value = StringBuffer();
        closedQuote = false;
        if (char != ',') {
          if (char == '\r' &&
              index + 1 < input.length &&
              input[index + 1] == '\n') {
            index++;
          }
          if (fields.any((field) => field.trim().isNotEmpty)) {
            records.add(fields);
          }
          fields = [];
          if (records.length > maximumRows + 1) {
            throw FormatException(
              'Import at most $maximumRows rows at a time.',
            );
          }
        }
      } else {
        if (closedQuote) {
          throw FormatException(
            'Unexpected text after a quoted field near record ${records.length + 1}.',
          );
        }
        value.write(char);
      }
    }
    if (quoted) throw const FormatException('A quoted field is not closed.');
    fields.add(value.toString());
    if (fields.any((field) => field.trim().isNotEmpty)) records.add(fields);
    if (records.isEmpty) throw const FormatException('The CSV file is empty.');
    if (records.length > maximumRows + 1) {
      throw FormatException('Import at most $maximumRows rows at a time.');
    }
    final headers = records.first
        .map((value) => value.trim().toLowerCase())
        .toList();
    if (headers.toSet().length != headers.length ||
        headers.any((value) => value.isEmpty)) {
      throw const FormatException('CSV headers must be unique and non-empty.');
    }
    final missing = requiredHeaders.difference(headers.toSet());
    final unknown = headers.toSet().difference(allowedHeaders);
    if (missing.isNotEmpty || unknown.isNotEmpty) {
      throw FormatException(
        'Invalid headers. ${missing.isEmpty ? '' : 'Missing: ${missing.join(', ')}. '} '
        '${unknown.isEmpty ? '' : 'Unknown: ${unknown.join(', ')}.'}',
      );
    }
    return [
      for (var index = 1; index < records.length; index++)
        if (records[index].length != headers.length)
          throw FormatException(
            'Record ${index + 1} has ${records[index].length} columns; expected ${headers.length}.',
          )
        else
          {
            for (var column = 0; column < headers.length; column++)
              headers[column]: records[index][column].trim(),
          },
    ];
  }
}
