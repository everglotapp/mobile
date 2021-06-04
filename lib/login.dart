import 'package:flutter/material.dart';
import 'package:auth_buttons/auth_buttons.dart';
// import 'package:googleapis/oauth2/v2.dart';

const EVERGLOT_URL = 'https://demo.everglot.com';

class LoginPage extends StatefulWidget {
  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
  }

  _onGoogleAuthButtonPressed() {
    print("pressed");
  }

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
                  Row(children: <Widget>[
                    GoogleAuthButton(
                      onPressed: _onGoogleAuthButtonPressed,
                      darkMode: false, // if true second example
                    ),
                  ])
                ]))));
  }
}
