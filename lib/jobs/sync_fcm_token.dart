import 'package:everglot/constants.dart';
import 'package:everglot/utils/login.dart';
import 'package:everglot/utils/notifications.dart';
import 'package:firebase_core/firebase_core.dart';

Future<bool> syncFcmToken(dynamic inputData) async {
  await Firebase.initializeApp();
  final fcmToken = await getFcmToken();
  if (fcmToken == null || fcmToken.isEmpty) {
    // Device has no FCM token, refresh is impossible.
    return true;
  }
  final sessionIdCookie = await getStoredSessionCookie();
  if (sessionIdCookie == null) {
    // Client can't possibly be signed in, refresh is impossible.
    return true;
  }
  await tryRegisterFcmToken(fcmToken,
          "$everglotSessionIdCookieHeaderName=${sessionIdCookie.value}")
      .catchError((e) {
    print(e);
  });
  return true;
}
