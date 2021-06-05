import 'package:everglot/constants.dart';
import 'package:everglot/webapp.dart';
import 'package:flutter/material.dart';
import 'package:auth_buttons/auth_buttons.dart';
import 'package:google_sign_in/google_sign_in.dart';

const EVERGLOT_URL = 'https://demo.everglot.com';

class LoginPage extends StatefulWidget {
  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  // GoogleSignInAccount? _currentUser;
  GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: GOOGLE_CLIENT_ID,
    scopes: <String>[
      'email',
    ],
  );

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) async {
      // setState(() {
      //   _currentUser = account;
      // });
      if (account == null) {
        print("null account");
      } else {
        final authentication = await account.authentication;
        if (authentication.idToken != null) {
          await Navigator.pushReplacementNamed(context, "/webapp",
              arguments: WebAppArguments(authentication.idToken as String));
        }
      }
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

  // Future<void> _handleGoogleSignOut() => _googleSignIn.disconnect();

  @override
  Widget build(BuildContext context) {
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
                          darkMode: false, // if true second example
                        ),
                      ])
                ]))));
  }
}
