import 'dart:io';

import 'package:everglot/app.dart';
import 'package:everglot/jobs/dispatcher.dart';
import 'package:everglot/jobs/sync_fcm_token.dart';
import 'package:everglot/jobs/types.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  // Do not add anything before the below line.
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.grey[50],
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(
        kDebugMode);
  }
  await Permission.camera.request();
  await Permission.microphone.request();
  runApp(const App());
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: kDebugMode,
  );
  registerFcmTokenSyncTask();
}

Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
}

void registerFcmTokenSyncTask() {
  if (Platform.isAndroid) {
    Workmanager().registerPeriodicTask(
      "SYNC_FCM_TOKEN",
      jobTypes[JobType.syncFcmToken]!,
      frequency: const Duration(days: 7),
      constraints: Constraints(
        // connected or metered mark the task as requiring internet
        networkType: NetworkType.connected,
        // do not require external power
        requiresCharging: false,
      ),
    );
  } else if (Platform.isIOS) {
    // TODO: Figure out what this duration should be and how to figure it out
    Workmanager().registerOneOffTask(
      "SYNC_FCM_TOKEN", // Ignored on iOS
      jobTypes[JobType.syncFcmToken]!, // Ignored on iOS
      initialDelay: const Duration(days: 7),
      constraints: Constraints(
        // connected or metered mark the task as requiring internet
        networkType: NetworkType.connected,
        // do not require external power
        requiresCharging: false,
      ),
    );
  }
}
