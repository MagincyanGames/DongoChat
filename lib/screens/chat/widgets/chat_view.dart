import 'dart:async';
import 'dart:io' show Platform;
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

class ChatView extends StatefulWidget {
  final Chat chat;
  final User? currentUser;
  final Future<void> Function(
    String text,
    ObjectId userId,
    MessageData? messageData,
  )
  onSendMessage;
  final Future<bool> Function() onRefreshMessages;
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
  final Map<ObjectId, User> _userCache = {};
  final Map<ObjectId, Message> _quotedCache = {};

  Timer? _refreshTimer;
  bool _isLoading = false;
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
    if (!mounted) return;

    final hasNewMessages = await widget.onRefreshMessages();

    // Always refresh the metadata to ensure quotes are up to date
    await _prefetchMetadata();

    if (hasNewMessages || messageData.resend != null) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _prefetchMetadata() async {
    final userMgr = DBManagers.user;
    final msgs = widget.chat.messages;

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
          neededUsers.where((id) => !_userCache.containsKey(id)).toList();
      for (final userId in usersToFetch) {
        try {
          final user = await userMgr.findById(userId);
          if (user != null) _userCache[userId] = user;
        } catch (e) {
          print('Error fetching user $userId: $e');
        }
      }

      // Prefetch quoted messages not in cache
      final quotesToFetch =
          neededQuotes.where((id) => !_quotedCache.containsKey(id)).toList();

      // Log for debugging
      if (quotesToFetch.isNotEmpty) {
        print('Fetching ${quotesToFetch.length} quoted messages');
      }

      for (final quoteId in quotesToFetch) {
        try {
          final quote = await widget.chat.findMessageById(quoteId);
          if (quote != null) {
            _quotedCache[quoteId] = quote;
            print('Cached quoted message: ${quote.id}');
          } else {
            print('Failed to find quoted message: $quoteId');
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
    setState(() => _isLoading = true);

    try {
      await widget.onSendMessage(
        text,
        widget.currentUser?.id ?? ObjectId(),
        messageData,
      );

      setState(() => messageData = MessageData());
      
      // Force a metadata refresh to ensure quotes are cached
      await _prefetchMetadata();

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error al enviar mensaje: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
    _refreshTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.chat.messages;
    final user = widget.currentUser;

    if (!_initialLoadDone) {
      return const Center(child: CircularProgressIndicator());
    }

    return Provider.value(
      value: _userCache,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child:
                    messages.isEmpty
                        ? const Center(child: Text('No hay mensajes aún'))
                        : ScrollablePositionedList.builder(
                          key: const PageStorageKey('chat-list'),
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                          itemCount: messages.length,
                          reverse: true,
                          padding: const EdgeInsets.all(8),
                          addAutomaticKeepAlives: false,
                          minCacheExtent: 2000,
                          itemBuilder: (context, index) {
                            final actualIndex = messages.length - 1 - index;
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
                                    ? (_quotedCache[msg.data!.resend!] ??
                                        Message(
                                          id: msg.data!.resend,
                                          message: "Cargando mensaje...",
                                          iv: "",
                                        ))
                                    : null;

                            return MessageBubble(
                              key: ValueKey(msgId),
                              msg: msg,
                              me: user?.id ?? ObjectId(),
                              user: _userCache[msg.sender],
                              quoted: quoted,
                              isConsecutive: isConsecutive,
                              isHighlighted: _highlightedMessageId == msgId,
                              onQuotedTap: scrollToMessage,
                              onReply: setReplyMessage,
                              onShowSnackbar: _showSnackbar,
                            );
                          },
                        ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: _buildMessageInput(),
              ),
            ],
          ),
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
      ),
    );
  }

  Widget _buildMessageInput() {
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
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
              const SizedBox(width: 8),
              GestureDetector(
                onLongPress: () {
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
                child: Material(
                  key: _sendButtonKey, // Add this key to the Material widget
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: _isLoading || widget.isLoading ? null : _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child:
                          _isLoading || widget.isLoading
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 24,
                              ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyIndicator() {
    final messages = widget.chat.messages;
    final replyMessage = messages.firstWhere(
      (msg) => msg.id == messageData.resend,
      orElse: () => Message(message: "Mensaje no encontrado", iv: ""),
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
}
