import 'dart:convert';
import 'dart:io';

import 'package:everglot/constants.dart';
import 'package:everglot/main.dart';
import 'package:everglot/state/messaging.dart';
import 'package:everglot/utils/webapp.dart';
import 'package:everglot/webapp.dart';
import 'package:flutter/material.dart';
import 'package:auth_buttons/auth_buttons.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

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

Future<http.Response> _tryLogin(String idToken) async {
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
    super.dispose();
  }

  void handleCurrentUserChanged(GoogleSignInAccount? account) async {
    // setState(() {
    //   _currentUser = account;
    // });
    if (account == null) {
      print("null account");
    } else {
      final authentication = await account.authentication;
      if (authentication.idToken != null) {
        if (_messaging != null && _messaging!.fcmToken != null) {
          _tryLogin(authentication.idToken!)
              .then((http.Response response) async {
            final int statusCode = response.statusCode;

            if (statusCode == 200) {
              print(
                  "Signed in to Everglot. Will now try to register FCM token.");
              final fcmTokenRegistrationUrl = await getEverglotUrl(
                  path: "/users/fcm-token/register/" + _messaging!.fcmToken!);
              http.post(Uri.parse(fcmTokenRegistrationUrl), headers: {
                HttpHeaders.cookieHeader:
                    response.headers[HttpHeaders.setCookieHeader] ?? ""
              }).then((http.Response response) {
                final int statusCode = response.statusCode;

                if (statusCode == 200) {
                  print("Successfully registered FCM token with Everglot!");
                } else {
                  print("Registering FCM token with Everglot failed: " +
                      response.body);
                }
              }).onError((error, stackTrace) {
                print('FCM token registration request produced an error');
                return Future.value();
              });
            } else {
              print("Signing into Everglot failed: " + response.body);
            }
          }).onError((error, stackTrace) {
            print('Login request produced an error');
            return Future.value();
          });
        }
        await Navigator.pushReplacementNamed(context, "/webapp",
            arguments: WebAppArguments(authentication.idToken as String));
      }
    }
  }

  Future<void> autoSignInOrOut() async {
    await Future.delayed(Duration.zero);
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args == null) {
      _googleSignIn.signInSilently();
    } else {
      if ((args as LoginPageArguments).signedOut) {
        _googleSignIn.signOut();
      } else {
        _googleSignIn.signInSilently();
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      print(error);
    }
  }

  // Future<void> _handleGoogleSignOut() => _googleSignIn.disconnect();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: Container(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                  Expanded(
                      flex: 0,
                      child: Container(
                          height: 96,
                          width: 96,
                          decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(96)),
                          child: Center(
                              child: Text("EVG",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 24))))),
                  Container(
                      margin: EdgeInsetsDirectional.only(start: 16, end: 16),
                      padding: EdgeInsetsDirectional.only(top: 24, bottom: 24),
                      child: Column(children: [
                        Container(
                            child: Text("Everglot",
                                style: GoogleFonts.poppins(
                                    fontSize: 28, fontWeight: FontWeight.w600)),
                            margin: EdgeInsetsDirectional.only(bottom: 4)),
                        Text("Learn Together",
                            style: GoogleFonts.poppins(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                      ])),
                  Form(
                      child: Container(
                          margin:
                              EdgeInsetsDirectional.only(start: 16, end: 16),
                          child: Column(children: [
                            TextFormField(
                              decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32)),
                                  labelStyle: GoogleFonts.poppins(),
                                  fillColor: Colors.grey[100],
                                  filled: true,
                                  contentPadding: EdgeInsetsDirectional.only(
                                      start: 18, end: 18, top: 4, bottom: 4),
                                  labelText: 'Email'),
                            ),
                            Container(height: 4),
                            TextFormField(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(32)),
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
                                  child: Text(_passwordHidden ? "Show" : "Hide",
                                      style: GoogleFonts.poppins(
                                          color: primary, fontSize: 14)),
                                ),
                              ),
                              obscureText: _passwordHidden,
                            ),
                            SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                    onPressed: () {},
                                    child: Text("Login",
                                        style: GoogleFonts.poppins(
                                            fontSize: 18, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                        padding: EdgeInsetsDirectional.only(
                                            top: 6, bottom: 6),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(32)))))
                          ]))),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        GoogleAuthButton(
                          onPressed: _handleGoogleSignIn,
                          darkMode: false,
                        ),
                      ])
                ]))));
  }
}
