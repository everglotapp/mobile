import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:everglot/login.dart';
import 'package:everglot/webapp.dart';
import 'package:everglot/utils/notifications.dart';
import 'package:everglot/state/messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

void main() {
  // Do not add anything before the below line.
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
  runApp(App());
}

Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
}

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

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  final _messaging = Messaging();
  late final Future<FirebaseApp> _initialization =
      Firebase.initializeApp().then((app) async {
    final token = await getFcmToken();
    _messaging.fcmToken = token;
    await listenForeground();
    return app;
  });

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
                print("Loaded app successfully");

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
                      "/": (_) => LoginPage(),
                      "/webapp": (_) => new WebAppContainer(),
                    });
              }

              print("Loading FirebaseApp …");
              return SplashScreen();
            }));
  }
}

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
            color: Colors.white,
            child: Center(
                child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text("Everglot",
                      style: TextStyle(
                          color: primary,
                          fontFamily: "Noto",
                          fontSize: 32,
                          fontWeight: FontWeight.bold))
                ]))));
  }
}

class ErrorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
            color: primary,
            child: Center(
                child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text("Error loading Everglot. Please restart the app.",
                      style: TextStyle(
                          color: Colors.white,
                          fontFamily: "Noto",
                          fontSize: 32,
                          fontWeight: FontWeight.bold))
                ]))));
  }
}
