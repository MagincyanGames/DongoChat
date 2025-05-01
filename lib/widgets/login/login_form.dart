import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/database/managers/user_manager.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/utils/crypto.dart';
import 'package:dongo_chat/widgets/login/password_field.dart';
import 'package:dongo_chat/widgets/login/username_field.dart';
import 'package:dongo_chat/widgets/login/login_button.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:dongo_chat/screens/chat/main_screen.dart'; // <- importar MainScreen
import 'package:shared_preferences/shared_preferences.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({Key? key}) : super(key: key);

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Método para cifrar la contraseña

  void _attemptLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Obtén los providers con listen: false
    final userMgr = DBManagers.user;
    final userProv = Provider.of<UserProvider>(context, listen: false);

    try {
      final hashed = CryptoUtils.makeHash(_passwordController.text);
      final ok = await userMgr.authenticateUser(
        _usernameController.text,
        hashed,
      );

      if (ok) {
        // Carga el usuario completo
        final doc = await userMgr.findByUsername(_usernameController.text);
        if (doc != null) {
          doc.password =
              hashed; // Asegúrate de que la contraseña cifrada se guarde
          userProv.user = doc;

          // Guardar credenciales para restaurar sesión
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', _usernameController.text);
          await prefs.setString('password', hashed);

          if (Platform.isAndroid) {
            var tkn = await FirebaseMessaging.instance.getToken();
            doc.fcmToken = tkn;
            await userMgr.update(doc.id!, doc);
          }
        }

        // Navega a MainScreen y limpia la pila
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (_) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credenciales incorrectas'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar sesión: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          UsernameField(controller: _usernameController),
          const SizedBox(height: 16),
          PasswordField(controller: _passwordController),
          const SizedBox(height: 24),
          _isLoading
              ? const CircularProgressIndicator()
              : LoginButton(onPressed: _attemptLogin),
        ],
      ),
    );
  }
}
