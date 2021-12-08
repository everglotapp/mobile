import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

Future<String> getEverglotProtocol() async {
  if (kDebugMode && Platform.isAndroid) {
    return 'http';
  }
  return 'https';
}

Future<String> getEverglotDomain() async {
  if (kDebugMode && Platform.isAndroid) {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    if (androidInfo.isPhysicalDevice == true) {
      return '192.168.178.88';
    } else {
      return '10.0.2.2';
    }
  }
  return 'app.everglot.com';
}

Future<int?> getEverglotPort() async {
  if (kDebugMode && Platform.isAndroid) {
    return 3000;
  }
  return null;
}

Future<String> getEverglotUrl({String path = '/'}) async {
  final proto = await getEverglotProtocol();
  final domain = await getEverglotDomain();
  final port = await getEverglotPort();
  return "$proto://$domain${port == null ? '' : ":$port"}$path";
}

String getChatPath(String groupUuid) {
  return "/chat?group=$groupUuid";
}

String getSqueekPath(String snowflakeId) {
  return "/s/$snowflakeId";
}

String getUserProfilePath(String username) {
  return "/u/$username";
}

String getWebviewUserAgent() {
  if (Platform.isAndroid) {
    return "ANDROID_WEBVIEW";
  }
  if (Platform.isIOS) {
    return "IOS_WEBVIEW";
  }
  return "MOBILE_APP_WEBVIEW";
}
