import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auth_buttons/auth_buttons.dart';
import 'package:email_validator/email_validator.dart';
import 'package:everglot/routes/_loading.dart';
import 'package:everglot/routes/_splash.dart';
import 'package:everglot/routes/webapp.dart';
import 'package:everglot/state/messaging.dart';
import 'package:everglot/utils/login.dart';
import 'package:everglot/utils/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: getGoogleClientId(),
  scopes: <String>[
    'email',
  ],
);

class LoginPageArguments {
  bool signedOut = false;
  String? forcePath;

  LoginPageArguments({this.signedOut = false, this.forcePath});
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
  Messaging? _messaging;
  bool _passwordHidden = true;
  bool _hasAccount = true;
  bool _transitioningToWebapp = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _feedback;
  bool _triedAutoSignIn = false;
  late StreamSubscription<GoogleSignInAccount?>
      _onCurrentUserChangedSubscription;

  @override
  void initState() {
    super.initState();
    _onCurrentUserChangedSubscription =
        _googleSignIn.onCurrentUserChanged.listen(handleCurrentUserChanged);
    autoSignInOrOut();

    _messaging = Provider.of<Messaging>(context, listen: false);
    _transitioningToWebapp = false;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _onCurrentUserChangedSubscription.cancel();
    super.dispose();
  }

