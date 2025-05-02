import 'package:dongo_chat/screens/chat/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:dongo_chat/screens/debug/debug_screen.dart';
import 'package:dongo_chat/main.dart';

/// Botón para ir a la pantalla de debug, listo para poner en el AppBar o cualquier lugar con Stack
class DebugButton extends StatelessWidget {
  const DebugButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.bug_report),
      onPressed: () async {
        // Navigate to debug screen and wait for it to close
        await Navigator.pushNamed(context, '/debug');
        
        // When returned from debug screen, update chats if we're in a context with MainScreenState
        final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
        if (mainScreenState != null && mainScreenState.mounted) {
          // Check for updates regardless of selector status
          mainScreenState.checkForChatUpdates();
        }
      },
    );
  }
}
