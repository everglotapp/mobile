import 'dart:convert';
import 'dart:io';

import 'package:auth_buttons/auth_buttons.dart';
import 'package:email_validator/email_validator.dart';
import 'package:everglot/routes/webapp.dart';
import 'package:everglot/state/messaging.dart';
import 'package:everglot/utils/login.dart';
import 'package:everglot/utils/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class LoginPageArguments {
  bool signedOut = false;
  String? forcePath;

  LoginPageArguments(this.signedOut, this.forcePath);
}

class LoginPage extends StatefulWidget {
  static const routeName = '/login';

  final String? forcePath;
  const LoginPage(this.forcePath, {Key? key}) : super(key: key);

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  // GoogleSignInAccount? _currentUser;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: getGoogleClientId(),
    scopes: <String>[
      'email',
    ],
  );
  Messaging? _messaging;
  bool _passwordHidden = true;
  bool _hasAccount = true;
  bool _transitioningToWebapp = false;
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
    _transitioningToWebapp = false;

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
        final idToken = authentication.idToken!;
        if (_messaging != null && _messaging!.fcmToken != null) {
          final fcmToken = _messaging!.fcmToken!;
          final authFunction = _hasAccount ? tryGoogleLogin : tryGoogleSignUp;
          authFunction(idToken).then((http.Response response) async {
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
                  tryRegisterFcmToken(fcmToken, cookieHeader);
                  await registerSessionCookie(
                      cookieHeader, response.request!.url);
                  await _transitionToWebApp();
                  return;
                }
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
            print('Login request produced an error: ' + error.toString());
            print(stackTrace);
            return Future.value();
          });
        }
      }
    }
  }

  Future<void> autoSignInOrOut() async {
    await Future.delayed(Duration.zero);
    final args =
        ModalRoute.of(context)!.settings.arguments as LoginPageArguments?;
    if (args != null && (args).signedOut) {
      // Automatically sign out from Google as user just signed out from app.
      _googleSignIn.signOut();
      // Unset any stored session cookie to prevent sign in upon app restart.
      removeStoredSessionCookie();
      return;
    }
    /**
     * Try all possible ways to automatically sign the user into the app.
     */
    try {
      final googleAccount = await _googleSignIn.signInSilently();
      if (googleAccount != null) {
        // Automatic sign in via Google worked.
        return;
      }
    } catch (error) {
      print("Automatic silent Google sign in failed: " + error.toString());
    }
    // Try to sign in with stored cookie header.
    final cookie = await getStoredSessionCookie();
    if (cookie != null) {
      // Check if expired.
      print("Session cookie header exists, moving to webapp route");
      await _transitionToWebApp();
    }
  }

  Future<void> _handleGoogleSignInOrUp() async {
    try {
      setState(() {
        _feedback = null;
      });
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _googleSignIn.signIn();
    } catch (error) {
      print("Google sign in failed: " + error.toString());
    }
  }

  // Future<void> _handleGoogleSignOut() => _googleSignIn.disconnect();

  Future<void> _handleEmailSignInOrUp() async {
    setState(() {
      _feedback = null;
    });
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final email = _emailController.text;
    final password = _passwordController.text;
    final authFunction = _hasAccount ? tryEmailLogin : tryEmailSignUp;
    authFunction(email, password).then((http.Response response) async {
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
            tryRegisterFcmToken(_messaging!.fcmToken!, cookieHeader);
            await registerSessionCookie(cookieHeader, response.request!.url);
            await _transitionToWebApp();
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
    });
  }

  Future<String?> _transitionToWebApp() async {
    if (!mounted || _transitioningToWebapp) {
      return null;
    }
    setState(() {
      _transitioningToWebapp = true;
    });
    await Future.delayed(Duration.zero);
    final args =
        ModalRoute.of(context)!.settings.arguments as LoginPageArguments?;
    final path = this.widget.forcePath == null
        ? (args == null ? null : args.forcePath)
        : this.widget.forcePath;
    final webAppArguments = path == null ? null : WebAppArguments(path);
    await Navigator.pushReplacementNamed(context, WebAppContainer.routeName,
        arguments: webAppArguments);
  }

  @override
  Widget build(BuildContext context) {
    if (_transitioningToWebapp) {
      return SafeArea(child: Scaffold());
    }
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom != 0;
    return SafeArea(
        child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: Container(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                  Flexible(
                      flex: 2,
                      fit: FlexFit.loose,
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 50.0,
                        fit: BoxFit.cover,
                      )),
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
                                    child: Text("Learn Together",
                                        style: GoogleFonts.poppins(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w600))),
                              ])))),
                  Flexible(
                      flex: 6,
                      fit: FlexFit.loose,
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
                                              color: primaryColor,
                                              fontSize: 14)),
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
                                Container(height: 6),
                                (_feedback == null || _feedback!.length == 0)
                                    ? SizedBox.shrink()
                                    : Container(
                                        padding: EdgeInsetsDirectional.only(
                                            top: 4, bottom: 6),
                                        child: Center(
                                            child: Text(_feedback!,
                                                style: TextStyle(
                                                    color: Colors.red[300],
                                                    fontWeight:
                                                        FontWeight.bold)))),
                                SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                        onPressed: _handleEmailSignInOrUp,
                                        child: Text(
                                            _hasAccount ? "Login" : "Sign up",
                                            style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                            padding: EdgeInsetsDirectional.only(
                                                top: 8, bottom: 8),
                                            elevation: 3,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        32))))),
                                keyboardVisible
                                    ? SizedBox.shrink()
                                    : Container(
                                        margin:
                                            EdgeInsetsDirectional.only(top: 8),
                                        child: Center(
                                            child: GoogleAuthButton(
                                          onPressed: _handleGoogleSignInOrUp,
                                          darkMode: false,
                                          text: _hasAccount
                                              ? "Login with Google"
                                              : "Sign up with Google",
                                          style: AuthButtonStyle(
                                            width: 400,
                                            borderRadius: 32,
                                            textStyle: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ))),
                                keyboardVisible
                                    ? SizedBox.shrink()
                                    : Container(
                                        margin:
                                            EdgeInsetsDirectional.only(top: 1),
                                        child: Center(
                                          child: MaterialButton(
                                            onPressed: () {
                                              setState(() {
                                                _hasAccount = !_hasAccount;
                                              });
                                            },
                                            child: _hasAccount
                                                ? Text(
                                                    "I don't have an account",
                                                    style: GoogleFonts.poppins(
                                                        color: primaryColor,
                                                        fontSize: 14))
                                                : Text(
                                                    "I already have an account",
                                                    style: GoogleFonts.poppins(
                                                        color: primaryColor,
                                                        fontSize: 14)),
                                            minWidth: 400,
                                            padding: EdgeInsetsDirectional.only(
                                                top: 2, bottom: 2),
                                          ),
                                        ))
                              ])))),
                ]))));
  }
}
