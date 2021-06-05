import 'package:flutter/material.dart';
import 'package:auth_buttons/auth_buttons.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fluent_i18n/fluent_i18n.dart';

const EVERGLOT_URL = 'https://demo.everglot.com';

class LoginPage extends StatefulWidget {
  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  GoogleSignInAccount? _currentUser;

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      setState(() {
        _currentUser = account;
        if (account == null) {
          print("null account");
        } else {
          (() async {
            final authentication = await account.authentication;
            print(authentication.idToken);
          })();
        }
      });
    });
    _googleSignIn.signInSilently();
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      print(error);
    }
  }

  Future<void> _handleGoogleSignOut() => _googleSignIn.disconnect();

  @override
  Widget build(BuildContext context) {
    final i18n = FluentLocalizations.current();
    return SafeArea(
        child: Scaffold(
            appBar: AppBar(
              title: Text('Login to Everglot'),
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
                            darkMode: false,
                            text: i18n.getMessage('login-google-auth-button')),
                      ])
                ]))));
  }
}

final GoogleSignIn _googleSignIn = GoogleSignIn(
  // TODO: Make this be the production one when building release.
  clientId:
      '457984069949-27t84k2dm2l8li57c32rjm114iedk15o.apps.googleusercontent.com',
  scopes: <String>[
    'email',
  ],
);
