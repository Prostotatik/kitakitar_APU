import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for center_web.
///
/// Important: for a full web configuration it is better to run `flutterfire configure`
/// from the `center_web` folder and replace the values below with real ones.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // For web you can use the same project keys as for Android mobile.
      return web;
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

  // We use the same values as in mobile/android (can be moved to .env if desired)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAjFzxXkd8ejk9YnuhxUU-YnaNepxIEXtk',
    appId: '1:313112928368:web:center_web_dummy_app', // can be replaced after flutterfire configure
    messagingSenderId: '313112928368',
    projectId: 'kitakitar',
    storageBucket: 'kitakitar.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAjFzxXkd8ejk9YnuhxUU-YnaNepxIEXtk',
    appId: '1:313112928368:android:center_web_dummy_app',
    messagingSenderId: '313112928368',
    projectId: 'kitakitar',
    storageBucket: 'kitakitar.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY_HERE',
    appId: 'YOUR_IOS_APP_ID_HERE',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID_HERE',
    projectId: 'kitakitar',
    storageBucket: 'kitakitar.firebasestorage.app',
    iosBundleId: 'com.example.kitakitarCenterWeb',
  );
}

