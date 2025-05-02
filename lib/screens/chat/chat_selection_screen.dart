import 'package:dongo_chat/models/user.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:provider/provider.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/theme/chat_theme.dart';

class ChatSelectionScreen extends StatelessWidget {
  final List<ChatSummary> chatSummaries;
  final ValueChanged<ChatSummary> onChatSelected;
  final Function(String)? onCreateChat; // Nuevo callback para crear chats

  const ChatSelectionScreen({
    Key? key,
    required this.chatSummaries,
    required this.onChatSelected,
    this.onCreateChat,
  }) : super(key: key);

  String _prettify(String input) {
    final withSpaces = input.replaceAll('-', ' ');
    if (withSpaces.isEmpty) return withSpaces;
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }

  void _showCreateChatDialog(BuildContext context) {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Crear Nuevo Chat'),
            content: Form(
              key: formKey,
              child: TextFormField(
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
                  // Validar si ya existe un chat con ese nombre
                  final normalizedName = value.trim().toLowerCase().replaceAll(
                    ' ',
                    '-',
                  );
                  final exists = chatSummaries.any(
                    (chat) => chat.name?.toLowerCase() == normalizedName,
                  );

                  if (exists) {
                    return 'Ya existe un chat con ese nombre';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState!.validate() &&
                      onCreateChat != null) {
                    final chatName = textController.text
                        .trim()
                        .toLowerCase()
                        .replaceAll(' ', '-');
                    onCreateChat!(chatName);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Crear'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = theme.extension<ChatTheme>();

    return Container(
      width: double.infinity,
      height: double.infinity, // Asegura que ocupe toda la altura disponible
      color: Colors.transparent,
      child:
          chatSummaries.isEmpty
              ? const Center(child: Text('No hay chats disponibles'))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 15, // Espacio horizontal entre elementos
                    runSpacing: 15, // Espacio vertical entre filas
                    children:
                        chatSummaries.map((chat) {
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
                            width: 150, // Ancho fijo para cada elemento
                            height:
                                150 / 1.5, // Mantiene la proporción original
                            child: FutureBuilder<User?>(
                              future: future,
                              builder: (ctx, snapshot) {
                                return Material(
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
                                );
                              },
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
    );
  }
}
