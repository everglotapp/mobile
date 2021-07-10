import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:everglot/login.dart';
import 'package:everglot/webapp.dart';
import 'package:everglot/splash.dart';
import 'package:everglot/error.dart';
import 'package:everglot/utils/ui.dart';
import 'package:everglot/utils/notifications.dart';
import 'package:everglot/state/messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  // Do not add anything before the below line.
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  await Permission.camera.request();
  await Permission.microphone.request();
  runApp(App());
}

Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
}

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
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

  Future<void> _setupHandleInteractionWithNotification() async {
    // Get any messages which caused the application to open from
    // a terminated state.
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage == null ||
        initialMessage.data['type'] != 'GROUP_MESSAGE') {
      return;
    }
    final recipientGroupUuid = initialMessage.data["recipientGroupUuid"];
    print(recipientGroupUuid);
    await _navigator.currentState?.pushReplacementNamed("/webapp",
        arguments: WebAppArguments("/chat?group=$recipientGroupUuid"));

    // Hndle any interaction when the app is in the background via a
    // Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      if (message.data['type'] == 'GROUP_MESSAGE') {
        final recipientGroupUuid = message.data["recipientGroupUuid"];
        print(recipientGroupUuid);
        await _navigator.currentState?.pushReplacementNamed("/webapp",
            arguments: WebAppArguments("/chat?group=$recipientGroupUuid"));
      }
    });
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
                return ErrorPage();
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
                    routes: {
                      "/": (_) => LoginPage(),
                      "/webapp": (_) => new WebAppContainer(),
                    });
              }

              print("Loading FirebaseApp …");
              return SplashScreen();
            }));
  }
}
