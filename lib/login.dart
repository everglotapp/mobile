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
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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
      await _googleSignIn.signIn();
    } catch (error) {
      print("Google sign in failed: " + error.toString());
    }
  }

  // Future<void> _handleGoogleSignOut() => _googleSignIn.disconnect();

  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await Navigator.pushReplacementNamed(context, "/webapp",
        arguments: EmailSignInArguments(
            _emailController.text, _passwordController.text));
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
                                  validator: (value) =>
                                      (value == null || value.isEmpty)
                                          ? "Please enter a password"
                                          : null,
                                ),
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
                  Flexible(
                      flex: 1,
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
