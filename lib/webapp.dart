import 'dart:io';
import 'package:everglot/login.dart';
import 'package:everglot/utils/webapp.dart';
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
  final Future<String> _initialization = getEverglotUrl();
  static const hidePageContentsId = "EVERGLOT_HIDE_PAGE_CONTENTS_ID";
  static const hidePageContentsHtml =
      """<style id="$hidePageContentsId">body {display:none;}</style>""";

  @override
  void initState() {
    super.initState();
    // Enable hybrid composition.
    if (Platform.isAndroid) {
      WebView.platform = SurfaceAndroidWebView();
    }
  }

  Future<void> _tryLogin() async {
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
          console.log("Login HTTP request succeeded with redirect to "+ response.url);
          history.replaceState(null, '', response.url);
          $tryShowPageContentsJsFunc();
          return;
        }
        response.json().then(function (res) {
          console.log(JSON.stringify(res));
          if (res && res.success) {
            WebViewLoginState.postMessage("1");
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

  static const tryHidePageContentsJsFunc = """
    (function() {
      function doHide() {
        var hider = document.getElementById('$hidePageContentsId');
        if (hider) {
          console.log("Page contents already hidden, cannot hide them");
          return false;
        }
        console.log("Hiding page contents");
        document.write('$hidePageContentsHtml');
      }
      if (document.readyState === "complete") {
        doHide();
      } else {
        document.addEventListener("DOMContentLoaded", function(_event) {
          doHide();
        }, { once: true });
      }
      return true;
    })
  """;
  Future<bool> _tryHidePageContents() async {
    print("Trying to hide page contents …");
    return (await _webViewController
            ?.evaluateJavascript("""$tryHidePageContentsJsFunc();""")) ==
        "true";
  }

  static const tryShowPageContentsJsFunc = """
    (function() {
      function doShow() {
        var hider = document.getElementById('$hidePageContentsId');
        if (!hider) {
          console.log("Page contents are not hidden, cannot show them again");
          return false;
        }
        console.log("Page contents are hidden, showing them again");
        hider.remove();
      }
      if (document.readyState === "complete") {
        doShow();
      } else {
        document.addEventListener("DOMContentLoaded", function(_event) {
          doShow();
        }, { once: true });
      }
      return true;
    })
  """;
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
