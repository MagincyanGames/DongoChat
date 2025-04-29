import 'package:flutter/material.dart';
import 'package:dongo_chat/screens/debug/debug_button.dart';

class LoadingChatScreen extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  
  const LoadingChatScreen({
    super.key,
    this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Inicializando Chat')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text('Inicializando chat...'),
                if (error != null) 
                  Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.all(10),
                    color: Colors.red.shade100,
                    child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
                  ),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Intentar inicializar chat'),
                ),
              ],
            ),
          ),
        ),
        const DebugButton(),
      ],
    );
  }
}