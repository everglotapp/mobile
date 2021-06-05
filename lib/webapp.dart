import 'dart:io';
import 'package:everglot/constants.dart';
import 'package:everglot/login.dart';
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
  bool jsRanOnce = false;

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
    WebViewController? _webViewController;
    final args = ModalRoute.of(context)!.settings.arguments as WebAppArguments;

    return WebView(
      initialUrl: EVERGLOT_URL,
      javascriptMode: JavascriptMode.unrestricted,
      javascriptChannels: Set.from([
        JavascriptChannel(
            name: 'WebViewLocationChange',
            onMessageReceived: (JavascriptMessage message) async {
              final path = message.message;
              if (path.startsWith("/join") || path.startsWith("/login")) {
                await Navigator.pushReplacementNamed(context, "/",
                    arguments: LoginPageArguments(true));
              }
            })
      ]),
      onWebViewCreated: (WebViewController controller) {
        _webViewController = controller;
        print("Web view created");
      },
      onPageFinished: (String page) {
        final token = args.idToken;
        _webViewController!.evaluateJavascript("""
          console.log("Trying to log in");
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

        if (!jsRanOnce) {
          setState(() {
            jsRanOnce = true;
          });
          _webViewController!.evaluateJavascript("""
        history.pushState = ( f => function pushState(){
            var ret = f.apply(this, arguments);
            window.dispatchEvent(new Event('pushstate'));
            window.dispatchEvent(new Event('locationchange'));
            return ret;
        })(history.pushState);

        history.replaceState = ( f => function replaceState(){
            var ret = f.apply(this, arguments);
            window.dispatchEvent(new Event('replacestate'));
            window.dispatchEvent(new Event('locationchange'));
            return ret;
        })(history.replaceState);

        window.addEventListener('popstate',()=>{
            window.dispatchEvent(new Event('locationchange'))
        });

        window.addEventListener("locationchange", function() {
          WebViewLocationChange.postMessage(window.location.pathname)
        });
        """);
        }
      },
      gestureNavigationEnabled: true,
    );
  }
}
