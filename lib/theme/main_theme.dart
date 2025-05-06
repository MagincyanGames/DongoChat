import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:flutter/material.dart';

ThemeData MainTheme() {
  // Create a proper input decoration theme for light mode
  final inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey[200],
    contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.0),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.0),
      borderSide: BorderSide(color: Colors.deepPurple, width: 2.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.0),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    labelStyle: TextStyle(color: Colors.deepPurple.shade700),
    hintStyle: TextStyle(color: Colors.grey.shade600),
  );

  return ThemeData(
    useMaterial3: false,
    primarySwatch: Colors.deepPurple,
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: Colors.deepPurple,
    ).copyWith(
      secondary: Colors.deepPurple.shade900,
      onSecondary: Colors.white,
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    // Apply the input decoration theme to the base theme
    inputDecorationTheme: inputDecorationTheme,
    extensions: [
      ChatTheme(
        // Gradientes de mensaje
        myMessageGradient: [Colors.deepPurple, Colors.deepPurple.shade700],
        otherMessageGradient: [Colors.blue.shade600, Colors.blue.shade900],
        // Add the action icon color for light theme
        actionIconColor: Colors.grey.shade800,
        // Mis mensajes citados (borde morado)
        myQuotedMessageBorderColor: Colors.purple.shade300,
        myQuotedMessageBackgroundColor: Colors.white,

        // Mensajes de otros citados (borde azul)
        otherQuotedMessageBorderColor: Colors.deepPurple.shade200,
        otherQuotedMessageBackgroundColor: Colors.white.withAlpha(200),

        // Colores de texto comunes
        quotedMessageTextColor: Colors.grey.shade800,
        quotedMessageNameColor: Colors.deepPurple.shade700,

        dialogBackgroundColor: Colors.white,
        dialogBorderRadius: BorderRadius.circular(24.0),
        dialogPrimaryButtonColor: Colors.blue,
        dialogSecondaryButtonColor: Colors.deepPurple,
        dialogTitleStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        dialogContentStyle: TextStyle(fontSize: 16),
        // Light theme field background - more appropriate light gray
        dialogFieldBackgroundColor: Colors.grey[200],
        // Set the input decoration theme specifically for dialogs
        dialogInputDecorationTheme: inputDecorationTheme,
        dialogRadioActiveColor: Colors.deepPurple,
        dialogCheckboxActiveColor: Colors.deepPurple,
      ),
    ],
  );
}

ThemeData MainDarkTheme() {
  // Create a proper input decoration theme for dark mode
  final darkInputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey.shade900,
    contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.0),
      borderSide: BorderSide(color: Colors.grey.shade800),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.0),
      borderSide: BorderSide(color: Colors.blue, width: 2.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.0),
      borderSide: BorderSide(color: Colors.grey.shade800),
    ),
    labelStyle: TextStyle(color: Colors.blue),
    hintStyle: TextStyle(color: Colors.grey.shade400),
  );

  return ThemeData(
    useMaterial3: false,
    brightness: Brightness.dark,
    primarySwatch: Colors.deepPurple,
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: Colors.deepPurple,
      brightness: Brightness.dark,
    ).copyWith(
      secondary: Colors.blue.shade800,
      onSecondary: const Color.fromARGB(255, 255, 255, 255),
      background: Color.fromARGB(255, 0, 0, 0),
      surface: Colors.grey[850],
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[900],
      foregroundColor: Colors.white,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    cardColor: Colors.grey[850],
    canvasColor: const Color.fromARGB(255, 27, 25, 34),
    // Apply the dark input decoration theme to the base theme
    inputDecorationTheme: darkInputDecorationTheme,
    extensions: [
      ChatTheme(
        // Gradientes de mensaje
        myMessageGradient: [
          Colors.deepPurple.shade600,
          Colors.deepPurple.shade900,
        ],
        otherMessageGradient: [Colors.blue.shade700, Colors.blue.shade900],
        // Add the action icon color for dark theme
        actionIconColor: Colors.white,
        // Mis mensajes citados (borde morado claro)
        myQuotedMessageBorderColor: Colors.purple.shade300,
        myQuotedMessageBackgroundColor: Colors.black.withAlpha(175),

        // Mensajes de otros citados (borde azul)
        otherQuotedMessageBorderColor: Colors.blue.shade200,
        otherQuotedMessageBackgroundColor: Colors.black.withAlpha(100),

        // Colores de texto comunes
        quotedMessageTextColor: Colors.grey.shade300,
        quotedMessageNameColor: Colors.deepPurple.shade300,

        dialogBackgroundColor: Colors.grey[900],
        dialogBorderRadius: BorderRadius.circular(24.0),
        dialogPrimaryButtonColor: Colors.blue,
        dialogSecondaryButtonColor: Colors.grey,
        dialogTitleStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        dialogContentStyle: TextStyle(fontSize: 16),
        // Dark theme field background - slightly lighter than dialog background
        dialogFieldBackgroundColor: Colors.grey[850],
        // Set the input decoration theme specifically for dialogs
        dialogInputDecorationTheme: darkInputDecorationTheme,
        dialogRadioActiveColor: Colors.blue,
        dialogCheckboxActiveColor: Colors.blue,
      ),
    ],
  );
}
