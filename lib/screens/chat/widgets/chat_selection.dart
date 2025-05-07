import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/screens/chat/widgets/user_management_section.dart';
import 'package:dongo_chat/utils/dialog_service.dart';
import 'package:dongo_chat/widgets/buttons/gradient/create_chat_button.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:provider/provider.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:dongo_chat/screens/chat/widgets/chat_summary_view.dart';

class ChatSelection extends StatelessWidget {
  final List<ChatSummary> chatSummaries;
  final ValueChanged<ChatSummary> onChatSelected;
  final Function(String, String)? onCreateChat;
  final Function(ObjectId)? onDeleteChat;
  final Function(ObjectId, String, String, ChatSummary)? onEditChat;

  const ChatSelection({
    Key? key,
    required this.chatSummaries,
    required this.onChatSelected,
    this.onCreateChat,
    this.onDeleteChat,
    this.onEditChat,
  }) : super(key: key);

  String _prettify(String input) {
    final withSpaces = input.replaceAll('-', ' ');
    if (withSpaces.isEmpty) return withSpaces;
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }

  void _showCreateChatDialog(BuildContext context) {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedPrivacy = 'private';

    DialogService.showFormDialog<void>(
      context: context,
      title: 'Crear Nuevo Chat',
      content: StatefulBuilder(
        builder: (context, setState) => Form(
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
                  final normalizedName = value
                      .trim()
                      .toLowerCase()
                      .replaceAll(' ', '-');
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
              const Text(
                'Privacidad:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              RadioListTile<String>(
                title: const Text('Privado'),
                subtitle: const Text(
                  'Solo usuarios invitados pueden acceder',
                ),
                value: 'private',
                groupValue: selectedPrivacy,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedPrivacy = value);
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
                    setState(() => selectedPrivacy = value);
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('Público (solo lectura)'),
                subtitle: const Text(
                  'Cualquiera puede leer, solo usuarios invitados pueden escribir',
                ),
                value: 'publicReadOnly',
                groupValue: selectedPrivacy,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedPrivacy = value);
                  }
                },
              ),
            ],
          ),
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
              onCreateChat!(chatName, selectedPrivacy);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }

  bool _isUserAdmin(ChatSummary chat, User? currentUser) {
    return currentUser != null &&
        currentUser.id != null &&
        chat.isAdmin(currentUser);
  }

  void _showContextMenu(
    BuildContext context,
    ChatSummary chat,
    User? currentUser,
    TapDownDetails details,
  ) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(details.localPosition, ancestor: overlay),
        button.localToGlobal(details.localPosition + const Offset(40, 40), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final isAdmin = _isUserAdmin(chat, currentUser);

    if (isAdmin) {
      showMenu(
        context: context,
        position: position,
        items: [
          if (onEditChat != null)
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: const [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Editar chat'),
                ],
              ),
            ),
          if (onDeleteChat != null)
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
        } else if (value == 'edit' && chat.id != null) {
          _showEditChatDialog(context, chat);
        }
      });
    }
  }

  void _showDeleteConfirmation(BuildContext context, ChatSummary chat) {
    DialogService.showConfirmationDialog(
      context: context,
      title: 'Confirmar eliminación',
      content:
          '¿Estás seguro de que quieres eliminar el chat "${chat.name}"? Esta acción no se puede deshacer.',
      confirmText: 'Eliminar',
      confirmColor: Colors.red,
    ).then((confirmed) {
      if (confirmed == true && chat.id != null) {
        onDeleteChat!(chat.id);
      }
    });
  }

  void _showEditChatDialog(BuildContext context, ChatSummary chat) {
    final textController = TextEditingController(text: chat.name);
    final formKey = GlobalKey<FormState>();
    String selectedPrivacy = chat.privacity ?? 'private';
    
    // Create sets for each user type
    final adminUsers = Set<ObjectId>.from(chat.adminUsers);
    final readWriteUsers = Set<ObjectId>.from(chat.readWriteUsers);
    final readOnlyUsers = Set<ObjectId>.from(chat.readOnlyUsers);
    
    // Get current user
    final currentUser = context.read<UserProvider>().user;
    
    // User management key
    final userManagementKey = GlobalKey<UserManagementSectionState>();

    DialogService.showFormDialog<void>(
      context: context,
      title: 'Editar Chat',
      content: StatefulBuilder(
        builder: (context, setState) => Form(
          key: formKey,
          child: SingleChildScrollView(  // Add scrolling for overflow
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Chat',
                    hintText: 'Ej. soporte, proyectos, general',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa un nombre válido';
                    }
                    final normalizedName = value
                        .trim()
                        .toLowerCase()
                        .replaceAll(' ', '-');
                    
                    final exists = chatSummaries.any(
                      (c) => c.name?.toLowerCase() == normalizedName && 
                             c.id != chat.id,
                    );

                    if (exists) {
                      return 'Ya existe un chat con ese nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Privacidad:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                RadioListTile<String>(
                  title: const Text('Privado'),
                  subtitle: const Text('Solo usuarios invitados pueden acceder'),
                  value: 'private',
                  groupValue: selectedPrivacy,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedPrivacy = value);
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
                      setState(() => selectedPrivacy = value);
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Público (solo lectura)'),
                  subtitle: const Text(
                    'Cualquiera puede leer, solo usuarios invitados pueden escribir',
                  ),
                  value: 'publicReadOnly',
                  groupValue: selectedPrivacy,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedPrivacy = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // Add the simplified user management section
                UserManagementSection(
                  key: userManagementKey,
                  initialAdmins: adminUsers,
                  initialReadWrite: readWriteUsers,
                  initialReadOnly: readOnlyUsers,
                  currentUser: currentUser,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate() && onEditChat != null && chat.id != null) {
              final chatName = textController.text
                  .trim()
                  .toLowerCase()
                  .replaceAll(' ', '-');
                  
              // Get updated user lists from the management section
              final userState = userManagementKey.currentState!;
              final updatedAdmins = userState.adminUsers.toList();
              final updatedReadWrite = userState.readWriteUsers.toList();
              final updatedReadOnly = userState.readOnlyUsers.toList();
              
              // Create updated chat summary
              final updatedChat = ChatSummary(
                id: chat.id,
                name: chatName,
                latestMessage: chat.latestMessage,
                latestUpdated: chat.latestUpdated,
                readOnlyUsers: updatedReadOnly,
                readWriteUsers: updatedReadWrite,
                adminUsers: updatedAdmins,
                privacity: selectedPrivacy,
                messageCount: chat.messageCount,
              );
              
              onEditChat!(chat.id, chatName, selectedPrivacy, updatedChat);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    print(chatSummaries.length);
    final theme = Theme.of(context);
    final chatTheme = theme.extension<ChatTheme>();
    final currentUser = context.read<UserProvider>().user;

    final accessibleChats =
        chatSummaries.where((chat) {print('chat ${chat.id}: ${chat.canRead(currentUser)}'); return chat.canRead(currentUser);}).toList();

    accessibleChats.sort((a, b) {
      final aTime = a.latestMessage?.timestamp?.millisecondsSinceEpoch ?? 0;
      final bTime = b.latestMessage?.timestamp?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton:
          onCreateChat != null
              ? CreateChatButton(
                onCreateChat: () => _showCreateChatDialog(context),
              )
              : null,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
        child:
            accessibleChats
                    .isEmpty
                ? Center(child: Text('No hay chats disponibles'))
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 15,
                      runSpacing: 15,
                      children:
                          accessibleChats.map((chat) {
                            return ChatSummaryView(
                              chat: chat,
                              currentUser: currentUser,
                              onChatSelected: onChatSelected,
                              onShowContextMenu: (ctx, cht, usr, details) => _showContextMenu(ctx, cht, usr, details),
                            );
                          }).toList(),
                    ),
                  ),
                ),
      ),
    );
  }
}
