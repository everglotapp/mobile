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
  bool _loggedIn = false;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    // Enable hybrid composition.
    if (Platform.isAndroid) {
      WebView.platform = SurfaceAndroidWebView();
    }
  }

  _tryLogin() async {
    final args = ModalRoute.of(context)!.settings.arguments as WebAppArguments;
    final token = args.idToken;
    await _webViewController?.evaluateJavascript("""
          console.log("Trying to log in");
          var res = fetch("/login", {
            method: "post",
            headers: {
              Accept: "application/json",
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              method: "google",
              idToken: "$token"
            }),
            redirect: "follow"
          }).then(function (response) {
            if (response && response.redirected && response.url && response.url.length) {
                history.replaceState(null, '', response.url);
                return
            }
            response.json().then(function (res) {
              console.log(JSON.stringify(res));
              if (res && res.success) {
                WebViewLoginState.postMessage("1");
              }
            }).catch(function (e) {
              console.log("Failed to parse response as JSON", res, e)
            });
          }).catch(function(e) {
            console.log("Login HTTP request failed", e)
          });
        """);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: true,
        body: WebView(
          initialUrl: EVERGLOT_URL,
          javascriptMode: JavascriptMode.unrestricted,
          javascriptChannels: Set.from([
            JavascriptChannel(
                name: 'WebViewLocationChange',
                onMessageReceived: (JavascriptMessage message) async {
                  final path = message.message;
                  print("Location changed: " + path);
                  if (path.startsWith("/join") || path.startsWith("/login")) {
                    setState(() {
                      _loggedIn = false;
                    });
                    await Navigator.pushReplacementNamed(context, "/",
                        arguments: LoginPageArguments(true));
                  }
                }),
            JavascriptChannel(
                name: 'WebViewLoginState',
                onMessageReceived: (JavascriptMessage message) async {
                  setState(() {
                    _loggedIn = message.message == "1";
                  });
                  print("Login state changed: " + message.message);
                  if (_loggedIn) {
                    await _webViewController?.loadUrl(EVERGLOT_URL + "/signup");
                  } else {
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
            print("Page finished: " + page);
            if (page.startsWith(EVERGLOT_URL + "/login")) {
              setState(() {
                _loggedIn = false;
              });
              _tryLogin();
            }
            _webViewController?.evaluateJavascript("""
        if (!window.locationChangeListenersInitialized) {
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
          window.locationChangeListenersInitialized = true;
        }
        """);
          },
          userAgent: _getWebviewUserAgent(),
          gestureNavigationEnabled: true,
        ));
  }

  String _getWebviewUserAgent() {
    if (Platform.isAndroid) {
      return "ANDROID_WEBVIEW";
    }
    if (Platform.isIOS) {
      return "IOS_WEBVIEW";
    }
    return "MOBILE_APP_WEBVIEW";
  }
}
