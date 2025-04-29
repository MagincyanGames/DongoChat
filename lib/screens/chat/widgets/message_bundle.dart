import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:provider/provider.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:dongo_chat/utils/time_ago.dart';
import 'package:dongo_chat/screens/chat/widgets/message_context_menu.dart';

class MessageBubble extends StatelessWidget {
  final Message msg;
  final ObjectId me;
  final User? user;
  final Message? quoted;
  final bool isConsecutive;
  final bool isHighlighted;
  final Function(ObjectId) onQuotedTap;
  final Function(ObjectId) onReply;
  final Function(String)? onShowSnackbar;

  const MessageBubble({
    Key? key,
    required this.msg,
    required this.me,
    this.user,
    this.quoted,
    this.isConsecutive = false,
    this.isHighlighted = false,
    required this.onQuotedTap,
    required this.onReply,
    this.onShowSnackbar,
  }) : super(key: key);

  bool get isMe => msg.sender == me;

  void _showContextMenu(BuildContext context, Offset tapPosition) {
    showMessageContextMenu(
      context: context,
      position: tapPosition,
      message: msg,
      isMe: isMe,
      onReply: onReply,
      onShowSnackbar: onShowSnackbar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Create the message content container
    final messageContainer = Container(
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
                colors: theme.extension<ChatTheme>()?.myMessageGradient ??
                    [Colors.deepPurple, Colors.deepPurple.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: theme.extension<ChatTheme>()?.otherMessageGradient ??
                    [Colors.blue.shade900, Colors.blue.shade700],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quoted != null) _buildQuotedMessage(quoted!, theme),
          Text(
            msg.message,
            style: TextStyle(
              color: isMe
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSecondary,
            ),
          ),
          if (!isConsecutive) const SizedBox(height: 4),
          Text(
            _getFormattedTime(msg.timestamp!),
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: isMe
                  ? theme.colorScheme.onPrimary.withOpacity(0.5)
                  : theme.colorScheme.onSecondary.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );

    // Create the full message widget with username if needed
    final messageContent = Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!isConsecutive && user != null)
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
              user?.displayName ?? 'Desconocido',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
        // Apply the highlight effect only to the message container
        if (isHighlighted) 
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3 * value),
                      blurRadius: 8 * value,
                      spreadRadius: 2 * value,
                    ),
                  ],
                ),
                child: Transform.scale(
                  scale: 1.0 + (0.05 * value),
                  child: child,
                ),
              );
            },
            child: messageContainer,
          )
        else
          messageContainer,
      ],
    );

    // Wrap with gesture detector and alignment
    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      onLongPress: () {
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        final tapPosition = Offset(
          position.dx + size.width / 2,
          position.dy + size.height / 2,
        );
        _showContextMenu(context, tapPosition);
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: messageContent,
      ),
    );
  }

  Widget _buildQuotedMessage(Message originalMessage, ThemeData theme) {
    final chatTheme = theme.extension<ChatTheme>();
    
    return Builder(builder: (context) {
      final isMyMessage = originalMessage.sender == me;

      // Choose border and background colors based on who is the author
      final borderColor = isMe
          ? chatTheme?.myQuotedMessageBorderColor
          : chatTheme?.otherQuotedMessageBorderColor;

      final backgroundColor = isMyMessage
          ? chatTheme?.myQuotedMessageBackgroundColor
          : chatTheme?.otherQuotedMessageBackgroundColor;

      return GestureDetector(
        onTap: () {
          onQuotedTap(originalMessage.id!);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor ?? theme.colorScheme.surfaceVariant.withOpacity(0.7),
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
              Text(
                Provider.of<Map<ObjectId, User>>(context, listen: false)[originalMessage.sender]?.displayName ?? 'Desconocido',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: borderColor ?? theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                originalMessage.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: chatTheme?.quotedMessageTextColor ?? theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  String _getFormattedTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    // If the message is from today
    if (messageDate.isAtSameMomentAs(today)) {
      return TimeAgo.getTimeAgo(timestamp);
    } 
    // If the message is from yesterday or earlier
    else {
      // Format the date and time
      final hours = timestamp.hour.toString().padLeft(2, '0');
      final minutes = timestamp.minute.toString().padLeft(2, '0');
      
      // If it's from this year, don't show the year
      if (timestamp.year == now.year) {
        return '${timestamp.day}/${timestamp.month} $hours:$minutes';
      } else {
        return '${timestamp.day}/${timestamp.month}/${timestamp.year} $hours:$minutes';
      }
    }
  }
}
