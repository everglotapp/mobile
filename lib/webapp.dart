import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const EVERGLOT_URL = 'https://demo.everglot.com';

class WebAppArguments {
  final String idToken;

  WebAppArguments(this.idToken);
}

class WebAppContainer extends StatefulWidget {
  @override
  WebAppState createState() => WebAppState();
}

class WebAppState extends State<WebAppContainer> {
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
    var _webViewController;
    final args = ModalRoute.of(context)!.settings.arguments as WebAppArguments;

    return WebView(
      initialUrl: EVERGLOT_URL,
      javascriptMode: JavascriptMode.unrestricted,
      onWebViewCreated: (WebViewController controller) {
        _webViewController = controller;
      },
      onPageFinished: (String page) {
        final token = args.idToken;
        print(token);
        _webViewController.evaluateJavascript("""
          fetch("/login", {
            method: "post",
            headers: {
              Accept: "application/json",
              "Content-Type": "application/json",
            },
            body: JSON.stringify({method: "GOOGLE", idToken: "$token"}),
            redirect: "follow"
          })
            .then(function (...args) {
              alert(JSON.stringify(...args));
            });
        """);
      },
      gestureNavigationEnabled: true,
    );
  }
}
