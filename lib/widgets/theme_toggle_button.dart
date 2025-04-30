import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dongo_chat/providers/ThemeProvider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return IconButton(
      icon: Icon(
        themeProvider.themeMode == ThemeMode.dark
            ? Icons.wb_sunny_outlined
            : Icons.nightlight_round,
      ),
      onPressed: () {
        // Don't allow changing theme while a transition is in progress
        if (themeProvider.isChangingTheme) return;
        
        themeProvider.setThemeMode(
          themeProvider.themeMode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark,
        );
      },
    );
  }
}