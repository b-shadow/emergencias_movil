import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('[FCM-BG] Mensaje en background: ${message.notification?.title}');
  print('[FCM-BG] Body: ${message.notification?.body}');
  print('[FCM-BG] Data: ${message.data}');
}

Future<void> configurePushBackgroundHandler() async {
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);
}
