import 'package:flutter/material.dart';
import 'package:dongo_chat/screens/debug/debug_screen.dart';
import 'package:dongo_chat/main.dart';

/// Botón para ir a la pantalla de debug, listo para poner en el AppBar o cualquier lugar con Stack
class DebugButton extends StatelessWidget {
  const DebugButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      // transparente para no pintar fondo
      color: Colors.transparent,
      child: IconButton(
        icon: const Icon(Icons.bug_report, color: Colors.white),
        tooltip: 'Debug',
        onPressed: () {
          navigatorKey.currentState
              ?.push(MaterialPageRoute(builder: (_) => const DebugScreen()));
        },
      ),
    );
  }
}
