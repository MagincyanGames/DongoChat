import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:dongo_chat/widgets/buttons/gradient-button.dart';
import 'package:flutter/material.dart';

class SendButton extends GradientButton {
  final bool Function() sendMessage;
  final Function? onSendMessage;
  final Function(BuildContext context)? loadContextualMenu;
  
  const SendButton({
    Key? key,
    required this.sendMessage,
    required this.onSendMessage,
    this.loadContextualMenu,
  }) : super(key: key);

  @override
  LinearGradient getGradient(BuildContext context) {
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Theme.of(context).extension<ChatTheme>()?.otherMessageGradient.last ??
            Colors.blue.shade900,
        Theme.of(context).extension<ChatTheme>()?.myMessageGradient.first ??
            Colors.deepPurple.shade900,
      ],
    ).withOpacity(0.6);
  }

  @override
  IconData getIcon(BuildContext context) {
    return Icons.send;
  }

  @override
  Future<void> onPressed(BuildContext context) {
    if (sendMessage()) {
      onSendMessage?.call();
    }

    return Future.value(null);
  }
  
  @override
  Future<void> onLongPress(BuildContext context) async {
    if (this.loadContextualMenu != null) {
      this.loadContextualMenu!(context);
    }
    return Future.value(null);
  }
}
