import 'dart:convert';
import 'dart:io';

import 'package:everglot/constants.dart';
import 'package:everglot/state/messaging.dart';
import 'package:everglot/utils/webapp.dart';
import 'package:everglot/webapp.dart';
import 'package:flutter/material.dart';
import 'package:auth_buttons/auth_buttons.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

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

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen(handleCurrentUserChanged);
    autoSignInOrOut();
    _messaging = Provider.of<Messaging>(context, listen: false);
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
          final loginUrl = await getEverglotUrl(path: "/login");
          http.post(Uri.parse(loginUrl),
              body: jsonEncode({
                "method": EVERGLOT_AUTH_METHOD_GOOGLE,
                "idToken": authentication.idToken,
              }),
              headers: {
                HttpHeaders.contentTypeHeader: 'application/json',
              }).then((http.Response response) async {
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
              });
            } else {
              print("Signing into Everglot failed: " + response.body);
            }
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
            appBar: AppBar(
              title: Text('Login to Everglot',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            body: Container(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        GoogleAuthButton(
                          onPressed: _handleGoogleSignIn,
                          darkMode: false, // if true second example
                        ),
                      ])
                ]))));
  }
}
