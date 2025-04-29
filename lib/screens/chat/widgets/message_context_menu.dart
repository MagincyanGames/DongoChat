import 'package:dongo_chat/screens/chat/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:flutter/services.dart';

void showMessageContextMenu({
  required BuildContext context,
  required Offset position,
  required Message message,
  required bool isMe,
  User? user,
}) {
  // Get theme colors
  final theme = Theme.of(context);
  final primaryColor = theme.colorScheme.primary;
  final backgroundColor = theme.cardColor;
  final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
  
  // Calculate the position for the menu
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  
  showMenu(
    context: context,
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    color: backgroundColor,
    position: RelativeRect.fromRect(
      Rect.fromPoints(position, position),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem(
        value: 'copy',
        child: Row(
          children: [
            Icon(Icons.copy, size: 20, color: primaryColor),
            const SizedBox(width: 10),
            Text(
              'Copiar mensaje',
              style: TextStyle(color: textColor),
            ),
          ],
        ),
      ),
      if (isMe) // Only show delete option for own messages
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete, size: 20, color: Colors.red),
              const SizedBox(width: 10),
              Text(
                'Eliminar mensaje', 
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      PopupMenuItem(
        value: 'reply',
        child: Row(
          children: [
            Icon(Icons.reply, size: 20, color: primaryColor),
            const SizedBox(width: 10),
            Text(
              'Responder',
              style: TextStyle(color: textColor),
            ),
          ],
        ),
      ),
    ],
  ).then((value) {
    // Handle menu item selection
    if (value == null) return;
    
    switch (value) {
      case 'copy':
        // Copy message to clipboard
        final messageText = message.message;
        Clipboard.setData(ClipboardData(text: messageText));
        
        break;
      case 'delete':
        // Handle delete action
        // You'll need to implement this based on your app's architecture
        break;
      case 'reply':
        // Get the MainScreen state and set the reply
        final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
        if (mainScreenState != null && message.id != null) {
          mainScreenState.setReplyMessage(message.id!);
        }
        break;
    }
  });
}