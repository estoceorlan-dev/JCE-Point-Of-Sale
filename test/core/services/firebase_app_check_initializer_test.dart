import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/config/app_config.dart';
import 'package:jce_pos/core/config/app_environment.dart';
import 'package:jce_pos/core/services/firebase_app_check_initializer.dart';

void main() {
  const initializer = FirebaseAppCheckInitializer();
  final app = _FakeApp();

  AppConfig config({
    String? siteKey,
    AppEnvironment environment = AppEnvironment.production,
  }) => AppConfig(
    environment: environment,
    enableDemoAuth: false,
    enableDiagnostics: false,
    appCheckWebSiteKey: siteKey,
  );

  test(
    'production Android explicitly uses Play Integrity then auto refresh',
    () async {
      final check = _FakeAppCheck();
      await initializer.initialize(
        app: app,
        config: config(),
        appCheck: check,
        isWeb: false,
      );
      expect(check.calls.map((call) => call.memberName), [
        #activate,
        #setTokenAutoRefreshEnabled,
      ]);
      expect(
        check.calls.first.namedArguments[#providerAndroid],
        isA<AndroidPlayIntegrityProvider>(),
      );
      expect(check.calls.first.namedArguments[#providerWeb], isNull);
      expect(check.calls.last.positionalArguments, [true]);
    },
  );

  test('production web uses reCAPTCHA Enterprise', () async {
    final check = _FakeAppCheck();
    await initializer.initialize(
      app: app,
      config: config(siteKey: ' web-key '),
      appCheck: check,
      isWeb: true,
    );
    final provider = check.calls.first.namedArguments[#providerWeb];
    expect(provider, isA<ReCaptchaEnterpriseProvider>());
    expect((provider as ReCaptchaEnterpriseProvider).siteKey, 'web-key');
  });

  test(
    'missing or blank production web key fails before activating any provider',
    () async {
      for (final key in [null, '', '  ']) {
        final check = _FakeAppCheck();
        await expectLater(
          initializer.initialize(
            app: app,
            config: config(siteKey: key),
            appCheck: check,
            isWeb: true,
          ),
          throwsStateError,
        );
        expect(check.calls, isEmpty);
      }
    },
  );

  test(
    'attestation activation failure propagates without enabling refresh',
    () async {
      final check = _FakeAppCheck(failActivation: true);
      await expectLater(
        initializer.initialize(
          app: app,
          config: config(),
          appCheck: check,
          isWeb: false,
        ),
        throwsStateError,
      );
      expect(check.calls.map((call) => call.memberName), [#activate]);
    },
  );

  test(
    'nonproduction startup does not request production attestation',
    () async {
      for (final environment in [
        AppEnvironment.development,
        AppEnvironment.staging,
      ]) {
        final check = _FakeAppCheck();
        await initializer.initialize(
          app: app,
          config: config(environment: environment),
          appCheck: check,
          isWeb: true,
        );
        expect(check.calls, isEmpty);
      }
    },
  );
}

class _FakeApp implements FirebaseApp {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAppCheck implements FirebaseAppCheck {
  _FakeAppCheck({this.failActivation = false});
  final bool failActivation;
  final calls = <Invocation>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (invocation.memberName == #activate && failActivation) {
      return Future<void>.error(StateError('Attestation activation failed'));
    }
    if (invocation.memberName == #activate ||
        invocation.memberName == #setTokenAutoRefreshEnabled) {
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
