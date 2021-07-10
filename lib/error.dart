import 'package:flutter/material.dart';
import 'package:everglot/utils/ui.dart';

class ErrorPage extends StatelessWidget {
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
                    children: [
                  Text("Error loading Everglot. Please restart the app.",
                      style: TextStyle(
                          color: Colors.white,
                          fontFamily: "Noto",
                          fontSize: 24,
                          fontWeight: FontWeight.bold))
                ]))));
  }
}
