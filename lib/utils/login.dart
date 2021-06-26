import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:everglot/utils/webapp.dart';
import 'package:everglot/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as inappwebview;

String getGoogleClientId() {
  // Causes Platform exception 10
  // if (Platform.isAndroid) {
  //   print("Using Android client ID");
  //   return GOOGLE_CLIENT_ID_ANDROID;
  // }
  if (Platform.isIOS) {
    print("Using iOS client ID");
    return GOOGLE_CLIENT_ID_IOS;
  }
  print("Using web client ID");
  return GOOGLE_CLIENT_ID_WEB;
}

Future<http.Response> tryGoogleLogin(String idToken) async {
  final loginUrl = await getEverglotUrl(path: "/login");
  return http.post(Uri.parse(loginUrl),
      body: jsonEncode({
        "method": EVERGLOT_AUTH_METHOD_GOOGLE,
        "idToken": idToken,
      }),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      });
}

Future<http.Response> tryEmailLogin(String email, String password) async {
  final loginUrl = await getEverglotUrl(path: "/login");
  return http.post(Uri.parse(loginUrl),
      body: jsonEncode({
        "method": EVERGLOT_AUTH_METHOD_EMAIL,
        "email": email,
        "password": password,
      }),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      });
}

Future<void> tryRegisterFcmToken(String fcmToken, String cookieHeader) async {
  final fcmTokenRegistrationUrl =
      await getEverglotUrl(path: "/users/fcm-token/register/" + fcmToken);
  http.post(Uri.parse(fcmTokenRegistrationUrl), headers: {
    HttpHeaders.cookieHeader: cookieHeader
  }).then((http.Response response) {
    final int statusCode = response.statusCode;

    if (statusCode == 200) {
      print("Successfully registered FCM token with Everglot!");
    } else {
      print("Registering FCM token with Everglot failed: " + response.body);
    }
  }).onError((error, stackTrace) {
    print('FCM token registration request produced an error');
    return Future.value();
  });
}

inappwebview.CookieManager _getCookieManager() {
  return inappwebview.CookieManager.instance();
}

Future<void> registerSessionCookie(String cookieHeader, Uri url) async {
  final cookieManager = _getCookieManager();
  // set the expiration date for the cookie in milliseconds
  final defaultExpiryMs =
      DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch;

  final cookie = Cookie.fromSetCookieValue(cookieHeader);
  await cookieManager.setCookie(
    url: url,
    path: cookie.path ?? "/",
    name: cookie.name,
    value: cookie.value,
    domain: cookie.domain,
    expiresDate: cookie.expires == null
        ? defaultExpiryMs
        : cookie.expires!.millisecondsSinceEpoch,
    isSecure: !kDebugMode,
  );
}

Future<inappwebview.Cookie?> getStoredSessionCookie(
    {String name = EVERGLOT_SESSION_COOKIE_HEADER_NAME}) async {
  final cookieManager = _getCookieManager();

  final cookie = await cookieManager.getCookie(
      url: Uri.parse(await getEverglotUrl(path: "/login")), name: name);

  if (cookie == null) {
    return null;
  }
  print(cookie.toString());
  return cookie;
}

Future<inappwebview.Cookie?> removeStoredSessionCookie(
    {String name = EVERGLOT_SESSION_COOKIE_HEADER_NAME}) async {
  final cookieManager = _getCookieManager();

  await cookieManager.deleteCookie(
      url: Uri.parse(await getEverglotUrl(path: "/login")), name: name);
}
