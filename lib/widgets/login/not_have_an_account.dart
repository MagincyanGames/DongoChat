import 'package:flutter/material.dart';
import 'package:dongo_chat/screens/register_screen.dart';

class NotHaveAnAccount extends StatelessWidget {
  const NotHaveAnAccount({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RegisterScreen()),
        );
      },
      child: const Text('Dont have an account?'),
    );
  }
}
