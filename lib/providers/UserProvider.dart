import 'package:flutter/material.dart';
import 'package:dongo_chat/models/user.dart';

class UserProvider extends ChangeNotifier {
  User? _user;

  User? get user => _user;

  set user(User? value) {
    _user = value;
    notifyListeners(); // Notifica a todos los widgets que escuchan este provider
  }

  Future<void> logout() async {
    // Limpia la información del usuario actual
    _user = null;
    
    // Si estás usando algún servicio de autenticación (Firebase, etc.)
    // es importante cerrar la sesión también en ese servicio
    
    // Si estás usando almacenamiento local para la sesión, limpiarlo:
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.remove('user_token'); // o las claves que uses
    
    notifyListeners();
  }
}