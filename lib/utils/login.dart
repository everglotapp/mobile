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
  print("tryGoogleLogin");
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
  print("tryEmailLogin");
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

Future<http.Response> tryGoogleSignUp(String idToken) async {
  print("tryGoogleSignUp");
  final loginUrl = await getEverglotUrl(path: "/join");
  return http.post(Uri.parse(loginUrl),
      body: jsonEncode({
        "method": EVERGLOT_AUTH_METHOD_GOOGLE,
        "idToken": idToken,
        "token": Platform.isIOS
            ? EVERGLOT_SIGN_UP_TOKEN_IOS
            : (Platform.isAndroid ? EVERGLOT_SIGN_UP_TOKEN_ANDROID : null),
      }),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      });
}

Future<http.Response> tryEmailSignUp(String email, String password) async {
  print("tryEmailSignUp");
  final loginUrl = await getEverglotUrl(path: "/join");
  return http.post(Uri.parse(loginUrl),
      body: jsonEncode({
        "method": EVERGLOT_AUTH_METHOD_EMAIL,
        "email": email,
        "password": password,
        "token": Platform.isIOS
            ? EVERGLOT_SIGN_UP_TOKEN_IOS
            : (Platform.isAndroid ? EVERGLOT_SIGN_UP_TOKEN_ANDROID : null),
      }),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      });
}

Future<void> tryRegisterFcmToken(String fcmToken, String cookieHeader) async {
  final fcmTokenRegistrationUrl =
      await getEverglotUrl(path: "/users/fcm-token/register/$fcmToken");
  http.post(
    Uri.parse(fcmTokenRegistrationUrl),
    headers: {
      HttpHeaders.cookieHeader: cookieHeader,
    },
  ).then((http.Response response) {
    final int statusCode = response.statusCode;

    if (statusCode == 200) {
      print("Successfully registered FCM token with Everglot!");
    } else {
      print("Registering FCM token with Everglot failed: ${response.body}");
    }
  }).onError((error, stackTrace) {
    print('FCM token registration request produced an error');
    return Future.error("FCM token registration request produced an error");
  });
}

inappwebview.CookieManager _getCookieManager() {
  return inappwebview.CookieManager.instance();
}

Future<void> registerSessionCookie(String cookieHeader, Uri url) async {
  final cookieManager = _getCookieManager();
  // set the expiration date for the cookie in milliseconds
  final defaultExpiryMs =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;

  if (kDebugMode) {
    print("Setting session cookie: " + cookieHeader);
  }
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
    {String name = everglotSessionIdCookieHeaderName}) async {
  final cookieManager = _getCookieManager();

  final url = await getEverglotUrl(path: "/login");
  final cookie = await cookieManager.getCookie(url: Uri.parse(url), name: name);

  if (cookie == null) {
    return null;
  }

  if (kDebugMode) {
    print("Retrieved stored session cookie for URL $url: " + cookie.toString());
  }
  return cookie;
}

Future<inappwebview.Cookie?> removeStoredSessionCookie(
    {String name = everglotSessionIdCookieHeaderName}) async {
  final cookieManager = _getCookieManager();

  final url = await getEverglotUrl(path: "/login");
  if (kDebugMode) {
    print("Removing any stored session cookie for URL $url and name $name");
  }
  await cookieManager.deleteCookie(url: Uri.parse(url), name: name);
}
