import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:everglot/utils/webapp.dart';
import 'package:everglot/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as inappwebview;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

String getGoogleClientId() {
  // Causes Platform exception 10
  // if (Platform.isAndroid) {
  //   print("Using Android client ID");
  //   return GOOGLE_CLIENT_ID_ANDROID;
  // }
  if (Platform.isIOS) {
    if (kDebugMode) {
      print("Using iOS client ID");
    }
    return GOOGLE_CLIENT_ID_IOS;
  }
  if (kDebugMode) {
    print("Using web client ID");
  }
  return GOOGLE_CLIENT_ID_WEB;
}

Future<http.Response> tryGoogleLogin(String idToken) async {
  if (kDebugMode) {
    print("tryGoogleLogin");
  }
  final loginUrl = await getEverglotUrl(path: "/login");
  return http.post(Uri.parse(loginUrl),
      body: jsonEncode({
        "method": EVERGLOT_AUTH_METHOD_GOOGLE,
        "idToken": idToken,
        "generateRefreshToken": true
      }),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      });
}

Future<http.Response> tryEmailLogin(String email, String password) async {
  if (kDebugMode) {
    print("tryEmailLogin");
  }
  final loginUrl = await getEverglotUrl(path: "/login");
  return http.post(Uri.parse(loginUrl),
      body: jsonEncode({
        "method": EVERGLOT_AUTH_METHOD_EMAIL,
        "email": email,
        "password": password,
        "generateRefreshToken": true
      }),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      });
}

Future<http.Response> tryGoogleSignUp(String idToken) async {
  if (kDebugMode) {
    print("tryGoogleSignUp");
  }
  final loginUrl = await getEverglotUrl(path: "/join");
  return http.post(Uri.parse(loginUrl),
      body: jsonEncode({
        "method": EVERGLOT_AUTH_METHOD_GOOGLE,
        "idToken": idToken,
        "token": Platform.isIOS
            ? EVERGLOT_SIGN_UP_TOKEN_IOS
            : (Platform.isAndroid ? EVERGLOT_SIGN_UP_TOKEN_ANDROID : null),
        "generateRefreshToken": true
      }),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      });
}

Future<http.Response> tryEmailSignUp(String email, String password) async {
  if (kDebugMode) {
    print("tryEmailSignUp");
  }
  final loginUrl = await getEverglotUrl(path: "/join");
  return http.post(Uri.parse(loginUrl),
      body: jsonEncode({
        "method": EVERGLOT_AUTH_METHOD_EMAIL,
        "email": email,
        "password": password,
        "token": Platform.isIOS
            ? EVERGLOT_SIGN_UP_TOKEN_IOS
            : (Platform.isAndroid ? EVERGLOT_SIGN_UP_TOKEN_ANDROID : null),
        "generateRefreshToken": true
      }),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      });
}

Future<void> tryRegisterFcmToken(String fcmToken, String cookieHeader) async {
  if (kDebugMode) {
    print("tryRegisterFcmToken");
  }
  final fcmTokenRegistrationUrl =
      await getEverglotUrl(path: "/users/fcm-token/register/$fcmToken");
  http.post(
    Uri.parse(fcmTokenRegistrationUrl),
    headers: {
      HttpHeaders.cookieHeader: cookieHeader,
    },
  ).then((http.Response response) {
    final int statusCode = response.statusCode;
    if (kDebugMode) {
      if (statusCode == 200) {
        print("Successfully registered FCM token with Everglot!");
      } else {
        print("Registering FCM token with Everglot failed: ${response.body}");
      }
    }
  }).onError((error, stackTrace) {
    if (kDebugMode) {
      print('FCM token registration request produced an error');
    }
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

const refreshTokenKey = 'REFRESH_TOKEN';
Future<void> registerRefreshToken(String refreshToken) async {
  if (kDebugMode) {
    print("Storing refresh token: $refreshToken");
  }
  const storage = FlutterSecureStorage();
  const iOptions = IOSOptions(accessibility: IOSAccessibility.first_unlock);
  try {
    await storage.write(
        key: refreshTokenKey, value: refreshToken, iOptions: iOptions);
  } catch (e) {
    if (kDebugMode) {
      print("Failed to store refresh token in secure storage: $e");
    }
  }
}

Future<String?> getRefreshToken() async {
  if (kDebugMode) {
    print("Retrieving refresh token");
  }
  const storage = FlutterSecureStorage();
  const iOptions = IOSOptions(accessibility: IOSAccessibility.first_unlock);
  try {
    return await storage.read(key: refreshTokenKey, iOptions: iOptions);
  } catch (e) {
    if (kDebugMode) {
      print("Failed to retrieve refresh token from secure storage: $e");
    }
    return null;
  }
}

Future<void> removeRefreshToken() async {
  if (kDebugMode) {
    print("Retrieving refresh token");
  }
  const storage = FlutterSecureStorage();
  const iOptions = IOSOptions(accessibility: IOSAccessibility.first_unlock);
  try {
    await storage.delete(key: refreshTokenKey, iOptions: iOptions);
  } catch (e) {
    if (kDebugMode) {
      print("Failed to remove refresh token from secure storage: $e");
    }
  }
}

Future<http.Response> trySignInWithRefreshToken(String refreshToken) async {
  if (kDebugMode) {
    print("trySignInWithRefreshToken");
  }
  final refreshUrl = await getEverglotUrl(path: "/auth/refresh");
  return http.post(Uri.parse(refreshUrl),
      body: jsonEncode({"refreshToken": refreshToken}),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      });
}

Future<bool> reauthenticate(String refreshToken) async {
  http.Response response;
  try {
    response = await trySignInWithRefreshToken(refreshToken);
  } catch (e) {
    if (kDebugMode) {
      print("Error during auth refresh: $e");
    }
    return false;
  }
  final int statusCode = response.statusCode;

  if (statusCode != 200) {
    if (kDebugMode) {
      print("Status code 200 expected during auth refresh, got $statusCode");
    }
    return false;
  }

  // We just used it up, make sure it's gone for good.
  await removeRefreshToken();

  final jsonResponse = json.decode(response.body);
  if (jsonResponse == null || jsonResponse["success"] != true) {
    if (kDebugMode) {
      print(
          "Auth refresh response is invalid or indicates failure: ${response.body}");
    }
    return false;
  }

  if (kDebugMode) {
    print("Auth refresh API call successful");
  }

  if (jsonResponse["refreshToken"] is String) {
    final refreshToken = jsonResponse["refreshToken"] as String;
    if (refreshToken.isNotEmpty) {
      await registerRefreshToken(refreshToken);
    }
  }

  // If response.json.success login succeeded
  final cookieHeader = response.headers[HttpHeaders.setCookieHeader];
  if (cookieHeader == null) {
    if (kDebugMode) {
      print("Something went wrong, cannot get session cookie.");
    }
    return false;
  }
  await registerSessionCookie(cookieHeader, response.request!.url);
  return true;
}
