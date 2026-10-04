import 'dart:convert';
import 'dart:io';

import 'package:jce_pos/core/config/release_config_validator.dart';

Future<void> main(List<String> arguments) async {
  try {
    final parsed = _Arguments.parse(arguments);
    final source = File(parsed.configPath);
    if (!await source.exists()) {
      throw FormatException('Configuration file not found: ${source.path}');
    }
    final decoded = jsonDecode(await source.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Configuration must be a JSON object.');
    }
    ReleaseConfigValidator.ensureValid(
      values: decoded,
      platform: parsed.platform,
      expectedProjectId: parsed.expectedProjectId,
    );
    stdout.writeln(
      'Production ${parsed.platform.name} configuration is valid. '
      'No configuration values were printed.',
    );
  } on FormatException catch (error) {
    stderr.writeln('Release configuration rejected:\n${error.message}');
    exitCode = 64;
  } on FileSystemException catch (error) {
    stderr.writeln('Release configuration could not be read: ${error.message}');
    exitCode = 66;
  }
}

class _Arguments {
  const _Arguments({
    required this.configPath,
    required this.platform,
    required this.expectedProjectId,
  });

  factory _Arguments.parse(List<String> arguments) {
    String? valueFor(String name) {
      final prefix = '--$name=';
      final match = arguments.where((value) => value.startsWith(prefix));
      return match.isEmpty ? null : match.last.substring(prefix.length).trim();
    }

    final configPath = valueFor('config');
    final platform = valueFor('platform');
    final expectedProject = valueFor('expected-project');
    if (configPath == null ||
        configPath.isEmpty ||
        platform == null ||
        platform.isEmpty ||
        expectedProject == null ||
        expectedProject.isEmpty) {
      throw const FormatException(
        'Usage: dart run tool/validate_release_config.dart '
        '--config=<local-json> --platform=<android|web|windows> '
        '--expected-project=<approved-project-id>',
      );
    }
    return _Arguments(
      configPath: configPath,
      platform: ReleasePlatform.parse(platform),
      expectedProjectId: expectedProject,
    );
  }

  final String configPath;
  final ReleasePlatform platform;
  final String expectedProjectId;
}
