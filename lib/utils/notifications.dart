import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';

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
  debugPrint('User granted permission: ${settings.authorizationStatus}');
  return settings;
}

Future<String?> getFcmToken() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  if (!Platform.isAndroid) {
    await _tryGetNotificationPermission(messaging);
    // debugPrint("Notifications authorized?" +
    //     (String)_settings.authorizationStatus);
    // if (_settings.authorizationStatus == AuthorizationStatus.authorized) {
    // }
  }
  String? token = await messaging.getToken();
  if (kDebugMode) {
    if (token != null) {
      debugPrint("Got FCM token $token");
    } else {
      debugPrint("Failed to get FCM token");
    }
  }
  return token;
}

listenForeground() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');

    if (message.notification != null) {
      debugPrint(
          'Message also contained a notification: ${message.notification}');
    }
  });
}
