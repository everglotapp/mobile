import 'dart:io';
import 'package:everglot/login.dart';
import 'package:everglot/utils/webapp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final Future<String> _initialization = getEverglotUrl();
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));
  late PullToRefreshController pullToRefreshController;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.blue,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );
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
            return Scaffold(
                resizeToAvoidBottomInset: true,
                body: SafeArea(
                  child: InAppWebView(
                    key: webViewKey,
                    initialUrlRequest:
                        URLRequest(url: Uri.parse(everglotRootUrl)),
                    initialOptions: options,
                    pullToRefreshController: pullToRefreshController,
                    onWebViewCreated: (controller) {
                      webViewController = controller;
                    },
                    onLoadStart: (controller, url) {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    androidOnPermissionRequest:
                        (controller, origin, resources) async {
                      return PermissionRequestResponse(
                          resources: resources,
                          action: PermissionRequestResponseAction.GRANT);
                    },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                      var uri = navigationAction.request.url!;

                      if (![
                        "http",
                        "https",
                      ].contains(uri.scheme)) {
                        if (await canLaunch(url)) {
                          // Launch the App
                          await launch(
                            url,
                          );
                          // and cancel the request
                          return NavigationActionPolicy.CANCEL;
                        }
                      }
                      // TODO: Prevent non-Everglot URLs

                      return NavigationActionPolicy.ALLOW;
                    },
                    onLoadStop: (controller, url) async {
                      pullToRefreshController.endRefreshing();
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    onLoadError: (controller, url, code, message) {
                      pullToRefreshController.endRefreshing();
                    },
                    onProgressChanged: (controller, progress) {
                      if (progress == 100) {
                        pullToRefreshController.endRefreshing();
                      }
                      setState(() {
                        urlController.text = this.url;
                      });
                    },
                    onUpdateVisitedHistory:
                        (controller, url, androidIsReload) async {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                      if (this.url.startsWith(
                              await getEverglotUrl(path: "/join")) ||
                          this.url.startsWith(
                              await getEverglotUrl(path: "/login"))) {
                        print(
                            "Logged out state detected, switching to login screen");
                        await Navigator.pushReplacementNamed(context, "/",
                            arguments: LoginPageArguments(true));
                      }
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      print(consoleMessage);
                    },
                  ),
                ));

            //     child: WebView(
            //   initialUrl: everglotPlaceholderUrl,
            //   javascriptMode: JavascriptMode.unrestricted,
            //   javascriptChannels: Set.from([
            //     JavascriptChannel(
            //         name: 'WebViewLocationChange',
            //         onMessageReceived: (JavascriptMessage message) async {
            //           final path = message.message;
            //           print("Location changed: " + path);
            //           if (path.startsWith("/join") ||
            //               path.startsWith("/login")) {
            //             print(
            //                 "Logged out state detected, switching to login screen");
            //             setState(() {
            //               _loggedIn = false;
            //             });
            //             await Navigator.pushReplacementNamed(context, "/",
            //                 arguments: LoginPageArguments(true));
            //           }
            //         }),
            //     JavascriptChannel(
            //         name: 'WebViewLoginState',
            //         onMessageReceived: (JavascriptMessage message) async {
            //           setState(() {
            //             _loggedIn = message.message == "1";
            //           });
            //           print("Login state changed: " + message.message);
            //           if (_loggedIn) {
            //             await _webViewController?.loadUrl(everglotRootUrl);
            //           } else {
            //             await Navigator.pushReplacementNamed(context, "/",
            //                 arguments: LoginPageArguments(true));
            //           }
            //         })
            //   ]),
            //   onWebViewCreated: (WebViewController controller) async {
            //     _webViewController = controller;
            //     print("Web view created");
            //   },
            //   onPageFinished: (String page) async {
            //     print("Page finished: " + page);
            //     if (page.startsWith(everglotPlaceholderUrl)) {
            //       setState(() {
            //         _loggedIn = false;
            //       });
            //       await _tryLogin();
            //     }
            //     _webViewController?.evaluateJavascript("""
            //       $initializeLocationChangeListenersJsFunc();
            //     """);
            //   },
            //   userAgent: _getWebviewUserAgent(),
            //   gestureNavigationEnabled: true,
            // )));
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
