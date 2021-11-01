import 'package:everglot/routes/login.dart';
import 'package:everglot/routes/webapp.dart';
import 'package:flutter/material.dart';

class EverglotRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    WidgetBuilder builder;
    switch (settings.name) {
      case "/":
        builder = (BuildContext _) => Row();
        break;
      case LoginPage.routeName:
        final args =
            (settings.arguments ?? LoginPageArguments()) as LoginPageArguments;
        builder = (BuildContext _) => LoginPage(args.forcePath);
        break;
      case WebAppContainer.routeName:
        final args = settings.arguments as WebAppArguments;
        builder = (BuildContext _) => WebAppContainer(args.forcePath);
        break;
      default:
        throw Exception('Invalid route: ${settings.name}');
    }
    return MaterialPageRoute(builder: builder, settings: settings);
  }
}
