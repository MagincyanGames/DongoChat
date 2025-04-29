import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    final themeColor = Theme.of(context).colorScheme.primary;


    return Text(
      'DongoChat',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: themeColor,
      ),
      textAlign: TextAlign.center,
    );
  }
}