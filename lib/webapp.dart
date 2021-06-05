import 'dart:io';
import 'package:everglot/constants.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
        _webViewController.evaluateJavascript("""
          fetch("/login", {
            method: "post",
            headers: {
              Accept: "application/json",
              "Content-Type": "application/json",
            },
            body: JSON.stringify({method: "google", idToken: "$token"}),
            redirect: "follow"
          });
        """);
        // TODO: Set up listener for page change, upon sign out redirect to LoginPage
      },
      gestureNavigationEnabled: true,
    );
  }
}
