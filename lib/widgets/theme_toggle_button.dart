import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dongo_chat/providers/ThemeProvider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return IconButton(
          icon: Icon(
            themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            // Usar el color del tema para el icono
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
          onPressed: () {
            themeProvider.toggleTheme();
          },
          tooltip: 'Cambiar tema',
        );
      },
    );
  }
}