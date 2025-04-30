import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dongo_chat/providers/UserProvider.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> _logout(BuildContext context) async {
    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Cerrar sesión'),
                content: const Text('¿Estás seguro que deseas cerrar sesión?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!shouldLogout) return;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.logout();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cerrar sesión: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: IconButton(
        iconSize: 20,
        icon: const Icon(Icons.logout),
        tooltip: 'Cerrar sesión',
        onPressed: () => _logout(context),
      ),
    );
  }
}
