import 'dart:io';
import 'package:everglot/login.dart';
import 'package:everglot/utils/login.dart';
import 'package:everglot/utils/webapp.dart';
import 'package:everglot/utils/ui.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class WebAppArguments {
  String forcePath = "";

  WebAppArguments(this.forcePath);
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
                  onWebViewCreated: (controller) async {
                    webViewController = controller;
                    await Future.delayed(Duration.zero);
                    final args = ModalRoute.of(context)!.settings.arguments;
                    if (args != null &&
                        (args as WebAppArguments).forcePath.isNotEmpty) {
                      final path = args.forcePath;
                      controller.loadUrl(
                          urlRequest: URLRequest(
                              url:
                                  Uri.parse(await getEverglotUrl(path: path))));
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
                    if (!url.startsWith(await getEverglotUrl(path: ""))) {
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
                    if (url.startsWith(await getEverglotUrl(path: "/join")) ||
                        url.startsWith(await getEverglotUrl(path: "/login"))) {
                      print(
                          "Logged out state detected, switching to login screen and removing stored cookie");
                      await removeStoredSessionCookie();

                      await Navigator.popAndPushNamed(context, "/",
                          arguments: LoginPageArguments(true));
                    }
                    print("Visited URL: $url");
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    print(consoleMessage);
                  },
                )));
          }
          return Scaffold();
        });
  }
}
