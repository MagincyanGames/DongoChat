import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:provider/provider.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/theme/chat_theme.dart';

class ChatSelectionScreen extends StatelessWidget {
  final List<ChatSummary> chatSummaries;
  final ValueChanged<ChatSummary> onChatSelected;
  final Function(String, String)? onCreateChat;
  final Function(ObjectId)? onDeleteChat; // Add delete callback

  const ChatSelectionScreen({
    Key? key,
    required this.chatSummaries,
    required this.onChatSelected,
    this.onCreateChat,
    this.onDeleteChat, // Add this parameter
  }) : super(key: key);

  String _prettify(String input) {
    final withSpaces = input.replaceAll('-', ' ');
    if (withSpaces.isEmpty) return withSpaces;
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }

  void _showCreateChatDialog(BuildContext context) {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedPrivacy = 'private'; // Default privacy setting

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Nuevo Chat'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Chat',
                  hintText: 'Ej. soporte, proyectos, general',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa un nombre válido';
                  }
                  final normalizedName = value.trim().toLowerCase().replaceAll(' ', '-');
                  final exists = chatSummaries.any(
                    (chat) => chat.name?.toLowerCase() == normalizedName,
                  );

                  if (exists) {
                    return 'Ya existe un chat con ese nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Privacidad:', style: TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile<String>(
                title: const Text('Privado'),
                subtitle: const Text('Solo usuarios invitados pueden acceder'),
                value: 'private',
                groupValue: selectedPrivacy,
                onChanged: (value) {
                  if (value != null) {
                    selectedPrivacy = value;
                    (context as Element).markNeedsBuild();
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('Público'),
                subtitle: const Text('Cualquiera puede leer y escribir'),
                value: 'public',
                groupValue: selectedPrivacy,
                onChanged: (value) {
                  if (value != null) {
                    selectedPrivacy = value;
                    (context as Element).markNeedsBuild();
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('Público (solo lectura)'),
                subtitle: const Text('Cualquiera puede leer, solo usuarios invitados pueden escribir'),
                value: 'publicReadOnly',
                groupValue: selectedPrivacy,
                onChanged: (value) {
                  if (value != null) {
                    selectedPrivacy = value;
                    (context as Element).markNeedsBuild();
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate() && onCreateChat != null) {
                final chatName = textController.text
                    .trim()
                    .toLowerCase()
                    .replaceAll(' ', '-');
                
                // Update to pass both name and privacy
                onCreateChat!(chatName, selectedPrivacy);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  bool _isUserAdmin(ChatSummary chat, User? currentUser) {
    return currentUser != null && currentUser.id != null && chat.isAdmin(currentUser);
  }

  void _showContextMenu(BuildContext context, ChatSummary chat, User? currentUser) {
    // Get the render box and overlay
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    // Calculate position based on tap location (center of widget is a fallback)
    final Offset position = renderBox.localToGlobal(
      Offset(renderBox.size.width / 2, renderBox.size.height / 2),
      ancestor: overlay,
    );
    
    // Create a proper RelativeRect for the menu position (following message_bundle.dart pattern)
    final RelativeRect rect = RelativeRect.fromRect(
      Rect.fromPoints(
        position,
        position.translate(40, 40), // Small offset to position menu properly
      ),
      Offset.zero & overlay.size,
    );
    
    // Check if user is admin
    final isAdmin = _isUserAdmin(chat, currentUser);
    
    // Show menu only if admin and delete callback exists
    if (isAdmin && onDeleteChat != null) {
      showMenu(
        context: context,
        position: rect,
        items: [
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: const [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Borrar chat'),
              ],
            ),
          ),
        ],
      ).then((value) {
        if (value == 'delete' && chat.id != null) {
          _showDeleteConfirmation(context, chat);
        }
      });
    }
  }

  void _showDeleteConfirmation(BuildContext context, ChatSummary chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar el chat "${chat.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (chat.id != null) {
                onDeleteChat!(chat.id);
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = theme.extension<ChatTheme>();
    final currentUser = context.read<UserProvider>().user;

    // Filter chats based on read permissions
    final accessibleChats = chatSummaries.where((chat) => 
      chat.canRead(currentUser)
    ).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: onCreateChat != null
          ? FloatingActionButton(
              onPressed: () => _showCreateChatDialog(context),
              child: const Icon(Icons.add),
              tooltip: 'Crear nuevo chat',
            )
          : null,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
        child:
            accessibleChats.isEmpty  // Use filtered list here
                ? const Center(child: Text('No hay chats disponibles'))
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 15,
                      runSpacing: 15,
                      children:
                          accessibleChats.map((chat) {  // Use filtered list here
                            final name = _prettify(chat.name ?? 'Unnamed');
                            Future<User?> future;

                            if (chat.latestMessage == null) {
                              future = Future.value(null);
                            } else if (chat.latestMessage!.sender == null) {
                              future = Future.value(null);
                            } else if (chat.latestMessage!.sender != null) {
                              future = DBManagers.user.findById(
                                chat.latestMessage!.sender!,
                              );
                            } else {
                              future = Future.value(null);
                            }

                            return SizedBox(
                              width: 150,
                              height: 150 / 1.5,
                              child: FutureBuilder<User?>(
                                future: future,
                                builder: (ctx, snapshot) {
                                  return GestureDetector(
                                    onSecondaryTap: () => _showContextMenu(context, chat, currentUser),
                                    onLongPress: () => _showContextMenu(context, chat, currentUser),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        splashColor:
                                            chatTheme?.otherQuotedMessageBorderColor
                                                ?.withOpacity(0.3) ??
                                            theme.colorScheme.primary.withOpacity(
                                              0.3,
                                            ),
                                        onTap: () => onChatSelected(chat),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 20,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                chatTheme
                                                    ?.otherQuotedMessageBackgroundColor ??
                                                theme.colorScheme.surfaceVariant
                                                    .withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border(
                                              left: BorderSide(
                                                color:
                                                    chatTheme
                                                        ?.otherQuotedMessageBorderColor ??
                                                    theme.colorScheme.primary,
                                                width: 4,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (chat.latestMessage != null &&
                                                  snapshot.data != null) ...[
                                                const SizedBox(height: 4),
                                                Expanded(
                                                  child: RichText(
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    text: TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text:
                                                              chat
                                                                          .latestMessage!
                                                                          .sender !=
                                                                      null
                                                                  ? "${snapshot.data!.displayName}: "
                                                                  : "",
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight.bold,
                                                                color:
                                                                    theme
                                                                        .textTheme
                                                                        .bodyMedium
                                                                        ?.color,
                                                              ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              chat
                                                                  .latestMessage!
                                                                  .message,
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color: theme
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.color
                                                                    ?.withOpacity(
                                                                      0.7,
                                                                    ),
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
      ),
    );
  }
}
