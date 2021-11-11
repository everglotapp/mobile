import 'package:everglot/constants.dart';
import 'package:everglot/jobs/types.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'package:everglot/utils/login.dart';
import 'package:everglot/utils/notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';

Future<bool> syncFcmToken(dynamic inputData) async {
  await Firebase.initializeApp();
  final refreshToken = await getRefreshToken();
  if (refreshToken == null) {
    if (kDebugMode) {
      debugPrint("No refresh token, app has probably never signed in");
    }
    scheduleNextIOSJob();
    return true;
  }
  try {
    if (JwtDecoder.isExpired(refreshToken)) {
      if (kDebugMode) {
        debugPrint(
            "Refresh token has expired, cannot use it to synchronize FCM token");
      }
      scheduleNextIOSJob();
      return true;
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint(
          "Failed to check if refresh token has expired, it seems to not even be a valid JWT.");
    }

    scheduleNextIOSJob();
    return true;
  }

  if (!await reauthenticate(refreshToken)) {
    if (kDebugMode) {
      debugPrint(
          "Reauthentication failed, FCM token synchronization is impossible.");
    }

    scheduleNextIOSJob();
    return false;
  }

  final fcmToken = await getFcmToken();
  if (fcmToken == null || fcmToken.isEmpty) {
    if (kDebugMode) {
      debugPrint("Device has no FCM token, synchronization is impossible.");
    }
    scheduleNextIOSJob();
    return false;
  }
  final sessionIdCookie = await getStoredSessionCookie();
  if (sessionIdCookie == null) {
    debugPrint(
        "Could not get session ID even though just reauthenticated, FCM token synchronization is impossible.");
    scheduleNextIOSJob();
    return false;
  }
  try {
    if (kDebugMode) {
      debugPrint(
          "Synchronizing FCM token after successful refresh authentication");
    }
    await tryRegisterFcmToken(
        fcmToken, "${EverglotSessionIdCookie.name}=${sessionIdCookie.value}");
  } catch (e) {
    if (kDebugMode) {
      debugPrint("Error during FCM token registration: $e");
    }
    scheduleNextIOSJob();
    return false;
  }
  scheduleNextIOSJob();
  return true;
}

void scheduleNextIOSJob() {
  if (Platform.isIOS) {
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
