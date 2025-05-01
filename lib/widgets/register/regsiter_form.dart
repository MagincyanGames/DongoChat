import 'dart:io';

import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/main.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/screens/chat/main_screen.dart';
import 'package:dongo_chat/screens/debug/debug_screen.dart';
import 'package:dongo_chat/widgets/app_logo.dart';
import 'package:dongo_chat/widgets/login/password_field.dart';
import 'package:dongo_chat/widgets/login/username_field.dart';
import 'package:dongo_chat/widgets/register/already_have_an_account.dart';
import 'package:dongo_chat/widgets/register/register_button.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({Key? key}) : super(key: key);

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _passwordsMatch = true;

  @override
  void initState() {
    super.initState();
    // Escuchar cambios en ambos campos de contraseña
    _passwordController.addListener(_checkPasswordsMatch);
    _confirmPasswordController.addListener(_checkPasswordsMatch);
  }

  void _checkPasswordsMatch() {
    final match = _passwordController.text == _confirmPasswordController.text;
    if (match != _passwordsMatch) {
      setState(() => _passwordsMatch = match);
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_checkPasswordsMatch);
    _confirmPasswordController.removeListener(_checkPasswordsMatch);
    _displayNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _attemptRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas no coinciden'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final userMgr = DBManagers.user;
    final userProv = Provider.of<UserProvider>(context, listen: false);

    try {
      final exists = await userMgr.usernameExists(_usernameController.text);
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario ya en uso'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Hash de la contraseña
      final hashedPassword = _hashPassword(_passwordController.text);

      final newUser = User(
        displayName: _displayNameController.text,
        username: _usernameController.text,
        color: 0xFF2196F3,
        password: hashedPassword,
      );

      await userMgr.add(newUser);
      final u = await userMgr.findByUsername(newUser.username);
      newUser.id = u?.id; // Asignar el ID del nuevo usuario

      if(Platform.isAndroid) {
        // Android: obtener el token de FCM
        var tkn = await FirebaseMessaging.instance.getToken();
        newUser.fcmToken = tkn;
        await userMgr.update(newUser.id!, newUser);
      }
      
      userProv.user = newUser; // asigna currentUser

      // Guardar credenciales para restaurar sesión
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', _usernameController.text);
      await prefs.setString('password', hashedPassword);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password); // Convertir a bytes
    final digest = sha256.convert(bytes); // Aplicar algoritmo SHA-256
    return digest.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu nombre';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          UsernameField(controller: _usernameController),

          const SizedBox(height: 16),

          PasswordField(controller: _passwordController),

          const SizedBox(height: 8),

          TextFormField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: Icon(
                _passwordsMatch ? Icons.check_circle : Icons.error,
                color: _passwordsMatch ? Colors.green : Colors.red,
              ),
              helperText:
                  _passwordsMatch
                      ? 'Las contraseñas coinciden'
                      : 'Las contraseñas no coinciden',
              helperStyle: TextStyle(
                color: _passwordsMatch ? Colors.green : Colors.red,
              ),
            ),
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor confirma tu contraseña';
              }
              if (!_passwordsMatch) {
                return 'Las contraseñas deben coincidir';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          _isLoading
              ? const CircularProgressIndicator()
              : RegisterButton(onPressed: _attemptRegister),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    AppLogo(),
                    SizedBox(height: 48),
                    RegisterForm(),
                    SizedBox(height: 16),
                    AlreadyHaveAnAccount(),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 48,
          child: FloatingActionButton(
            heroTag: 'debugButton',
            backgroundColor: Colors.red,
            mini: true,
            child: const Icon(Icons.bug_report),
            onPressed: () {
              navigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => const DebugScreen()),
              );
            },
          ),
        ),
      ],
    );
  }
}
