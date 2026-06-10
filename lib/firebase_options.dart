import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }


  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDR6ijml0quYCfl61eV6K3rLnq-9v0dLSA',
    appId: '1:948326605122:android:ccd6e3cdd27a8ef12768db',
    messagingSenderId: '948326605122',
    projectId: 'now-fishing-final',
    storageBucket: 'now-fishing-final.firebasestorage.app',
  );
  
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDdibOuJI26FdvJOkCQY_c6RkoxhdiP5pM',
    appId: '1:340302655045:web:4927ca0a9da0907593fd2c',
    messagingSenderId: '340302655045',
    projectId: 'now-fishing-723a8',
    authDomain: 'now-fishing-723a8.firebaseapp.com',
    storageBucket: 'now-fishing-723a8.firebasestorage.app',
    measurementId: 'G-KLCGNY2XZP',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAvOoyc4847kbIx4aW4N-iNi16xhT0vCA8',
    appId: '1:948326605122:ios:8fd830a786908d302768db',
    messagingSenderId: '948326605122',
    projectId: 'now-fishing-final',
    storageBucket: 'now-fishing-final.firebasestorage.app',
    iosBundleId: 'com.example.busanFushApp',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCaDwQuZhZ2XZIGDBE7noP08PoDC5pim7I',
    appId: '1:340302655045:ios:a3126305c0173d3493fd2c',
    messagingSenderId: '340302655045',
    projectId: 'now-fishing-723a8',
    storageBucket: 'now-fishing-723a8.firebasestorage.app',
    iosBundleId: 'com.example.busanFushApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDdibOuJI26FdvJOkCQY_c6RkoxhdiP5pM',
    appId: '1:340302655045:web:382230b3a8d552c193fd2c',
    messagingSenderId: '340302655045',
    projectId: 'now-fishing-723a8',
    authDomain: 'now-fishing-723a8.firebaseapp.com',
    storageBucket: 'now-fishing-723a8.firebasestorage.app',
    measurementId: 'G-QVPERMDNP7',
  );
}
