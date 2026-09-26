import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('このプラットフォームはサポートされていません');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDSSY_3AsRDrFs-LKqh723fcX7M5TPt4ow',
    appId: '1:16094171054:android:0d569cdf9aab5369a8023f',
    messagingSenderId: '16094171054',
    projectId: 'shiori-8fd3f',
    storageBucket: 'shiori-8fd3f.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDSSY_3AsRDrFs-LKqh723fcX7M5TPt4ow',
    appId: '1:16094171054:web:f7eeb3547ef993a6a8023f',
    messagingSenderId: '16094171054',
    projectId: 'shiori-8fd3f',
    storageBucket: 'shiori-8fd3f.firebasestorage.app',
    authDomain: 'shiori-8fd3f.firebaseapp.com',
  );
}
