import 'package:flutter/foundation.dart';

class EverglotGoogleClient {
  static const idIOS =
      "457984069949-79sdutia34vvkn2fcetcq1sblmhe38gk.apps.googleusercontent.com";
  static const idAndroid =
      "457984069949-5giaecr690rps0g9f5unj0j5j1qt22ck.apps.googleusercontent.com";
  static const idWeb =
      "457984069949-bgc3aj14fi47olkp0arn7is4cr07cfla.apps.googleusercontent.com";
}

class EverglotAuthMethod {
  static const google = "google";
  static const email = "email";
}

class EverglotSignupToken {
  static const ios = "AyMUWmgUV6YmszfDN9oPZ5qgsBGYaUN3RoCcNBgGdDmJ";
  static const android = "35xMXbwHguV1KERp9jJ8CYiUbcXPNJtighC3oqwnATed";
}

class EverglotSessionIdCookie {
  static const headerNameSuffix = "everglot_sid";
  // __Host- prefix requires HTTPS which we don't want to enforce in dev
  static const headerName =
      kDebugMode ? headerNameSuffix : "__Host-$headerNameSuffix";
}
