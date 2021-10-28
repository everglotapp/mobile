import 'package:everglot/utils/ui.dart';
import 'package:flutter/material.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
            color: primaryColor,
            child: Center(
                child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const <Widget>[
                  Text("Error loading Everglot. Please restart the app.",
                      style: TextStyle(
                          color: Colors.white,
                          fontFamily: "Noto",
                          fontSize: 24,
                          fontWeight: FontWeight.bold))
                ]))));
  }
}
