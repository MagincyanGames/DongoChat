import 'package:dongo_chat/widgets/buttons/gradient-floating-button.dart';
import 'package:flutter/material.dart';

class CreateChatButton extends GradientButton {
  final Function() onCreateChat;

  const CreateChatButton({required this.onCreateChat, Key? key})
    : super(/*tooltip: 'Crear nuevo chat', */ key: key);

  @override
  IconData getIcon(BuildContext context) => Icons.add;

  @override
  Future<void> onPressed(BuildContext context) async {
    onCreateChat();
  }

  @override
  LinearGradient getGradient(BuildContext context) {
    final theme = Theme.of(context);
    return LinearGradient(
      colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
