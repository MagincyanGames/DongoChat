import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/theme/chat_theme.dart';

class ChatSelectionScreen extends StatefulWidget {
  final ValueChanged<String> onChatSelected;
  const ChatSelectionScreen({Key? key, required this.onChatSelected})
    : super(key: key);

  @override
  State<ChatSelectionScreen> createState() => _ChatSelectionScreenState();
}

class _ChatSelectionScreenState extends State<ChatSelectionScreen> {
  late Future<List<Chat>> _chatsFuture;

  @override
  void initState() {
    super.initState();
    _chatsFuture = DBManagers.chat.findAll();
  }

  String _prettify(String input) {
    final withSpaces = input.replaceAll('-', ' ');
    if (withSpaces.isEmpty) return withSpaces;
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = theme.extension<ChatTheme>();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            chatTheme?.otherMessageGradient.last ?? Colors.blue.shade900,
            chatTheme?.myMessageGradient.first ?? Colors.deepPurple.shade900,
          ],
        ).withOpacity(0.6),
      ),
      child: FutureBuilder<List<Chat>>(
        future: _chatsFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return const Center(child: Text('Error cargando chats'));
          }
          final chats = snap.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final chat = chats[i];
              final name = _prettify(chat.name ?? 'Unnamed');
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  splashColor:
                      chatTheme?.otherQuotedMessageBorderColor?.withOpacity(
                        0.3,
                      ) ??
                      theme.colorScheme.primary.withOpacity(0.3),
                  onTap: () => widget.onChatSelected(chat.name!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          chatTheme?.otherQuotedMessageBackgroundColor ??
                          theme.colorScheme.surfaceVariant.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                          color:
                              chatTheme?.otherQuotedMessageBorderColor ??
                              theme.colorScheme.primary,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Text(
                      name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
