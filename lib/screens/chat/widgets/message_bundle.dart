import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/database/managers/chat_manager.dart';
import 'package:dongo_chat/database/managers/database_manager.dart';
import 'package:dongo_chat/database/managers/user_manager.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/utils/time_ago.dart';

class MessageBubble extends StatefulWidget {
  final Message msg;
  final bool isMe;
  final bool isConsecutive;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.isMe,
    this.isConsecutive = false,
  });

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with AutomaticKeepAliveClientMixin {
  late final Future<User?> _futureUser;
  late bool isMe;
  late bool isConsecutive;
  late Message msg;

  @override
  void initState() {
    super.initState();

    final userManager = DBManagers.user;
    _futureUser = userManager.findById(widget.msg.sender);
    isMe = widget.isMe;
    isConsecutive = widget.isConsecutive;
    msg = widget.msg;

    print("$isMe - $isConsecutive - ${widget.msg.sender}");
  }

  @override
  bool get wantKeepAlive => true; // Para que el State no se descarte

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

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isConsecutive)
              Container(
                margin: EdgeInsets.only(left: 8, right: 8, top: 16, bottom: 0),
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
                gradient:
                    isMe
                        ? LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                        : LinearGradient(
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.secondary.withOpacity(0.8),
                            Theme.of(context).colorScheme.secondary,
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.message,
                    style: TextStyle(
                      color:
                          isMe
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
                      color:
                          isMe
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
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<User?>(future: _futureUser, builder: futureBuilder);
  }
}
