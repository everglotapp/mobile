import 'package:flutter/material.dart';
import 'package:everglot/utils/ui.dart';

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
            color: Colors.white,
            child: Center(
                child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text("Everglot",
                      style: TextStyle(
                          color: primaryColor,
                          fontFamily: "Noto",
                          fontSize: 32,
                          fontWeight: FontWeight.bold))
                ]))));
  }
}
