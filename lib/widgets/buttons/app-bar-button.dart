import 'dart:ui';

import 'package:dongo_chat/providers/ThemeProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

abstract class AppBarButton extends StatelessWidget {
  const AppBarButton({Key? key}) : super(key: key);

  IconData getIcon(BuildContext context);
  
  Future<void> onPressed(BuildContext context);

  ThemeProvider getThemeProvider(BuildContext context) {
    return Provider.of<ThemeProvider>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async => await onPressed(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Icon(getIcon(context), color: Colors.white, size: 30,),
        ),
      ),
    );
  }
}
