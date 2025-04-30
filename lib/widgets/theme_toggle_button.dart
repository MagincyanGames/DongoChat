import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dongo_chat/providers/ThemeProvider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Material(
      color: Colors.transparent,
      child: IconButton(
        icon: const Icon(Icons.brightness_6, color: Colors.white),
        iconSize: 20,
        constraints: BoxConstraints(),
        onPressed: () {
          // Don't allow changing theme while a transition is in progress
          if (themeProvider.isChangingTheme) return;

          themeProvider.setThemeMode(
            themeProvider.themeMode == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark,
          );
        },
      ),
    );
  }
}
