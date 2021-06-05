import 'package:flutter/material.dart';
import 'package:everglot/login.dart';
import 'package:everglot/webapp.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(App());
}

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        // Initialize FlutterFire:
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print("Snapshot error");
            return ErrorPage();
          }

          if (snapshot.connectionState == ConnectionState.done) {
            print("Loaded app successfully");

            (() async {
              FirebaseMessaging messaging = FirebaseMessaging.instance;

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
              if (settings.authorizationStatus ==
                  AuthorizationStatus.authorized) {
                String? token = await messaging.getToken();
                if (token != null) {
                  print("FCM token ${token}");
                } else {
                  print("failed to get FCM token");
                }
              }
            })();
            FirebaseMessaging.onMessage.listen((RemoteMessage message) {
              print('Got a message whilst in the foreground!');
              print('Message data: ${message.data}');

              if (message.notification != null) {
                print(
                    'Message also contained a notification: ${message.notification}');
              }
            });
            Map<int, Color> colorCodes = {
              50: Color.fromRGBO(69, 180, 66, .1),
              100: Color.fromRGBO(69, 180, 66, .2),
              200: Color.fromRGBO(69, 180, 66, .3),
              300: Color.fromRGBO(69, 180, 66, .4),
              400: Color.fromRGBO(69, 180, 66, .5),
              500: Color.fromRGBO(69, 180, 66, .6),
              600: Color.fromRGBO(69, 180, 66, .7),
              700: Color.fromRGBO(69, 180, 66, .8),
              800: Color.fromRGBO(69, 180, 66, .9),
              900: Color.fromRGBO(69, 180, 66, 1),
            };
            MaterialColor primary = MaterialColor(0xFF45cdcd, colorCodes);

            return MaterialApp(
                title: 'Everglot',
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
                  primarySwatch: primary,
                  fontFamily: "Noto",
                ),
                routes: {
                  "/": (_) => new LoginPage(),
                  "/webapp": (_) => new WebAppContainer(),
                });
          }
          print("Loading Everglot …");

          return LoadingPage();
        });
  }
}

class LoadingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Directionality(
        textDirection: TextDirection.ltr, child: new Text("Loading Everglot "));
  }
}

class ErrorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Directionality(
        textDirection: TextDirection.ltr, child: new Text("Error"));
  }
}
