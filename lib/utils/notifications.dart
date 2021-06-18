import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';

_tryGetNotificationPermission(FirebaseMessaging messaging) async {
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  print('User granted permission: ${settings.authorizationStatus}');
}

Future<String?> getFcmToken() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  if (!Platform.isAndroid) {
    NotificationSettings _settings = _tryGetNotificationPermission(messaging);
    print("Notifications authorized?" +
        jsonEncode(_settings.authorizationStatus));
    // settings.authorizationStatus == AuthorizationStatus.authorized;
    _settings = _settings;
  }
  String? token = await messaging.getToken();
  if (token != null) {
    print("Got FCM token $token");
  } else {
    print("Failed to get FCM token");
  }
  return token;
}

listenForeground() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }
  });
}
