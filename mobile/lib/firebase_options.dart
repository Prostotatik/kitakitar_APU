// ⚠️ IMPORTANT: This file needs to be configured before use!
// 
// Method 1 (recommended): Run in terminal:
//   cd mobile
//   flutterfire configure
//
// Method 2: Create file manually (see README.md)
//
// After configuration, this file should contain DefaultFirebaseOptions class
// with your Firebase project configuration.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Data from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAjFzxXkd8ejk9YnuhxUU-YnaNepxIEXtk',
    appId: '1:313112928368:android:ee61df6bf0320ccf23d4b5',
    messagingSenderId: '313112928368',
    projectId: 'kitakitar',
    storageBucket: 'kitakitar.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY_HERE',
    appId: 'YOUR_IOS_APP_ID_HERE',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID_HERE',
    projectId: 'YOUR_PROJECT_ID_HERE',
    storageBucket: 'YOUR_STORAGE_BUCKET_HERE',
    iosBundleId: 'com.example.kitakitarMobile', // Replace with your bundle ID
  );
}

