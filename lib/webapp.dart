import 'dart:convert';
import 'dart:io';
import 'package:everglot/constants.dart';
import 'package:everglot/login.dart';
import 'package:everglot/utils/webapp.dart';
import 'package:everglot/utils/webapp_js.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

abstract class WebAppArguments {
  late final SignInMethod method;
}

enum SignInMethod { Google, Email }

class GoogleSignInArguments extends WebAppArguments {
  final SignInMethod method = SignInMethod.Google;
  final String idToken;

  GoogleSignInArguments(this.idToken);
}

class EmailSignInArguments extends WebAppArguments {
  final SignInMethod method = SignInMethod.Email;
  final String email;
  final String password;

  EmailSignInArguments(this.email, this.password);
}

class WebAppContainer extends StatefulWidget {
  @override
  WebAppState createState() => WebAppState();
}

class WebAppState extends State<WebAppContainer> {
  bool _loggedIn = false;
  WebViewController? _webViewController;
  final Future<String> _initialization = getEverglotUrl();

  @override
  void initState() {
    super.initState();
    // Enable hybrid composition.
    if (Platform.isAndroid) {
      WebView.platform = SurfaceAndroidWebView();
    }
  }

  Future<void> _tryLogin() async {
    WebAppArguments args =
        ModalRoute.of(context)!.settings.arguments as WebAppArguments;
    Map<String, String> body = {};
    if (args.method == SignInMethod.Google) {
      args = args as GoogleSignInArguments;
      body["method"] = EVERGLOT_AUTH_METHOD_GOOGLE;
      body["idToken"] = args.idToken;
    } else if (args.method == SignInMethod.Email) {
      args = args as EmailSignInArguments;
      body["method"] = EVERGLOT_AUTH_METHOD_EMAIL;
      body["email"] = args.email;
      body["password"] = args.password;
    }
    final String jsonBody = json.encode(body);
    await _webViewController?.evaluateJavascript("""
      console.log("Trying to log in");
      var res = fetch("/login", {
        method: "post",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: '$jsonBody',
        redirect: "follow"
      }).then(function (response) {
        if (response && response.redirected && response.url && response.url.length) {
          console.log("Login HTTP request succeeded with redirect to "+ response.url);
          history.replaceState(null, '', response.url);
          $tryShowPageContentsJsFunc();
          return;
        }
        response.json().then(function (res) {
          console.log(JSON.stringify(res));
          if (res && res.success) {
            WebViewLoginState.postMessage("1");
          } else {
            WebViewLoginState.postMessage("0");
          }
        }).catch(function (e) {
          console.log("Failed to parse response as JSON", res, e);
            WebViewLoginState.postMessage("0");
        });
      }).catch(function(e) {
        console.log("Login HTTP request failed", e);
        WebViewLoginState.postMessage("0");
      });
    """);
  }

  Future<bool> _tryHidePageContents() async {
    print("Trying to hide page contents …");
    return (await _webViewController
            ?.evaluateJavascript("""$tryHidePageContentsJsFunc();""")) ==
        "true";
  }

  Future<bool> _tryShowPageContents() async {
    print("Trying to show page contents …");
    return (await _webViewController
            ?.evaluateJavascript("""$tryShowPageContentsJsFunc();""")) ==
        "true";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold();
          }
          if (snapshot.connectionState == ConnectionState.done) {
            final everglotRootUrl = snapshot.data as String;
            final everglotLoginUrl = everglotRootUrl + "login";
            return Scaffold(
                resizeToAvoidBottomInset: true,
                body: SafeArea(
                    child: WebView(
                  initialUrl: everglotRootUrl,
                  javascriptMode: JavascriptMode.unrestricted,
                  javascriptChannels: Set.from([
                    JavascriptChannel(
                        name: 'WebViewLocationChange',
                        onMessageReceived: (JavascriptMessage message) async {
                          final path = message.message;
                          print("Location changed: " + path);
                          if (path.startsWith("/join") ||
                              path.startsWith("/login")) {
                            print(
                                "Logged out state detected, switching to login screen");
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
                            await _webViewController?.loadUrl(everglotRootUrl);
                            await _tryShowPageContents();
                          } else {
                            await Navigator.pushReplacementNamed(context, "/",
                                arguments: LoginPageArguments(true));
                          }
                        })
                  ]),
                  onWebViewCreated: (WebViewController controller) async {
                    _webViewController = controller;
                    print("Web view created");
                    await _tryHidePageContents();
                  },
                  onPageStarted: (String page) async {
                    print("Page started: " + page);
                    if (page.startsWith(everglotLoginUrl)) {
                      await _tryHidePageContents();
                    } else {
                      await _tryShowPageContents();
                    }
                  },
                  onPageFinished: (String page) async {
                    print("Page finished: " + page);
                    if (page.startsWith(everglotLoginUrl)) {
                      setState(() {
                        _loggedIn = false;
                      });
                      await _tryHidePageContents();
                      await _tryLogin();
                    } else {
                      await _tryShowPageContents();
                    }
                    _webViewController?.evaluateJavascript("""
                      $initializeLocationChangeListenersJsFunc();
                    """);
                  },
                  userAgent: _getWebviewUserAgent(),
                  gestureNavigationEnabled: true,
                )));
          }
          return Scaffold();
        });
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
