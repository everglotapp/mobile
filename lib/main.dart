import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
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
      ),
      routes: {
        "/": (_) => new WebViewExample(),
      }
    );
  }
}

class WebViewExample extends StatefulWidget {
  @override
  WebViewExampleState createState() => WebViewExampleState();
}

class WebViewExampleState extends State<WebViewExample> {
  @override
  void initState() {
    super.initState();
    // Enable hybrid composition.
    if (Platform.isAndroid) {
      WebView.platform = SurfaceAndroidWebView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebView(
      initialUrl: 'https://demo.everglot.com',
      javascriptMode: JavascriptMode.unrestricted,
      gestureNavigationEnabled: true,
    );
  }
}
