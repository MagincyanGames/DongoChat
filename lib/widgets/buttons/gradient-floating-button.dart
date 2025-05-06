import 'dart:ui';

import 'package:dongo_chat/providers/ThemeProvider.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

abstract class GradientButton extends StatelessWidget {
  const GradientButton({Key? key}) : super(key: key);

  IconData getIcon(BuildContext context);
  Future<void> onPressed(BuildContext context);

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

abstract class GradientFloatingButton extends StatelessWidget {
  final String? tooltip;

  const GradientFloatingButton({this.tooltip, Key? key}) : super(key: key);

  IconData getIcon(BuildContext context);
  Future<void> onPressed(BuildContext context);

  ThemeProvider getThemeProvider(BuildContext context) {
    return Provider.of<ThemeProvider>(context, listen: false);
  }

  LinearGradient getGradient(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56, // Standard FAB size
      height: 56, // Standard FAB size
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: getGradient(context),
      ),
      padding: const EdgeInsets.all(2), // Border thickness
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        shape: const CircleBorder(),
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: () async => await onPressed(context),
          customBorder: const CircleBorder(),
          borderRadius: BorderRadius.circular(28),
          child: Tooltip(
            message: tooltip ?? '',
            child: Center(
              child: Icon(
                getIcon(context),
                size: 24,
                color:
                    Theme.of(context).extension<ChatTheme>()?.actionIconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Use this for a FloatingActionButton with a gradient in your scaffold:
// floatingActionButton: YourCustomGradientButton(),
