import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/firebase_options_production.dart';

void main() {
  test('builds isolated production options from validated values', () {
    final options = ProductionFirebaseOptions.fromValues(
      apiKey: 'production-api-key',
      appId: '1:123:web:production',
      messagingSenderId: '123',
      projectId: 'jce-pos-production-example',
      approvedProjectId: 'jce-pos-production-example',
      authDomain: 'jce-pos-production-example.firebaseapp.com',
      storageBucket: 'jce-pos-production-example.firebasestorage.app',
      requireAuthDomain: true,
      requiredAppIdMarker: ':web:',
    );

    expect(options.projectId, 'jce-pos-production-example');
  });

  test('rejects development and staging projects', () {
    expect(
      () => ProductionFirebaseOptions.fromValues(
        apiKey: 'staging-api-key',
        appId: '1:123:web:staging',
        messagingSenderId: '123',
        projectId: 'jce-pos-staging-259528',
        approvedProjectId: 'jce-pos-production-example',
        authDomain: 'jce-pos-staging-259528.firebaseapp.com',
        storageBucket: 'jce-pos-staging-259528.firebasestorage.app',
      ),
      throwsFormatException,
    );
  });

  test('requires every production identifier', () {
    expect(
      () => ProductionFirebaseOptions.fromValues(
        apiKey: '',
        appId: '',
        messagingSenderId: '',
        projectId: '',
        approvedProjectId: '',
        storageBucket: '',
      ),
      throwsFormatException,
    );
  });

  test('rejects an app registration for the wrong platform', () {
    expect(
      () => ProductionFirebaseOptions.fromValues(
        apiKey: 'production-api-key',
        appId: '1:123:web:production',
        messagingSenderId: '123',
        projectId: 'jce-pos-production-example',
        approvedProjectId: 'jce-pos-production-example',
        storageBucket: 'jce-pos-production-example.firebasestorage.app',
        requiredAppIdMarker: ':android:',
      ),
      throwsFormatException,
    );
  });

  test('rejects a production project that was not independently approved', () {
    expect(
      () => ProductionFirebaseOptions.fromValues(
        apiKey: 'production-api-key',
        appId: '1:123:web:production',
        messagingSenderId: '123',
        projectId: 'jce-pos-production-unapproved',
        approvedProjectId: 'jce-pos-production-approved',
        storageBucket: 'jce-pos-production-unapproved.firebasestorage.app',
      ),
      throwsFormatException,
    );
  });
}
