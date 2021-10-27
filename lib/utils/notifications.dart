import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';

enum NotificationType {
  PostReply,
  PostLike,
  PostCorrection,
  PostUserMention,
  GroupMessage
}

NotificationType? findNotificationType(String type) {
  switch (type) {
    case 'POST_REPLY':
      return NotificationType.PostReply;
    case "POST_LIKE":
      return NotificationType.PostLike;
    case "POST_CORRECTION":
      return NotificationType.PostCorrection;
    case "POST_USER_MENTION":
      return NotificationType.PostUserMention;
    case "GROUP_MESSAGE":
      return NotificationType.GroupMessage;
  }
}

Future<NotificationSettings> _tryGetNotificationPermission(
    FirebaseMessaging messaging) async {
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
  return settings;
}

Future<String?> getFcmToken() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  if (!Platform.isAndroid) {
    NotificationSettings _settings =
        await _tryGetNotificationPermission(messaging);
    // print("Notifications authorized?" +
    //     (String)_settings.authorizationStatus);
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
