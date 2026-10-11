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
      expectedDeploymentId: parsed.expectedDeploymentId,
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
    required this.expectedDeploymentId,
  });

  factory _Arguments.parse(List<String> arguments) {
    String? valueFor(String name) {
      final prefix = '--$name=';
      final match = arguments.where((value) => value.startsWith(prefix));
      return match.isEmpty ? null : match.last.substring(prefix.length).trim();
    }

    final configPath = valueFor('config');
    final platform = valueFor('platform');
    final expectedDeployment = valueFor('expected-deployment');
    if (configPath == null ||
        configPath.isEmpty ||
        platform == null ||
        platform.isEmpty ||
        expectedDeployment == null ||
        expectedDeployment.isEmpty) {
      throw const FormatException(
        'Usage: dart run tool/validate_release_config.dart '
        '--config=<local-json> --platform=<android|web|windows> '
        '--expected-deployment=<approved-deployment-uuid>',
      );
    }
    return _Arguments(
      configPath: configPath,
      platform: ReleasePlatform.parse(platform),
      expectedDeploymentId: expectedDeployment,
    );
  }

  final String configPath;
  final ReleasePlatform platform;
  final String expectedDeploymentId;
}
