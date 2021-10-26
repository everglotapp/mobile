import 'dart:io';
import 'package:async/async.dart';
import 'package:everglot/login.dart';
import 'package:everglot/utils/login.dart';
import 'package:everglot/utils/webapp.dart';
import 'package:everglot/utils/ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class WebAppArguments {
  String forcePath = "";

  WebAppArguments(this.forcePath);
}

class WebAppContainer extends StatefulWidget {
  static const routeName = '/webapp';

  final String? forcePath;
  WebAppContainer(this.forcePath);

  @override
  WebAppState createState() => WebAppState();
}

class WebAppState extends State<WebAppContainer> with WidgetsBindingObserver {
  final Future<String> _initialization = getEverglotUrl(path: "");
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? _webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
          useShouldOverrideUrlLoading: true,
          mediaPlaybackRequiresUserGesture: false,
          userAgent: getWebviewUserAgent(),
          supportZoom: false),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
        allowsBackForwardNavigationGestures: false,
      ));
  late PullToRefreshController pullToRefreshController;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();
  String? _pathForced;
  bool allowMinimizeApp = false;
  RestartableTimer? allowMinimizeAppTimer;
  final SnackBar snackBar = const SnackBar(
    content: Text('Tap back again to leave'),
  );

  @override
  void initState() {
    super.initState();

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: primaryColor,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          _webViewController?.reload();
        } else if (Platform.isIOS) {
          _webViewController?.loadUrl(
              urlRequest: URLRequest(url: await _webViewController?.getUrl()));
        }
      },
    );
    allowMinimizeAppTimer = RestartableTimer(const Duration(seconds: 3), () {
      setState(() {
        allowMinimizeApp = false;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.hideCurrentSnackBar();
      });
    });
  }

  @override
  void didUpdateWidget(WebAppContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final forcePath = widget.forcePath;
    if (forcePath != null &&
        (forcePath != this._pathForced || forcePath != oldWidget.forcePath)) {
      () async {
        if (_webViewController == null) {
          return;
        }
        final jsResult =
            await _webViewController!.evaluateJavascript(source: """
          (function() {
            if (typeof window === "undefined") {
              return;
            }
            var customEvent = new CustomEvent("everglotGoto", {
              detail: {
                path: "$forcePath"
              }
            });
            return window.dispatchEvent(customEvent);
          })();
        """);
        if (jsResult == true) {
          _pathForced = forcePath;
        }
      }();
    }
  }

  @override
  void dispose() {
    super.dispose();
    allowMinimizeAppTimer?.cancel();
    allowMinimizeAppTimer = null;
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
            final everglotBaseUrl = snapshot.data as String;
            final initialPath =
                widget.forcePath == null ? "/" : widget.forcePath;
            final initialUrl = "$everglotBaseUrl$initialPath";
            return Scaffold(
                resizeToAvoidBottomInset: true,
                body: SafeArea(
                    child: WillPopScope(
                        onWillPop: () async {
                          if (_webViewController != null) {
                            if (await _webViewController!.canGoBack()) {
                              _webViewController?.goBack();
                              return false;
                            }
                          }
                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
                          if (allowMinimizeApp) {
                            allowMinimizeAppTimer?.cancel();
                            scaffoldMessenger.hideCurrentSnackBar();
                            await SystemChannels.platform
                                .invokeMethod('SystemNavigator.pop');
                            return true;
                          }
                          allowMinimizeApp = true;
                          allowMinimizeAppTimer?.reset();
                          scaffoldMessenger.hideCurrentSnackBar();
                          scaffoldMessenger.showSnackBar(snackBar);
                          return false;
                        },
                        child: InAppWebView(
                          key: webViewKey,
                          initialUrlRequest:
                              URLRequest(url: Uri.parse(initialUrl)),
                          initialOptions: options,
                          pullToRefreshController: pullToRefreshController,
                          onWebViewCreated: (controller) async {
                            _webViewController = controller;
                            await Future.delayed(Duration.zero);
                            final args = ModalRoute.of(context)!
                                .settings
                                .arguments as WebAppArguments?;
                            if (args != null && args.forcePath.isNotEmpty) {
                              final path = args.forcePath;
                              _pathForced = path;
                              controller.loadUrl(
                                  urlRequest: URLRequest(
                                      url: Uri.parse(
                                          await getEverglotUrl(path: path))));
                            }
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
                            if (!url
                                .startsWith(await getEverglotUrl(path: ""))) {
                              if (url
                                  .startsWith("https://survey.everglot.com/")) {
                                // Launch survey links externally.
                                await launch(
                                  url,
                                );
                              }
                              return NavigationActionPolicy.CANCEL;
                            }

                            return NavigationActionPolicy.ALLOW;
                          },
                          onLoadStop: (controller, uri) async {
                            pullToRefreshController.endRefreshing();
                            final url = uri.toString();
                            setState(() {
                              this.url = url;
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
                              (controller, uri, androidIsReload) async {
                            final url = uri.toString();
                            setState(() {
                              this.url = url;
                              urlController.text = this.url;
                            });
                            // Prevent /login and /join routes from showing.
                            if (url.startsWith(
                                    await getEverglotUrl(path: "/join")) ||
                                url.startsWith(
                                    await getEverglotUrl(path: "/login"))) {
                              print(
                                  "Logged out state detected, switching to login screen and removing stored cookie");
                              await removeStoredSessionCookie();

                              await Navigator.popAndPushNamed(
                                  context, LoginPage.routeName,
                                  arguments:
                                      LoginPageArguments(true, uri!.path));
                            }
                            print("Visited URL: $url");
                          },
                          onConsoleMessage: (controller, consoleMessage) {
                            print(consoleMessage);
                          },
                        ))));
          }
          return Scaffold();
        });
  }
}
