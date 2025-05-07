import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/utils/dialog_service.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:provider/provider.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:dongo_chat/providers/user_cache_provider.dart';

class ChatSummaryView extends StatefulWidget {
  final ChatSummary chat;
  final User? currentUser;
  final ValueChanged<ChatSummary> onChatSelected;
  final Function(BuildContext, ChatSummary, User?, dynamic)? onShowContextMenu;

  const ChatSummaryView({
    Key? key,
    required this.chat,
    required this.currentUser,
    required this.onChatSelected,
    this.onShowContextMenu,
  }) : super(key: key);

  @override
  _ChatSummaryViewState createState() => _ChatSummaryViewState();
}

class _ChatSummaryViewState extends State<ChatSummaryView> {
  String _prettify(String input) {
    final withSpaces = input.replaceAll('-', ' ');
    if (withSpaces.isEmpty) return withSpaces;
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = theme.extension<ChatTheme>();
    final name = _prettify(widget.chat.name ?? 'Unnamed');
    final userCache = Provider.of<UserCacheProvider>(context, listen: false);

    final bool canWrite = widget.currentUser != null && widget.chat.canWrite(widget.currentUser);

    User? lastMessageUser;
    if (widget.chat.latestMessage?.sender != null) {
      lastMessageUser = userCache.getUser(widget.chat.latestMessage!.sender!);
      if (lastMessageUser == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            DBManagers.user.Get(widget.chat.latestMessage!.sender!).then((user) {
              if (user != null && mounted) {
                userCache.cacheUser(user);
                setState(() {});
              }
            });
          }
        });
      }
    }

    return SizedBox(
      width: 240, // Increased from 200 to give more space
      height: 150 / 1.5,
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          if (widget.onShowContextMenu != null) {
            widget.onShowContextMenu!(context, widget.chat, widget.currentUser, details);
          }
        },
        onLongPressStart: (details) {
          if (widget.onShowContextMenu != null) {
            widget.onShowContextMenu!(context, widget.chat, widget.currentUser, details.localPosition);
          }
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            splashColor:
                chatTheme?.otherQuotedMessageBorderColor?.withOpacity(
                  0.3,
                ) ??
                theme.colorScheme.primary.withOpacity(0.3),
            onTap: () => widget.onChatSelected(widget.chat),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12, // Reduced from 14 to give more space to content
                vertical: 10,   // Reduced from 12 for better spacing
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 9, // Giving more weight to the name
                        child: Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        canWrite ? Icons.edit : Icons.lock_outline,
                        size: 14, // Reduced from 16
                        color:
                            canWrite
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                      ),
                    ],
                  ),
                  Divider(
                    height: 12,
                    thickness: 1,
                    color: theme.dividerColor.withOpacity(0.3),
                  ),
                  if (widget.chat.latestMessage != null) ...[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (lastMessageUser != null)
                                Text(
                                  lastMessageUser.displayName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (lastMessageUser == null)
                                Text(
                                  "Desconocido",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          Text(
                            widget.chat.latestMessage!.message,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: Center(
                        child: Text(
                          "No hay mensajes",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(
                              0.5,
                            ),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}