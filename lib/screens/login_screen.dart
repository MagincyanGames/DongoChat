import 'package:flutter/material.dart';
import 'package:dongo_chat/screens/debug/debug_screen.dart';
import 'package:dongo_chat/main.dart';
import 'package:dongo_chat/widgets/app_logo.dart';
import 'package:dongo_chat/widgets/login/login_form.dart';
import 'package:dongo_chat/widgets/login/forgot_password_button.dart';
import 'package:dongo_chat/widgets/login/not_have_an_account.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

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
                    LoginForm(),
                    SizedBox(height: 16),
                    ForgotPasswordButton(),
                    NotHaveAnAccount(),
                  ],
                ),
              ),
            ),
          ),
        ),
        // New visible debug button
        Positioned(
          top: 40,
          right: 16,
          child: Material(
            elevation: 4,
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(builder: (_) => const DebugScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.bug_report, color: Colors.red),
                    SizedBox(width: 4),
                    Text('Debug', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