  void handleCurrentUserChanged(GoogleSignInAccount? account) async {
    // setState(() {
    //   _currentUser = account;
    // });
    if (account == null) {
      debugPrint("null account");
      setState(() {
        _triedAutoSignIn = true;
      });
      return;
    }
    // Successfully logged in via Google.
    final authentication = await account.authentication;
    if (authentication.idToken == null) {
      setState(() {
        _triedAutoSignIn = true;
      });
      return;
    }
    final idToken = authentication.idToken!;
    if (_messaging == null || _messaging!.fcmToken == null) {
      setState(() {
        _triedAutoSignIn = true;
      });
      return;
    }
    final fcmToken = _messaging!.fcmToken!;
    final authFunction = _hasAccount ? tryGoogleLogin : tryGoogleSignUp;
    authFunction(idToken).then((http.Response response) async {
      final int statusCode = response.statusCode;

      if (statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse != null && jsonResponse["success"] == true) {
          final cookieHeader = response.headers[HttpHeaders.setCookieHeader];
          if (cookieHeader == null) {
            debugPrint("Something went wrong, cannot get session cookie.");
          } else {
            debugPrint(
                "Signed in to Everglot via Google. Will now try to register FCM token.");
            tryRegisterFcmToken(fcmToken, cookieHeader).catchError((e) {
              debugPrint(e);
            });
            await registerSessionCookie(cookieHeader, response.request!.url);
            if (jsonResponse["refreshToken"] is String) {
              final refreshToken = jsonResponse["refreshToken"] as String;
              if (refreshToken.isNotEmpty) {
                await registerRefreshToken(refreshToken);
              }
            }
            final transitionFuture = _transitionToWebApp();
            setState(() {
              _triedAutoSignIn = true;
            });
            await transitionFuture;
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

      setState(() {
        _triedAutoSignIn = true;
      });
      if (kDebugMode) {
        debugPrint("Signing into Everglot failed: " + response.body);
      }
    }).onError((error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Login request produced an error: ' + error.toString());
        debugPrint(stackTrace.toString());
      }

      setState(() {
        _triedAutoSignIn = true;
      });
      return Future.value();
    });
  }

  Future<bool> autoSignInOrOut() async {
    await Future.delayed(Duration.zero);
    final args =
        ModalRoute.of(context)!.settings.arguments as LoginPageArguments?;
    if (args != null && (args).signedOut) {
      // Automatically sign out from Google as user just signed out from app.
      await _googleSignIn.signOut();
      // Unset any stored session cookie to prevent sign in upon app restart.
      await removeStoredSessionCookie();
      return true;
    }
    /**
     * Try all possible ways to automatically sign the user into the app.
     */
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) {
      if (kDebugMode) {
        debugPrint(
            "Cannot reauth via refresh token no refresh token could be retrieved");
      }
    } else {
      if (JwtDecoder.isExpired(refreshToken)) {
        if (kDebugMode) {
          debugPrint(
              "Reauth via refresh token cancelled as refresh token has expired");
        }
      } else {
        final reauthedSuccessfully = await reauthenticate(refreshToken);
        if (reauthedSuccessfully) {
          if (kDebugMode) {
            debugPrint(
                "Reauth via refresh token worked, moving to webapp route");
          }
          final transitionFuture = _transitionToWebApp();
          setState(() {
            _triedAutoSignIn = true;
          });
          await transitionFuture;
          return true;
        }
      }
    }
    try {
      final googleAccount = await _googleSignIn.signInSilently();
      if (googleAccount != null) {
        // Automatic sign in via Google worked.
        return true;
      }
    } catch (e) {
      debugPrint("Automatic silent Google sign in failed: $e");
    }
    setState(() {
      _triedAutoSignIn = true;
    });
    return false;
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
      debugPrint("Google sign in failed: " + error.toString());
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
            debugPrint("Something went wrong, cannot get session cookie.");
          } else {
            debugPrint(
                "Successfully signed in to Everglot via email. Will now try to register FCM token.");
            tryRegisterFcmToken(_messaging!.fcmToken!, cookieHeader)
                .catchError((e) {
              debugPrint(e);
            });
            await registerSessionCookie(cookieHeader, response.request!.url);
            if (jsonResponse["refreshToken"] is String) {
              final refreshToken = jsonResponse["refreshToken"] as String;
              if (refreshToken.isNotEmpty) {
                await registerRefreshToken(refreshToken);
              }
            }
            await _transitionToWebApp();
            return;
          }
        }
      }
      debugPrint("Signing into Everglot failed: " + response.body);
      final jsonResponse = json.decode(response.body);
      debugPrint(jsonResponse);
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
    final path = widget.forcePath ?? (args?.forcePath);
    await Navigator.pushReplacementNamed(context, WebAppContainer.routeName,
        arguments: WebAppArguments(forcePath: path));
  }

  @override
  Widget build(BuildContext context) {
    if (!_triedAutoSignIn) {
      return const SplashScreen();
    }
    if (_transitioningToWebapp) {
      return const LoadingScreen();
    }
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom != 0;
    return SafeArea(
        child: Scaffold(
            resizeToAvoidBottomInset: true,
            body:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: <
                    Widget>[
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
                          : const EdgeInsetsDirectional.only(
                              top: 0, bottom: 18),
                      child: ConstrainedBox(
                          constraints:
                              BoxConstraints.tight(const Size.fromHeight(110)),
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
                          margin: const EdgeInsetsDirectional.only(
                              start: 16, end: 16),
                          child: Column(children: [
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32)),
                                  labelStyle: GoogleFonts.poppins(),
                                  fillColor: Colors.grey[100],
                                  filled: true,
                                  contentPadding:
                                      const EdgeInsetsDirectional.only(
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
                                    borderRadius: BorderRadius.circular(32)),
                                labelStyle: GoogleFonts.poppins(),
                                fillColor: Colors.grey[100],
                                filled: true,
                                contentPadding:
                                    const EdgeInsetsDirectional.only(
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
                                          color: primaryColor, fontSize: 14)),
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
                            (_feedback == null || _feedback!.isEmpty)
                                ? const SizedBox.shrink()
                                : Container(
                                    padding: const EdgeInsetsDirectional.only(
                                        top: 4, bottom: 6),
                                    child: Center(
                                        child: Text(_feedback!,
                                            style: TextStyle(
                                                color: Colors.red[300],
                                                fontWeight: FontWeight.bold)))),
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
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                                top: 8, bottom: 8),
                                        elevation: 3,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(32))))),
                            keyboardVisible
                                ? const SizedBox.shrink()
                                : Container(
                                    margin: const EdgeInsetsDirectional.only(
                                        top: 8),
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
                                ? const SizedBox.shrink()
                                : Container(
                                    margin: const EdgeInsetsDirectional.only(
                                        top: 1),
                                    child: Center(
                                      child: MaterialButton(
                                        onPressed: () {
                                          setState(() {
                                            _hasAccount = !_hasAccount;
                                          });
                                        },
                                        child: _hasAccount
                                            ? Text("I don't have an account",
                                                style: GoogleFonts.poppins(
                                                    color: primaryColor,
                                                    fontSize: 14))
                                            : Text("I already have an account",
                                                style: GoogleFonts.poppins(
                                                    color: primaryColor,
                                                    fontSize: 14)),
                                        minWidth: 400,
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                                top: 2, bottom: 2),
                                      ),
                                    ))
                          ])))),
            ])));
  }
}
