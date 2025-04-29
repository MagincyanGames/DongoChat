import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:provider/provider.dart';
import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/database/managers/chat_manager.dart';
import 'package:dongo_chat/database/managers/database_manager.dart';
import 'package:dongo_chat/database/managers/user_manager.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/utils/time_ago.dart';
import 'package:dongo_chat/screens/chat/widgets/message_context_menu.dart'; // Import the context menu

class MessageBubble extends StatefulWidget {
  final Chat chat;
  final Message msg;
  final bool isMe;
  final bool isConsecutive;
  final void Function(ObjectId targetMessageId) onQuotedTap;
  final void Function(ObjectId messageId) onReply; // Nuevo
  final void Function(ObjectId messageId)? onDelete; // Nuevo, opcional

  const MessageBubble({
    super.key,
    required this.chat,
    required this.msg,
    required this.isMe,
    this.isConsecutive = false,
    required this.onQuotedTap,
    required this.onReply,
    this.onDelete,
  });

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with AutomaticKeepAliveClientMixin {
  late final Future<User?> _futureUser;
  late Future<Message?> _originalMessageFuture = Future.value(null);
  late bool isMe;
  late bool isConsecutive;
  late Message msg;
  late Chat chat;

  @override
  void initState() {
    super.initState();
    print("Initializing MessageBubble for message: ${widget.msg.message}");
    final userManager = DBManagers.user;
    _futureUser = userManager.findById(widget.msg.sender);
    isMe = widget.isMe;
    isConsecutive = widget.isConsecutive;
    msg = widget.msg;
    chat = widget.chat;

    // Load referenced message if this is a reply
    if (msg.data?.resend != null) {
      print("Loading original message: ${msg.data!.resend}");
      _originalMessageFuture = chat.findMessageById(msg.data!.resend!);
    }
  }

  @override
  bool get wantKeepAlive => true; // Para que el State no se descarte

  void _showContextMenu(BuildContext context, Offset position, User? user) {
    showMessageContextMenu(
      context: context,
      position: position,
      message: widget.msg,
      isMe: widget.isMe,
      user: user,
      onReply: widget.onReply,
      onDelete: widget.onDelete,
    );
  }

  // Add this method to build the quoted message UI
  Widget _buildQuotedMessage(Message originalMessage, ThemeData theme) {
    final chatTheme = theme.extension<ChatTheme>();

    // Determinar si el mensaje citado es mío (como usuario actual)
    final isMyMessage =
        originalMessage.sender == context.watch<UserProvider>().user!.id;

    // Elegir el color del borde y fondo según quién es el autor del mensaje original
    final borderColor = isMe
        ? chatTheme?.myQuotedMessageBorderColor
        : chatTheme?.otherQuotedMessageBorderColor;

    final backgroundColor = isMyMessage
        ? chatTheme?.myQuotedMessageBackgroundColor
        : chatTheme?.otherQuotedMessageBackgroundColor;

    return GestureDetector(
      onTap: () {
        widget.onQuotedTap.call(originalMessage.id!);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor ??
              theme.colorScheme.surfaceVariant.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: borderColor ?? theme.colorScheme.primary,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<User?>(
              future: DBManagers.user.findById(originalMessage.sender),
              builder: (context, snapshot) {
                String userName = 'Desconocido';

                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData &&
                    snapshot.data != null) {
                  userName = snapshot.data!.displayName;
                }

                return Text(
                  userName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: borderColor ?? theme.colorScheme.primary,
                  ),
                );
              },
            ),
            const SizedBox(height: 2),
            Text(
              originalMessage.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: chatTheme?.quotedMessageTextColor ??
                    theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget futureBuilder(BuildContext context, AsyncSnapshot<User?> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    } else {
      final user = snapshot.data;
      final theme = Theme.of(context);

      // Wrap with GestureDetector to detect right-click and long press
      return GestureDetector(
        // Keep right-click for desktop/web
        onSecondaryTapUp: (details) {
          _showContextMenu(context, details.globalPosition, user);
        },
        // Add long press for mobile devices
        onLongPress: () {
          // Get the position for the context menu
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final position = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;

          // Position the menu near the center of the message bubble
          final tapPosition = Offset(
            position.dx + size.width / 2,
            position.dy + size.height / 2,
          );

          _showContextMenu(context, tapPosition, user);
        },
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isConsecutive)
                Container(
                  margin: EdgeInsets.only(
                    left: 8,
                    right: 8,
                    top: 16,
                    bottom: 0,
                  ),
                  padding: EdgeInsets.only(
                    left: isMe ? 0 : 10,
                    right: isMe ? 10 : 0,
                    bottom: 0,
                  ),
                  child: Text(
                    user != null ? user.displayName : 'Desconocido',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              Container(
                margin: const EdgeInsets.only(
                  left: 8,
                  right: 8,
                  top: 2,
                  bottom: 2,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: Theme.of(context)
                                  .extension<ChatTheme>()
                                  ?.myMessageGradient ??
                              [Colors.deepPurple, Colors.deepPurple.shade900],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: Theme.of(context)
                                  .extension<ChatTheme>()
                                  ?.otherMessageGradient ??
                              [Colors.blue.shade900, Colors.blue.shade700],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add the quoted message if this is a reply
                    if (msg.data?.resend != null)
                      FutureBuilder<Message?>(
                        future: _originalMessageFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Container(
                              height: 40,
                              width: 100,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant
                                    .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            );
                          }

                          if (snapshot.hasData && snapshot.data != null) {
                            return _buildQuotedMessage(snapshot.data!, theme);
                          }

                          return const SizedBox.shrink();
                        },
                      ),

                    Text(
                      msg.message,
                      style: TextStyle(
                        color: isMe
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                    if (!isConsecutive) const SizedBox(height: 4),
                    Text(
                      TimeAgo.getTimeAgo(msg.timestamp!),
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: isMe
                            ? Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.5)
                            : Theme.of(
                                context,
                              ).colorScheme.onSecondary.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    print("building ${msg.message}");
    return FutureBuilder<User?>(future: _futureUser, builder: futureBuilder);
  }
}
