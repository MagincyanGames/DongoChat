import 'dart:ui';

import 'package:dongo_chat/providers/ThemeProvider.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

abstract class GradientButton extends StatelessWidget {
  const GradientButton({Key? key}) : super(key: key);

  IconData getIcon(BuildContext context);
  Future<void> onPressed(BuildContext context);
  Future<void> onLongPress(
    BuildContext context,
  ) async {} // New method with default empty implementation

  ThemeProvider getThemeProvider(BuildContext context) {
    return Provider.of<ThemeProvider>(context, listen: false);
  }

  LinearGradient getGradient(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: getGradient(context),
      ),
      padding: const EdgeInsets.all(2), // Border thickness
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () async => await onPressed(context),
          onLongPress:
              () async =>
                  await onLongPress(context), // Added onLongPress handler

          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(
              getIcon(context),
              color: Theme.of(context).extension<ChatTheme>()?.actionIconColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
