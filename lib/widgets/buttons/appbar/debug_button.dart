import 'package:dongo_chat/screens/chat/main_screen.dart';
import 'package:dongo_chat/widgets/buttons/app-bar-button.dart';
import 'package:flutter/material.dart';
import 'package:dongo_chat/screens/debug/debug_screen.dart';
import 'package:dongo_chat/main.dart';

/// Botón para ir a la pantalla de debug, listo para poner en el AppBar o cualquier lugar con Stack
class DebugButton extends AppBarButton {
  @override
  IconData getIcon(BuildContext context) => Icons.bug_report;

  @override
  Future<void> onPressed(BuildContext context) async {
    await Navigator.pushNamed(context, '/debug');
  }
}
