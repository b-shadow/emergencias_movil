import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('[FCM-BG] Mensaje en background: ${message.notification?.title}');
  debugPrint('[FCM-BG] Body: ${message.notification?.body}');
  debugPrint('[FCM-BG] Data: ${message.data}');
}

Future<void> configurePushBackgroundHandler() async {
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);
}

