import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

void showMessageContextMenu({
  required BuildContext context,
  required RelativeRect rect, // Changed from Offset position to RelativeRect
  required Message message,
  required bool isMe,
  required Function(ObjectId) onReply,
  Function(String)? onShowSnackbar,
  Function(ObjectId, String)? onQuickReply,
}) {
  final theme = Theme.of(context);
  final primaryColor = theme.colorScheme.primary;
  final secondaryColor = theme.colorScheme.secondary;
  final backgroundColor = theme.cardColor;
  final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
  final RenderBox overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox;

  // 1) Declaro isPressed **fuera** del builder:
  bool isPressed = false;

  // Use the rect directly with showMenu
  showMenu(
    context: context,
    position: rect,
    items: [
      PopupMenuItem(
        value: 'reply',
        child: StatefulBuilder(
          builder: (context, setState) {
            return GestureDetector(
              onLongPressStart: (_) {
                setState(() => isPressed = true);
              },
              onLongPressEnd: (details) {
                setState(() => isPressed = false);

                // Verificamos si el puntero está dentro del widget cuando se suelta
                final RenderBox box = context.findRenderObject() as RenderBox;
                final Offset localOffset = box.globalToLocal(
                  details.globalPosition,
                );
                final bool isInsideBounds = box.size.contains(localOffset);

                Navigator.of(context).pop();

                // Solo ejecutar la acción si el dedo se suelta dentro del botón
                if (isInsideBounds) {
                  if (message.id != null && onQuickReply != null) {
                    onQuickReply(message.id!, ".");
                    if (onShowSnackbar != null) {
                      onShowSnackbar('Respuesta rápida enviada');
                    }
                  }
                } else {
                  // Acción cancelada
                  if (onShowSnackbar != null) {
                    onShowSnackbar('Acción cancelada');
                  }
                }
              },
              onLongPressMoveUpdate: (details) {
                // Verificamos si el puntero se ha movido fuera del widget
                final RenderBox box = context.findRenderObject() as RenderBox;
                final Offset localOffset = box.globalToLocal(
                  details.globalPosition,
                );
                final bool isInsideBounds = box.size.contains(localOffset);

                // Actualizamos el estado visual si cambia
                if (isInsideBounds != isPressed) {
                  setState(() => isPressed = isInsideBounds);
                }
              },
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 20,
                    color: isPressed ? primaryColor : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isPressed ? 'Recordar' : 'Responder',
                    style: TextStyle(
                      color: isPressed ? primaryColor : null,
                      fontWeight:
                          isPressed ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),

      PopupMenuItem(
        value: 'copy',
        child: Row(
          children: const [
            Icon(Icons.copy),
            SizedBox(width: 8),
            Text('Copiar'),
          ],
        ),
      ),
    ],
  ).then((value) {
    if (value == null) return;
    // Mover lógica de estado fuera del builder
    switch (value) {
      case 'copy':
        Clipboard.setData(ClipboardData(text: message.message));
        break;
      case 'reply':
        if (message.id != null) onReply(message.id!);
        break;
    }
  });
}
