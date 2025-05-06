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

  void _attemptLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      // Hash the password using the same utility method
      final hashedPassword = CryptoUtilities.makeHash(_passwordController.text);
      
      // Use the UserProvider's login method instead of the direct database call
      final success = await userProvider.login(
        _usernameController.text,
        hashedPassword,
      );

      if (success) {
        // Login successful, navigate to main screen
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/main',
          (_) => false,
        );
      } else {
        // Login failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credenciales incorrectas'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Handle any errors
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
