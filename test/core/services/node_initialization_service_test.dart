import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/config/app_config.dart';
import 'package:jce_pos/core/services/node_initialization_service.dart';

void main() {
  final config = AppConfig.fromValues(environment: 'staging');
  test('demo starts without deployment or credential services', () async {
    var calls = 0;
    final service = NodeInitializationService(
      initializeBinding: () async {
        calls++;
      },
      recoverQueue: () async {
        calls++;
      },
      native: true,
    );
    await service.initialize(
      AppConfig.fromValues(
        environment: 'development',
        enableDemoAuth: 'true',
        demoBranchId: 'demo-test',
      ),
    );
    expect(calls, 0);
  });
  test('native recovery follows verified installation binding', () async {
    final events = <String>[];
    final service = NodeInitializationService(
      initializeBinding: () async {
        events.add('bound');
      },
      recoverQueue: () async {
        events.add('recovery');
      },
      native: true,
    );
    await service.initialize(config);
    expect(events, ['bound', 'recovery']);
  });
  test('binding failure cannot start queue replay', () async {
    var replayed = false;
    final service = NodeInitializationService(
      initializeBinding: () async {
        throw StateError('deployment mismatch');
      },
      recoverQueue: () async {
        replayed = true;
      },
      native: true,
    );
    await expectLater(service.initialize(config), throwsStateError);
    expect(replayed, isFalse);
  });
  test('web administration binds without native device recovery', () async {
    final events = <String>[];
    final service = NodeInitializationService(
      initializeBinding: () async {
        events.add('bound');
      },
      recoverQueue: () async {
        events.add('recovery');
      },
      native: false,
    );
    await service.initialize(config);
    expect(events, ['bound']);
  });
}
