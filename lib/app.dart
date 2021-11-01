import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:everglot/router.dart';
import 'package:everglot/routes/login.dart';
import 'package:everglot/routes/error.dart';
import 'package:everglot/state/messaging.dart';
import 'package:everglot/utils/webapp.dart';
import 'package:everglot/utils/ui.dart';
import 'package:everglot/utils/notifications.dart';

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
  const App({Key? key}) : super(key: key);
}

class _AppState extends State<App> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  final _messaging = Messaging();
  late final Future<FirebaseApp> _initialization =
      Firebase.initializeApp().then((app) async {
    final token = await getFcmToken();
    _messaging.fcmToken = token;
    await _setupHandleInteractionWithNotification();
    await listenForeground();
    return app;
  });
  String? _forcePath;

  void goToGroup(String groupUuid) {
    if (!Uuid.isValidUUID(fromString: groupUuid)) {
      print("goToGroup: Invalid group UUID: $groupUuid");
      return;
    }
    setState(() {
      _forcePath = getChatPath(groupUuid);
    });
    print("Forcing path to $_forcePath");
  }

  void goToSqueek(String snowflakeId) {
    if (BigInt.tryParse(snowflakeId) == null) {
      print("goToSqueek: Invalid snowflake ID: $snowflakeId");
      return;
    }
    setState(() {
      _forcePath = getSqueekPath(snowflakeId);
    });
    print("Forcing path to $_forcePath");
  }

  void goToUserProfile(String username) {
    if (username.isEmpty) {
      print("goToUserProfile: Empty username: $username");
      return;
    }
    setState(() {
      _forcePath = getUserProfilePath(username);
    });
    print("Forcing path to $_forcePath");
  }

  Future<void> _setupHandleInteractionWithNotification() async {
    // Handle any interaction when the app is in the background via a
    // Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      if (message.data['type'] == null) {
        print(
            "User tapped on notification of an unknown type while app was in background");
        return;
      }
      final messageType = message.data['type'];
      final notificationType = findNotificationType(messageType);
      print(
          "User tapped on notification of type '$messageType' while app was in background");
      switch (notificationType) {
        case NotificationType.groupMessage:
          goToGroup(message.data["recipientGroupUuid"]);
          break;
        case NotificationType.postLike:
          goToSqueek(message.data["postSnowflakeId"]);
          break;
        case NotificationType.postCorrection:
          goToSqueek(message.data["postSnowflakeId"]);
          break;
        case NotificationType.postReply:
          goToSqueek(message.data["parentPostSnowflakeId"]);
          break;
        case NotificationType.postUserMention:
          goToSqueek(message.data["parentPostSnowflakeId"]);
          break;
        case NotificationType.userFollowership:
          goToUserProfile(message.data["followerUsername"]);
          break;
        case null:
          break;
      }
    });

    // Get any messages which caused the application to open from
    // a terminated state.
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage == null) {
      return;
    }

    final messageType = initialMessage.data['type'];
    final notificationType = findNotificationType(messageType);
    print("App was started with a notification of type $messageType");
    switch (notificationType) {
      case NotificationType.groupMessage:
        goToGroup(initialMessage.data["recipientGroupUuid"]);
        break;
      case NotificationType.postLike:
        goToSqueek(initialMessage.data["postSnowflakeId"]);
        break;
      case NotificationType.postCorrection:
        goToSqueek(initialMessage.data["postSnowflakeId"]);
        break;
      case NotificationType.postReply:
        goToSqueek(initialMessage.data["parentPostSnowflakeId"]);
        break;
      case NotificationType.postUserMention:
        goToSqueek(initialMessage.data["parentPostSnowflakeId"]);
        break;
      case NotificationType.userFollowership:
        goToUserProfile(initialMessage.data["followerUsername"]);
        break;
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
        value: _messaging,
        child: FutureBuilder(
            // Initialize FlutterFire:
            future: _initialization,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print("Snapshot error");
                return const ErrorPage();
              }

              if (snapshot.connectionState == ConnectionState.done) {
                print("Loaded Firebase app successfully, rendering Everglot");

                return MaterialApp(
                  title: 'Everglot',
                  navigatorKey: _navigator,
                  theme: ThemeData(
                    // This is the theme of your application.
                    //
                    // Try running your application with "flutter run". You'll see the
                    // application has a blue toolbar. Then, without quitting the app, try
                    // changing the primarySwatch below to Colors.green and then invoke
                    // "hot reload" (press "r" in the console where you ran "flutter run",
                    // or simply save your changes to "hot reload" in a Flutter IDE).
                    // Notice that the counter didn't reset back to zero; the application
                    // is not restarted.
                    primarySwatch: primaryColor,
                    fontFamily: "Noto",
                  ),
                  initialRoute: LoginPage.routeName,
                  onGenerateRoute: EverglotRouter.generateRoute,
                );
              }

              print("Loading FirebaseApp …");
              return MaterialApp(
                  title: 'Everglot',
                  theme: ThemeData(
                    primarySwatch: primaryColor,
                    fontFamily: "Noto",
                  ),
                  home: Scaffold(body: Container(width: 300)));
            }));
  }
}
