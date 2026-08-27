// Firebase client identifiers for the isolated JCE POS staging project.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class StagingFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => macos,
      TargetPlatform.windows => windows,
      TargetPlatform.linux => throw UnsupportedError(
        'Staging Firebase options are not configured for Linux.',
      ),
      _ => throw UnsupportedError(
        'Staging Firebase options are not supported on this platform.',
      ),
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAigqYCvUjjewO2mOtxb_j23l0Newk2QDI',
    appId: '1:4515483594:web:82df2d4802e89d25aa0933',
    messagingSenderId: '4515483594',
    projectId: 'jce-pos-staging-259528',
    authDomain: 'jce-pos-staging-259528.firebaseapp.com',
    storageBucket: 'jce-pos-staging-259528.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBh-9AQIchzyaG3uPZ-Fl0hoDxeCdSDU58',
    appId: '1:4515483594:android:5b1136e696c13ce4aa0933',
    messagingSenderId: '4515483594',
    projectId: 'jce-pos-staging-259528',
    storageBucket: 'jce-pos-staging-259528.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCvUnKTbC8GdjP6NgPS3bbfBBM8Jg-3g_c',
    appId: '1:4515483594:ios:e37db2cd9642b3d3aa0933',
    messagingSenderId: '4515483594',
    projectId: 'jce-pos-staging-259528',
    storageBucket: 'jce-pos-staging-259528.firebasestorage.app',
    iosBundleId: 'com.jce.pos',
  );

  static const FirebaseOptions macos = ios;

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAigqYCvUjjewO2mOtxb_j23l0Newk2QDI',
    appId: '1:4515483594:web:1fe84a0bcefcbb46aa0933',
    messagingSenderId: '4515483594',
    projectId: 'jce-pos-staging-259528',
    authDomain: 'jce-pos-staging-259528.firebaseapp.com',
    storageBucket: 'jce-pos-staging-259528.firebasestorage.app',
  );
}
