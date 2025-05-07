import 'dart:async';
import 'dart:io' show Platform;
import 'package:dongo_chat/api/firebase_api.dart';
import 'package:dongo_chat/providers/user_cache_provider.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:dongo_chat/widgets/buttons/gradient/send-button.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/screens/chat/widgets/message_bundle.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChatView extends StatefulWidget {
  final Chat chat;
  final User? currentUser;
  final Future<void> Function(
    String text,
    ObjectId userId,
    MessageData? messageData,
  )
  onSendMessage;
  final Future<List<Message>> Function()
  onRefreshMessages; // Changed return type
  final Future<void> Function(ObjectId messageId)? onDeleteMessage;
  final VoidCallback? onChatInitialized;
  final bool isLoading;

  const ChatView({
    Key? key,
    required this.chat,
    required this.currentUser,
    required this.onSendMessage,
    required this.onRefreshMessages,
    this.onDeleteMessage,
    this.onChatInitialized,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<ChatView> createState() => ChatViewState();
}

class ChatViewState extends State<ChatView> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final GlobalKey _sendButtonKey = GlobalKey();

  // Caching maps
  final Map<ObjectId, Message> _quotedCache = {};

  Timer? _refreshTimer;
  String _loaddingState = 'none';
  MessageData messageData = MessageData();

  ObjectId? _highlightedMessageId;
  bool _showScrollButton = false;
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Scroll button visibility listener
    _itemPositionsListener.itemPositions.addListener(() {
      if (!mounted) return;

      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        bool isAtBottom = false;
        for (final position in positions) {
          if (position.index == 0) {
            isAtBottom = true;
            break;
          }
        }
        final shouldShow = !isAtBottom;
        if (_showScrollButton != shouldShow) {
          setState(() => _showScrollButton = shouldShow);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchMetadata().then((_) {
        setState(() => _initialLoadDone = true);
        _startRefreshTimer();
        _scrollToBottom();
        _textFieldFocus.requestFocus();
        widget.onChatInitialized?.call();
      });
    });
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshMessages();
    });
  }

  Future<void> _refreshMessages() async {
    try {
      final changedMessages = await widget.onRefreshMessages();
      if (!mounted) return;

      // Get existing messages map for quick lookup
      final existingMessagesById = <String, Message>{};
      for (var msg in widget.chat.messages) {
        if (msg.id != null) {
          existingMessagesById[msg.id!.oid] = msg;
        }
      }

      // Process changed messages
      for (final newMsg in changedMessages) {
        if (newMsg.id != null) {
          existingMessagesById[newMsg.id!.oid] = newMsg;
        }
      }

      // Keep messages without IDs (likely pending messages)
      final pendingMessages =
          widget.chat.messages.where((msg) => msg.id == null).toList();

      // Combine existing, changed, and pending messages
      final updatedMessages = [
        ...existingMessagesById.values,
        ...pendingMessages,
      ];

      // Sort messages by timestamp
      updatedMessages.sort(
        (a, b) => (a.timestamp ?? DateTime.now()).compareTo(
          b.timestamp ?? DateTime.now(),
        ),
      );

      await _prefetchMetadata();

      if (mounted) {
        setState(() {
          widget.chat.messages = updatedMessages;
        });
      }
    } catch (e) {
      print('Error refreshing messages: $e');
    }
  }

  Future<void> _prefetchMetadata() async {
    final msgs = widget.chat.messages;
    final userCache = Provider.of<UserCacheProvider>(context, listen: false);

    try {
      // First, collect all the needed IDs
      final Set<ObjectId> neededUsers = {};
      final Set<ObjectId> neededQuotes = {};

      for (final msg in msgs) {
        if (msg.sender != null) {
          neededUsers.add(msg.sender!);
        }

        // Ensure we get all quoted messages
        if (msg.data?.resend != null) {
          neededQuotes.add(msg.data!.resend!);
        }
      }

      // Prefetch users not in cache
      final usersToFetch =
          neededUsers.where((id) => userCache.getUser(id) == null).toList();

      for (final userId in usersToFetch) {
        try {
          final user = await DBManagers.user.Get(userId);
          if (user != null && mounted) {
            userCache.cacheUser(user);
          }
        } catch (e) {
          print('Error fetching user $userId: $e');
        }
      }

      // Prefetch quoted messages not in cache
      final quotesToFetch =
          neededQuotes.where((id) => !_quotedCache.containsKey(id)).toList();

      if (quotesToFetch.isNotEmpty) {
        print('Fetching ${quotesToFetch.length} quoted messages');
      }

      for (final quoteId in quotesToFetch) {
        try {
          final quote = await widget.chat.findMessageById(quoteId);
          if (quote != null && mounted) {
            _quotedCache[quoteId] = quote;
          } else {
            // Try to find in existing messages
            final foundMsg = msgs.firstWhere(
              (msg) => msg.id == quoteId,
              orElse: () => Message(message: "Mensaje no encontrado"),
            );
            if (foundMsg.message != "Mensaje no encontrado" && mounted) {
              _quotedCache[quoteId] = foundMsg;
            }
          }
        } catch (e) {
          print('Error fetching quoted message $quoteId: $e');
        }
      }
    } catch (e) {
      print('Error in prefetch metadata: $e');
    }
  }

  void _scrollToBottom() {
    if (!_itemScrollController.isAttached) return;

    try {
      _itemScrollController.scrollTo(
        index: 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
    } catch (e) {
      print('Error in scrollToBottom: $e');
    }
  }

  void _ensureInputIsVisible() => _scrollToBottom();

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset > 0) {
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() => _loaddingState = 'loading');

    try {
      print('Sending message: $text');
      await widget.onSendMessage(
        text,
        widget.currentUser?.id ?? ObjectId(),
        messageData,
      );
      print('Message sent: $text');
      setState(() {
        _loaddingState = 'none';
        messageData = MessageData();
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error al enviar mensaje: ${e}');
      }
    } finally {
      if (mounted) {
        setState(() => _loaddingState = 'none');
        _textFieldFocus.requestFocus();
      }
    }
  }

  void setReplyMessage(ObjectId messageId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => messageData.resend = messageId);
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            _textFieldFocus.requestFocus();
            _ensureInputIsVisible();
          }
        });
      }
    });
  }

  void scrollToMessage(ObjectId messageId) {
    final messages = widget.chat.messages;
    final index = messages.indexWhere((msg) => msg.id == messageId);

    if (index != -1 && _itemScrollController.isAttached) {
      try {
        final reversedIndex = messages.length - 1 - index;
        _itemScrollController.scrollTo(
          index: reversedIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
        setState(() => _highlightedMessageId = messageId);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _highlightedMessageId = null);
        });
      } catch (e) {
        print('Error scrolling to message: $e');
      }
    }
  }

  void _showMessageTypeMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromCenter(
          center: position.translate(0, -20),
          width: 40,
          height: 40,
        ),
        Offset.zero & overlay.size,
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem<String>(
          value: 'text',
          child: Row(
            children: [Icon(Icons.message), SizedBox(width: 8), Text('Texto')],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'apk',
          child: Row(
            children: [Icon(Icons.android), SizedBox(width: 8), Text('APK')],
          ),
        ),
      ],
    ).then((String? value) {
      if (value != null) {
        // Handle different message types
        switch (value) {
          case 'text':
            _sendMessage();
            break;
          case 'apk':
            var splt = _controller.text.trim().split('\n');

            _controller.text = splt.length > 1 ? splt[0].trim() : 'apk';
            messageData.url = splt[1].trim();
            messageData.type = 'apk';
            _sendMessage();
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textFieldFocus.dispose();
    // Asegúrate de que el timer se cancele correctamente
    if (_refreshTimer != null) {
      print('Canceling refresh timer in ChatView dispose');
      _refreshTimer!.cancel();
      _refreshTimer = null;
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.chat.messages;
    final user = widget.currentUser;
    final bool hasWritePermission = widget.chat.canWrite(widget.currentUser);
    final userCache = Provider.of<UserCacheProvider>(context);

    if (!_initialLoadDone) {
      return const Center(child: CircularProgressIndicator());
    }

    // Get route information
    final currentRoute = ModalRoute.of(context);
    final isCurrentRouteChat = currentRoute?.settings.name == '/chat';

    return Provider.value(
      value: userCache.allUsers,
      // Add this AnimatedBuilder for entrance animation
      child: AnimatedBuilder(
        animation: currentRoute?.animation ?? const AlwaysStoppedAnimation(1.0),
        builder: (context, child) {
          final animationValue = currentRoute?.animation?.value ?? 1.0;

          return Stack(
            children: [
              // Apply transform to the chat content
              Transform.translate(
                offset: Offset(
                  (1 - animationValue) * 100,
                  0,
                ), // Slide in from right
                child: Opacity(
                  opacity: animationValue,
                  child: Column(
                    children: [
                      Expanded(
                        child:
                            messages.isEmpty
                                ? const Center(
                                  child: Text('No hay mensajes aún'),
                                )
                                : ScrollablePositionedList.builder(
                                  key: const PageStorageKey('chat-list'),
                                  itemScrollController: _itemScrollController,
                                  itemPositionsListener: _itemPositionsListener,
                                  itemCount: messages.length,
                                  reverse: true,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  addAutomaticKeepAlives: false,
                                  minCacheExtent: 2000,
                                  itemBuilder: (context, index) {
                                    final actualIndex =
                                        messages.length - 1 - index;
                                    final msg = messages[actualIndex];
                                    final msgId = msg.id!;

                                    // Check if this message is consecutive
                                    final isConsecutive =
                                        actualIndex > 0 &&
                                        messages[actualIndex].sender ==
                                            messages[actualIndex - 1].sender;

                                    // Get quoted message if available
                                    final quoted =
                                        msg.data?.resend != null
                                            ? (_quotedCache[msg
                                                    .data!
                                                    .resend!] ??
                                                Message(
                                                  id: msg.data!.resend,
                                                  message:
                                                      "Cargando mensaje...",
                                                ))
                                            : null;

                                    return MessageBubble(
                                      key: ValueKey(msgId),
                                      msg: msg,
                                      me: user?.id ?? ObjectId(),
                                      user: userCache.getUser(msg.sender),
                                      quoted: quoted,
                                      isConsecutive: isConsecutive,
                                      isHighlighted:
                                          _highlightedMessageId == msgId,
                                      onQuotedTap: scrollToMessage,
                                      onReply: setReplyMessage,
                                      onShowSnackbar: _showSnackbar,
                                      onQuickReply: _quickReply,
                                    );
                                  },
                                ),
                      ),
                      _buildMessageInput(hasWritePermission),
                    ],
                  ),
                ),
              ),

              // Scroll button - keep this the same
              Positioned(
                right: 16,
                bottom: 80,
                child: AnimatedOpacity(
                  opacity: _showScrollButton ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child:
                      _showScrollButton
                          ? FloatingActionButton(
                            mini: true,
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            onPressed: _scrollToBottom,
                            child: const Icon(Icons.keyboard_arrow_down),
                          )
                          : const SizedBox.shrink(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageInput(bool hasWritePermission) {
    if (!hasWritePermission) {
      // Return a read-only notice instead of input field when no permission
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'No tienes permiso para escribir en este chat',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // Original input field code for users with permission
    return Column(
      children: [
        if (messageData.resend != null) _buildReplyIndicator(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: (FocusNode node, KeyEvent event) {
                    if (!Platform.isAndroid && !Platform.isIOS) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter) {
                        if (!HardwareKeyboard.instance.isShiftPressed) {
                          _sendMessage();
                          return KeyEventResult.handled;
                        }
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Theme.of(context)
                                  .extension<ChatTheme>()
                                  ?.otherMessageGradient
                                  .last ??
                              Colors.blue.shade900,
                          Theme.of(context)
                                  .extension<ChatTheme>()
                                  ?.myMessageGradient
                                  .first ??
                              Colors.deepPurple.shade900,
                        ],
                      ).withOpacity(0.6),
                    ),
                    padding: const EdgeInsets.all(2), // Grosor del borde
                    child: TextFormField(
                      focusNode: _textFieldFocus,
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      textAlignVertical: TextAlignVertical.center,
                      expands: false,
                      style: const TextStyle(height: 1.5),
                      decoration: InputDecoration(
                        hintText:
                            messageData.resend != null
                                ? 'Responder a mensaje...'
                                : 'Escribe un mensaje…',
                        hintStyle: const TextStyle(height: 1.5),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none, // Quitar borde interno
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        isDense: true,
                        alignLabelWithHint: true,
                        isCollapsed: false,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SendButton(
                key: _sendButtonKey,
                sendMessage: () {
                  return hasWritePermission;
                },
                loaddingState: _loaddingState,
                onSendMessage: _sendMessage,
                loadContextualMenu: (context) {
                  // Get the position of the button using its key
                  final RenderBox? buttonBox =
                      _sendButtonKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  if (buttonBox != null) {
                    // Get the position of the center of the button
                    final buttonPosition = buttonBox.localToGlobal(
                      buttonBox.size.center(Offset.zero),
                    );
                    _showMessageTypeMenu(context, buttonPosition);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageTypeButton(String type) {
    if (type == 'loading' || widget.isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }
    if (type == 'pushing') {
      return TweenAnimationBuilder<double>(
        key: const ValueKey('pushing'),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        onEnd: () {
          if (mounted && _loaddingState == 'pushing') {
            setState(() {}); // Restart animation while in pushing state
          }
        },
        builder: (context, value, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                transform: GradientRotation(value * 2 * 3.14159),
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcIn,
            child: Icon(
              Icons.campaign,
              color:
                  Theme.of(context).extension<ChatTheme>()?.actionIconColor ??
                  Colors.white,
              size: 24,
            ),
          );
        },
      );
    } else {
      return Icon(
        Icons.send,
        color:
            Theme.of(context).extension<ChatTheme>()?.actionIconColor ??
            Colors.white,
        size: 24,
      );
    }
  }

  Widget _buildReplyIndicator() {
    final messages = widget.chat.messages;
    final replyMessage = messages.firstWhere(
      (msg) => msg.id == messageData.resend,
      orElse: () => Message(message: "Mensaje no encontrado"),
    );
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
            margin: const EdgeInsets.only(right: 8),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Respondiendo a:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  replyMessage.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: theme.colorScheme.primary, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              minimumSize: const Size(36, 36),
            ),
            onPressed: () => setState(() => messageData.resend = null),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  _quickReply(ObjectId messageId, String text) {
    setReplyMessage(messageId);
    _controller.text = text;
    _sendMessage();
  }
}
