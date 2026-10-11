import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'native_auth_test_support.dart';
import 'node_sale_scenario.dart';

void main() {
  final encoded = Platform.environment['JCE_AUTH_LIVE_PROFILE'];
  test(
    'Node deployment: SQLite offline checkout, original evidence, restart and lost-response retry',
    () async {
      final directory = await Directory.systemTemp.createTemp('jce-node-sale-');
      final vault = MemoryVault();
      NodeSaleScenario create() => NodeSaleScenario(
        config: jsonDecode(encoded!) as Map,
        directory: directory,
        vault: vault,
        hasher: FastTestPinHasher(),
      );
      var scenario = create();
      try {
        final checkpoint = await scenario.prepare();
        await scenario.close();
        scenario = create();
        await scenario.resume(checkpoint);
      } finally {
        await scenario.close();
        await directory.delete(recursive: true);
      }
    },
    skip: encoded == null,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
