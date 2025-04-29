import 'package:flutter/material.dart';
import 'package:dongo_chat/screens/debug/debug_button.dart';
import 'package:dongo_chat/widgets/app_logo.dart';
import 'package:dongo_chat/widgets/register/already_have_an_account.dart';
import 'package:dongo_chat/widgets/register/regsiter_form.dart';

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
                    AlreadyHaveAnAccount(),
                  ],
                ),
              ),
            ),
          ),
        ),
        DebugButton(),
      ],
    );
  }
}
