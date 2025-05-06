import 'package:dongo_chat/main.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:flutter/material.dart';

AppBar CustomAppBar({
  String title = 'Dongo Chat',
  List<Widget>? actions,
  BuildContext? context,
}) {
  return AppBar(
    title: Text(title),
    actions: actions,
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Theme.of(
                  context!,
                ).extension<ChatTheme>()?.otherMessageGradient.last ??
                Colors.blue.shade900,
            Theme.of(
                  context!,
                ).extension<ChatTheme>()?.myMessageGradient.first ??
                Colors.deepPurple.shade900,
          ],
        ),
      ),
    ),
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
  );
}
