import 'package:dongo_chat/widgets/buttons/app-bar-button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dongo_chat/providers/ThemeProvider.dart';

class ThemeToggleButton extends AppBarButton {
  @override
  IconData getIcon(BuildContext context) {
    if (getThemeProvider(context).themeMode == ThemeMode.dark) {
      return Icons.wb_sunny;
    } else {
      return Icons.dark_mode;
    }
  }

  @override
  Future<void> onPressed(BuildContext context) async {
    ThemeProvider themeProvider = getThemeProvider(context);

    if (themeProvider.isChangingTheme) return;

    themeProvider.setThemeMode(
      themeProvider.themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark,
    );
  }
}
