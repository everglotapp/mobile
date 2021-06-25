import 'dart:convert';
import 'dart:io';

import 'package:everglot/constants.dart';
import 'package:everglot/main.dart';
import 'package:everglot/state/messaging.dart';
import 'package:everglot/utils/webapp.dart';
import 'package:everglot/webapp.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auth_buttons/auth_buttons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show CookieManager;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:email_validator/email_validator.dart';

String _getGoogleClientId() {
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

Future<http.Response> _tryGoogleLogin(String idToken) async {
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

Future<http.Response> _tryEmailLogin(String email, String password) async {
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

Future<void> _tryRegisterFcmToken(String fcmToken, String cookieHeader) async {
  final fcmTokenRegistrationUrl =
      await getEverglotUrl(path: "/users/fcm-token/register/" + fcmToken);
  http.post(Uri.parse(fcmTokenRegistrationUrl), headers: {
    HttpHeaders.cookieHeader: cookieHeader
  }).then((http.Response response) {
    final int statusCode = response.statusCode;

    if (statusCode == 200) {
      print("Successfully registered FCM token with Everglot!");
    } else {
      print("Registering FCM token with Everglot failed: " + response.body);
    }
  }).onError((error, stackTrace) {
    print('FCM token registration request produced an error');
    return Future.value();
  });
}

Future<void> _registerSessionCookie(String cookieHeader, Uri url) async {
  CookieManager cookieManager = CookieManager.instance();
  // set the expiration date for the cookie in milliseconds
  final defaultExpiryMs =
      DateTime.now().add(Duration(days: 3)).millisecondsSinceEpoch;

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

class LoginPageArguments {
  bool signedOut = false;

  LoginPageArguments(this.signedOut);
}

class LoginPage extends StatefulWidget {
  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  // GoogleSignInAccount? _currentUser;
  GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: _getGoogleClientId(),
    scopes: <String>[
      'email',
    ],
  );
  Messaging? _messaging;
  bool _passwordHidden = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen(handleCurrentUserChanged);
    autoSignInOrOut();
    _messaging = Provider.of<Messaging>(context, listen: false);

    SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);
  }

  void dispose() {
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void handleCurrentUserChanged(GoogleSignInAccount? account) async {
    // setState(() {
    //   _currentUser = account;
    // });
    if (account == null) {
      print("null account");
    } else {
      // Successfully logged in via Google.
      final authentication = await account.authentication;
      if (authentication.idToken != null) {
        if (_messaging != null && _messaging!.fcmToken != null) {
          _tryGoogleLogin(authentication.idToken!)
              .then((http.Response response) async {
            final int statusCode = response.statusCode;

            if (statusCode == 200) {
              final jsonResponse = json.decode(response.body);
              if (jsonResponse != null && jsonResponse["success"] == true) {
                final cookieHeader =
                    response.headers[HttpHeaders.setCookieHeader];
                if (cookieHeader == null) {
                  print("Something went wrong, cannot get session cookie.");
                } else {
                  print(
                      "Signed in to Everglot via Google. Will now try to register FCM token.");
                  _tryRegisterFcmToken(_messaging!.fcmToken!, cookieHeader);
                  _registerSessionCookie(cookieHeader, response.request!.url);
                  await Navigator.pushReplacementNamed(context, "/webapp",
                      arguments:
                          GoogleSignInArguments(authentication.idToken!));
                }
                return;
              }
            }
            final jsonResponse = json.decode(response.body);
            if (jsonResponse != null &&
                jsonResponse["success"] == false &&
                jsonResponse["message"] != null) {
              setState(() {
                _feedback = jsonResponse["message"];
              });
            }
            print("Signing into Everglot failed: " + response.body);
          }).onError((error, stackTrace) {
            print('Login request produced an error');
            return Future.value();
          });
        }
        await Navigator.pushReplacementNamed(context, "/webapp",
            arguments: GoogleSignInArguments(authentication.idToken as String));
      }
    }
  }

  Future<void> autoSignInOrOut() async {
    await Future.delayed(Duration.zero);
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args != null && (args as LoginPageArguments).signedOut) {
      _googleSignIn.signOut();
    } else {
      try {
        await _googleSignIn.signInSilently();
      } catch (error) {
        print("Automatic silent Google sign in failed: " + error.toString());
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() {
        _feedback = null;
      });
      await _googleSignIn.signIn();
    } catch (error) {
      print("Google sign in failed: " + error.toString());
    }
  }

  // Future<void> _handleGoogleSignOut() => _googleSignIn.disconnect();

  Future<void> _handleEmailSignIn() async {
    setState(() {
      _feedback = null;
    });
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final email = _emailController.text;
    final password = _passwordController.text;
    _tryEmailLogin(email, password).then((http.Response response) async {
      final int statusCode = response.statusCode;

      if (statusCode == 200) {
        // If response.json.success login succeeded
        final jsonResponse = json.decode(response.body);
        if (jsonResponse != null && jsonResponse["success"] == true) {
          final cookieHeader = response.headers[HttpHeaders.setCookieHeader];
          if (cookieHeader == null) {
            print("Something went wrong, cannot get session cookie.");
          } else {
            print(
                "Successfully signed in to Everglot via email. Will now try to register FCM token.");
            _tryRegisterFcmToken(_messaging!.fcmToken!,
                response.headers[HttpHeaders.setCookieHeader] ?? "");
            _registerSessionCookie(cookieHeader, response.request!.url);
            await Navigator.pushReplacementNamed(context, "/webapp",
                arguments: EmailSignInArguments(email, password));
            return;
          }
        }
      }
      print("Signing into Everglot failed: " + response.body);
      final jsonResponse = json.decode(response.body);
      print(jsonResponse);
      if (jsonResponse != null &&
          jsonResponse["success"] == false &&
          jsonResponse["message"] != null) {
        setState(() {
          _feedback = jsonResponse["message"];
        });
      }
      // TODO: If 302, set initial URL to redirected URL

      //  if (response && response.redirected && response.url && response.url.length) {
      //     console.log("Login HTTP request succeeded with redirect to "+ response.url);
      //     history.replaceState(null, '', response.url);
      //     return;
      //   }
      //   response.json().then(function (res) {
      //     console.log(JSON.stringify(res));
      //     if (res && res.success) {
      //       WebViewLoginState.postMessage("1");
      //     } else {
      //       WebViewLoginState.postMessage("0");
      //     }
      //   }).catch(function (e) {
      //     console.log("Failed to parse response as JSON", res, e);
      //       WebViewLoginState.postMessage("0");
      //   });
    });
    // TODO: Only push this upon success
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom != 0;
    return SafeArea(
        child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: Container(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                  keyboardVisible
                      ? SizedBox.shrink()
                      : Flexible(
                          flex: 2,
                          fit: FlexFit.loose,
                          child: Container(
                              height: 96,
                              width: 96,
                              decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(96)),
                              child: Center(
                                  child: Text("EVG",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24))))),
                  Flexible(
                      flex: 3,
                      fit: FlexFit.loose,
                      child: Container(
                          margin: keyboardVisible
                              ? EdgeInsetsDirectional.zero
                              : EdgeInsetsDirectional.only(top: 0, bottom: 18),
                          child: ConstrainedBox(
                              constraints:
                                  BoxConstraints.tight(Size.fromHeight(110)),
                              child: Column(children: [
                                Flexible(
                                  flex: 1,
                                  fit: FlexFit.tight,
                                  child: Text("Everglot",
                                      style: GoogleFonts.poppins(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w600)),
                                ),
                                Flexible(
                                    flex: 1,
                                    fit: FlexFit.tight,
                                    child: Text("Learn Together",
                                        style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600))),
                              ])))),
                  Flexible(
                      flex: 3,
                      fit: FlexFit.tight,
                      child: Form(
                          key: _formKey,
                          child: Container(
                              margin: EdgeInsetsDirectional.only(
                                  start: 16, end: 16),
                              child: Column(children: [
                                TextFormField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(32)),
                                      labelStyle: GoogleFonts.poppins(),
                                      fillColor: Colors.grey[100],
                                      filled: true,
                                      contentPadding:
                                          EdgeInsetsDirectional.only(
                                              start: 18,
                                              end: 18,
                                              top: 4,
                                              bottom: 4),
                                      labelText: 'Email'),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) =>
                                      (value == null || value.isEmpty)
                                          ? "Please enter an email"
                                          : EmailValidator.validate(value)
                                              ? null
                                              : "Please enter a valid email",
                                ),
                                Container(height: 4),
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(32)),
                                    labelStyle: GoogleFonts.poppins(),
                                    fillColor: Colors.grey[100],
                                    filled: true,
                                    contentPadding: EdgeInsetsDirectional.only(
                                        start: 18, end: 18, top: 4, bottom: 4),
                                    labelText: 'Password',
                                    suffix: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _passwordHidden = !_passwordHidden;
                                        });
                                      },
                                      child: Text(
                                          _passwordHidden ? "Show" : "Hide",
                                          style: GoogleFonts.poppins(
                                              color: primary, fontSize: 14)),
                                    ),
                                  ),
                                  obscureText: _passwordHidden,
                                  validator: (value) => (value == null ||
                                          value.isEmpty)
                                      ? "Please enter a password"
                                      : (value.length < 8
                                          ? "Passwords must be at least 8 characters long"
                                          : null),
                                ),
                                (_feedback == null || _feedback!.length == 0)
                                    ? SizedBox.shrink()
                                    : Container(
                                        padding: EdgeInsetsDirectional.only(
                                            top: 12, bottom: 12),
                                        child: Center(
                                            child: Text(_feedback!,
                                                style: TextStyle(
                                                    color: Colors.red[300],
                                                    fontWeight:
                                                        FontWeight.bold)))),
                                SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                        onPressed: _handleEmailSignIn,
                                        child: Text("Login",
                                            style: GoogleFonts.poppins(
                                                fontSize: 18,
                                                color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                            padding: EdgeInsetsDirectional.only(
                                                top: 6, bottom: 6),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        32)))))
                              ])))),
                  keyboardVisible
                      ? SizedBox.shrink()
                      : Flexible(
                          flex: 4,
                          fit: FlexFit.loose,
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                GoogleAuthButton(
                                  onPressed: _handleGoogleSignIn,
                                  darkMode: false,
                                ),
                              ]))
                ]))));
  }
}
