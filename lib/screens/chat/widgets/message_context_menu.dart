import 'package:flutter/material.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:flutter/services.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

void showMessageContextMenu({
  required BuildContext context,
  required Offset position,
  required Message message,
  required bool isMe,
  required Function(ObjectId) onReply,  // Nuevo callback para responder
  Function(ObjectId)? onDelete,         // Nuevo callback opcional para eliminar
  User? user,
}) {
  // Get theme colors
  final theme = Theme.of(context);
  final primaryColor = theme.colorScheme.primary;
  final backgroundColor = theme.cardColor;
  final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;

  // Calculate the position for the menu
  final RenderBox overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox;

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
        value: 'reply',
        child: Row(
          children: [
            Icon(Icons.reply, size: 20, color: primaryColor),
            const SizedBox(width: 10),
            Text('Responder', style: TextStyle(color: textColor)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'copy',
        child: Row(
          children: [
            Icon(Icons.copy, size: 20, color: primaryColor),
            const SizedBox(width: 10),
            Text('Copiar mensaje', style: TextStyle(color: textColor)),
          ],
        ),
      ),
      if (isMe && onDelete != null) // Solo mostrar opción de eliminar para mensajes propios
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
        // Usar el callback de eliminación
        if (isMe && onDelete != null && message.id != null) {
          onDelete(message.id!);
        }
        break;
        
      case 'reply':
        // Usar el callback de respuesta
        if (message.id != null) {
          onReply(message.id!);
        }
        break;
    }
  });
}
