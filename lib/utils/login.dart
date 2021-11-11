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
  //   debugPrint("Using Android client ID");
  //   return GOOGLE_CLIENT_ID_ANDROID;
  // }
  if (Platform.isIOS) {
    if (kDebugMode) {
      debugPrint("Using iOS client ID");
    }
    return EverglotGoogleClient.idIOS;
  }
  if (kDebugMode) {
    debugPrint("Using web client ID");
  }
  return EverglotGoogleClient.idWeb;
}

Future<http.Response> tryGoogleLogin(String idToken) async {
  if (kDebugMode) {
    debugPrint("tryGoogleLogin");
  }
  final loginUrl = await getEverglotUrl(path: "/login");
  return http.post(Uri.parse(loginUrl),
      body: jsonEncode({
        "method": EverglotAuthMethod.google,
        "idToken": idToken,
        "generateRefreshToken": true
      }),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      });
}

Future<http.Response> tryEmailLogin(String email, String password) async {
  if (kDebugMode) {
    debugPrint("tryEmailLogin");
  }
  final loginUrl = await getEverglotUrl(path: "/login");
  return http.post(Uri.parse(loginUrl),
      body: jsonEncode({
        "method": EverglotAuthMethod.email,
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
    debugPrint("tryGoogleSignUp");
  }
  final loginUrl = await getEverglotUrl(path: "/join");
  return http.post(Uri.parse(loginUrl),
      body: jsonEncode({
        "method": EverglotAuthMethod.google,
        "idToken": idToken,
        "token": Platform.isIOS
            ? EverglotSignupToken.ios
            : (Platform.isAndroid ? EverglotSignupToken.android : null),
        "generateRefreshToken": true
      }),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      });
}

Future<http.Response> tryEmailSignUp(String email, String password) async {
  if (kDebugMode) {
    debugPrint("tryEmailSignUp");
  }
  final loginUrl = await getEverglotUrl(path: "/join");
  return http.post(Uri.parse(loginUrl),
      body: jsonEncode({
        "method": EverglotAuthMethod.email,
        "email": email,
        "password": password,
        "token": Platform.isIOS
            ? EverglotSignupToken.ios
            : (Platform.isAndroid ? EverglotSignupToken.android : null),
        "generateRefreshToken": true
      }),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      });
}

Future<void> tryRegisterFcmToken(String fcmToken, String cookieHeader) async {
  if (kDebugMode) {
    debugPrint("tryRegisterFcmToken");
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
        debugPrint("Successfully registered FCM token with Everglot!");
      } else {
        debugPrint(
            "Registering FCM token with Everglot failed: ${response.body}");
      }
    }
  }).onError((error, stackTrace) {
    if (kDebugMode) {
      debugPrint('FCM token registration request produced an error');
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
    debugPrint("Setting session cookie: " + cookieHeader);
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
    {String name = EverglotSessionIdCookie.name}) async {
  final cookieManager = _getCookieManager();

  final url = await getEverglotUrl(path: "/login");
  final cookie = await cookieManager.getCookie(url: Uri.parse(url), name: name);

  if (cookie == null) {
    return null;
  }

  if (kDebugMode) {
    debugPrint(
        "Retrieved stored session cookie for URL $url: " + cookie.toString());
  }
  return cookie;
}

Future<void> removeStoredSessionCookie(
    {String name = EverglotSessionIdCookie.name}) async {
  final cookieManager = _getCookieManager();

  final url = await getEverglotUrl(path: "/login");
  if (kDebugMode) {
    debugPrint(
        "Removing any stored session cookie for URL $url and name $name");
  }
  await cookieManager.deleteCookie(url: Uri.parse(url), name: name);
}

const refreshTokenKey = 'REFRESH_TOKEN';
Future<void> registerRefreshToken(String refreshToken) async {
  if (kDebugMode) {
    debugPrint("Storing refresh token: $refreshToken");
  }
  const storage = FlutterSecureStorage();
  const iOptions = IOSOptions(accessibility: IOSAccessibility.first_unlock);
  try {
    await storage.write(
        key: refreshTokenKey, value: refreshToken, iOptions: iOptions);
  } catch (e) {
    if (kDebugMode) {
      debugPrint("Failed to store refresh token in secure storage: $e");
    }
  }
}

Future<String?> getRefreshToken() async {
  if (kDebugMode) {
    debugPrint("Retrieving refresh token");
  }
  const storage = FlutterSecureStorage();
  const iOptions = IOSOptions(accessibility: IOSAccessibility.first_unlock);
  try {
    return await storage.read(key: refreshTokenKey, iOptions: iOptions);
  } catch (e) {
    if (kDebugMode) {
      debugPrint("Failed to retrieve refresh token from secure storage: $e");
    }
    return null;
  }
}

Future<void> removeRefreshToken() async {
  if (kDebugMode) {
    debugPrint("Retrieving refresh token");
  }
  const storage = FlutterSecureStorage();
  const iOptions = IOSOptions(accessibility: IOSAccessibility.first_unlock);
  try {
    await storage.delete(key: refreshTokenKey, iOptions: iOptions);
  } catch (e) {
    if (kDebugMode) {
      debugPrint("Failed to remove refresh token from secure storage: $e");
    }
  }
}

Future<http.Response> trySignInWithRefreshToken(String refreshToken) async {
  if (kDebugMode) {
    debugPrint("trySignInWithRefreshToken");
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
      debugPrint("Error during auth refresh: $e");
    }
    return false;
  }
  final int statusCode = response.statusCode;

  if (statusCode != 200) {
    if (kDebugMode) {
      debugPrint(
          "Status code 200 expected during auth refresh, got $statusCode");
    }
    return false;
  }

  // We just used it up, make sure it's gone for good.
  await removeRefreshToken();

  final jsonResponse = json.decode(response.body);
  if (jsonResponse == null || jsonResponse["success"] != true) {
    if (kDebugMode) {
      debugPrint(
          "Auth refresh response is invalid or indicates failure: ${response.body}");
    }
    return false;
  }

  if (kDebugMode) {
    debugPrint("Auth refresh API call successful");
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
      debugPrint("Something went wrong, cannot get session cookie.");
    }
    return false;
  }
  await registerSessionCookie(cookieHeader, response.request!.url);
  return true;
}
