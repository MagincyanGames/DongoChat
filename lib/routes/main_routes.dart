import 'package:dongo_chat/screens/chat/chat_screen.dart';
import 'package:dongo_chat/screens/chat/chat_selection_screen.dart';
import 'package:dongo_chat/screens/chat/main_screen.dart';
import 'package:dongo_chat/screens/debug/debug_screen.dart';
import 'package:dongo_chat/screens/login_screen.dart';
import 'package:flutter/material.dart';

Map<String, Widget Function(BuildContext)> MainRoutes = {
  '/main': (context) => const ChatSelectionScreen(),
  '/debug': (context) => const DebugScreen(),
  '/chat': (context) => const ChatScreen(),
  '/login': (context) => const LoginScreen(),
};
