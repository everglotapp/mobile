import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';

enum NotificationType {
  postReply,
  postLike,
  postCorrection,
  postUserMention,
  groupMessage,
  userFollowership
}

NotificationType? findNotificationType(String type) {
  switch (type) {
    case 'POST_REPLY':
      return NotificationType.postReply;
    case "POST_LIKE":
      return NotificationType.postLike;
    case "POST_CORRECTION":
      return NotificationType.postCorrection;
    case "POST_USER_MENTION":
      return NotificationType.postUserMention;
    case "GROUP_MESSAGE":
      return NotificationType.groupMessage;
    case "USER_FOLLOWERSHIP":
      return NotificationType.userFollowership;
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
    await _tryGetNotificationPermission(messaging);
    // print("Notifications authorized?" +
    //     (String)_settings.authorizationStatus);
    // if (_settings.authorizationStatus == AuthorizationStatus.authorized) {
    // }
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
