import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

Future<String> getEverglotUrl({String path = '/'}) async {
  if (kDebugMode && Platform.isAndroid) {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    if (androidInfo.isPhysicalDevice == true) {
      print(
          'Running on ${androidInfo.model} which is a physical Android device');
      return 'http://192.168.178.88:8002' + path;
    } else {
      print('Running on ${androidInfo.model} which is an Android emulator');
      return 'http://10.0.2.2:8002' + path;
    }
  }
  return 'https://app.everglot.com' + path;
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
