import 'dart:io';
import 'package:everglot/login.dart';
import 'package:everglot/utils/login.dart';
import 'package:everglot/utils/webapp.dart';
import 'package:everglot/utils/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

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
        userAgent: getWebviewUserAgent(),
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
        color: primaryColor,
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
                      final uri = navigationAction.request.url!;
                      final url = uri.toString();
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

                      // Forbid non-Everglot URLs.
                      if (!url.startsWith(await getEverglotUrl(path: ""))) {
                        return NavigationActionPolicy.CANCEL;
                      }

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
                      // Prevent /login and /join routes from showing.
                      if (this.url.startsWith(
                              await getEverglotUrl(path: "/join")) ||
                          this.url.startsWith(
                              await getEverglotUrl(path: "/login"))) {
                        print(
                            "Logged out state detected, switching to login screen and removing stored cookie");
                        await removeStoredSessionCookie();

                        await Navigator.popAndPushNamed(context, "/",
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
}
