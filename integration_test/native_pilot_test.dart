import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:jce_pos/features/auth/data/security/argon_pin_hasher.dart';
import 'package:jce_pos/features/auth/data/security/credential_record_store.dart';
import 'package:jce_pos/features/auth/data/security/native_credential_vault.dart';
import '../test/features/auth/node_sale_scenario.dart';

/// Run through the backend's test:native-pilot command, using disposable data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows native pilot stage', (tester) async {
    final encoded = Platform.environment['JCE_NATIVE_PILOT_PROFILE'];
    if (!Platform.isWindows || encoded == null) {
      throw StateError('Use the Windows backend test:native-pilot runner.');
    }
    final config = jsonDecode(encoded) as Map<String, dynamic>;
    final origin = Uri.parse(config['origin'] as String);
    final runId = config['runId'] as String;
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    if (config['purpose'] != 'disposable-native-pilot-v1' ||
        origin.scheme != 'http' ||
        origin.host != '127.0.0.1' ||
        !uuid.hasMatch(runId) ||
        !uuid.hasMatch(config['deploymentId'] as String)) {
      throw StateError('A disposable loopback fixture is required.');
    }
    final directory = Directory(config['directory'] as String);
    final resolved = await directory.resolveSymbolicLinks();
    final tempRoot = await Directory('.tmp').resolveSymbolicLinks();
    if (!path.equals(path.dirname(resolved), tempRoot) ||
        path.basename(resolved) != 'native-pilot-$runId') {
      throw StateError(
        'Pilot files must be isolated under the client .tmp directory.',
      );
    }
    final stage = config['stage'] as String;
    final vault = NativeCredentialVault();
    final records = CredentialRecordStore(
      vault,
      config['deploymentId'] as String,
    );
    final existing = await vault.read(records.key);
    if (stage == 'prepare') {
      if (existing != null) {
        throw StateError('Refusing to overwrite existing credentials.');
      }
      await records.transact((state) async {
        state['nativePilotRunId'] = runId;
      });
    } else if (existing != null) {
      final owned = jsonDecode(existing) as Map;
      if (owned['nativePilotRunId'] != runId ||
          owned['deploymentId'] != config['deploymentId']) {
        throw StateError(
          'Refusing to access credentials owned by another run.',
        );
      }
    } else if (stage != 'cleanup') {
      throw StateError(
        'No persisted native credentials from the prepare process.',
      );
    }

    if (stage == 'cleanup') {
      await vault.delete(records.key);
      expect(await vault.read(records.key), isNull);
      for (final name in [
        'pos.sqlite',
        'pos.sqlite-wal',
        'pos.sqlite-shm',
        'pos.sqlite-journal',
      ]) {
        final file = File(path.join(resolved, name));
        if (await file.exists()) await file.delete();
      }
    } else {
      if (!{'prepare', 'resume'}.contains(stage)) {
        throw StateError('Unknown stage.');
      }
      final scenario = NodeSaleScenario(
        config: config,
        directory: directory,
        vault: vault,
        hasher: const ArgonPinHasher(),
      );
      try {
        final checkpointFile = File(path.join(resolved, 'checkpoint.json'));
        if (stage == 'prepare') {
          final checkpoint = await scenario.prepare();
          await checkpointFile.writeAsString(
            jsonEncode({
              ...checkpoint,
              'runId': runId,
              'prepareProcessId': pid,
            }),
            flush: true,
          );
        } else {
          final checkpoint =
              jsonDecode(await checkpointFile.readAsString())
                  as Map<String, dynamic>;
          expect(checkpoint['runId'], runId);
          expect(
            checkpoint['prepareProcessId'],
            isNot(pid),
            reason: 'Resume must use a new app process.',
          );
          await scenario.resume(checkpoint);
        }
      } finally {
        await scenario.close();
      }
    }
    await File(path.join(resolved, '$stage.json')).writeAsString(
      jsonEncode({
        'runId': runId,
        'stage': stage,
        'passed': true,
        'processId': pid,
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
