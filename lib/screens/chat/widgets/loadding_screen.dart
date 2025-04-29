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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Inicializando Chat'),
            // Usar el estilo correcto del AppBar según el tema actual
            backgroundColor: theme.appBarTheme.backgroundColor,
            foregroundColor: theme.appBarTheme.foregroundColor,
          ),
          // Usar el color de fondo del tema
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Usar el color primario del tema para el indicador
                CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                // Usar el color de texto del tema
                Text(
                  'Inicializando chat...',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                if (error != null) 
                  Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.red.shade900.withOpacity(0.7)
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.red.shade300
                            : Colors.red.shade300,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Error: $error',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.red.shade100
                            : Colors.red.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Intentar inicializar chat',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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