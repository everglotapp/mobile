import 'package:flutter/foundation.dart';

class Messaging with ChangeNotifier {
  String? _fcmToken;

  String? get fcmToken => _fcmToken;
  set fcmToken(String? newValue) {
    _fcmToken = newValue;
    notifyListeners();
  }
}
