import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:dongo_chat/screens/chat/widgets/message_bundle.dart';

class ChatView extends StatefulWidget {
  final Chat chat;
  final User? currentUser;
  final Future<void> Function(String text, ObjectId userId, MessageData? messageData) onSendMessage;
  final Future<bool> Function() onRefreshMessages;
  final Future<void> Function(ObjectId messageId)? onDeleteMessage; // Nuevo callback opcional
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
  
  Timer? _refreshTimer;
  bool _isLoading = false;
  ObjectId? reply;
  ObjectId? _highlightedMessageId;
  final Map<ObjectId, MessageBubble> _bubbleCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRefreshTimer();
      _scrollToBottomWithDelay();
      _textFieldFocus.requestFocus();
    });

    _textFieldFocus.addListener(() {
      if (_textFieldFocus.hasFocus) {
        _scrollToBottomInstant();
      }
    });
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _refreshMessages();
    });
  }

  void _refreshMessages() async {
    if (!mounted) return;

    final hasNewMessages = await widget.onRefreshMessages();
    if (hasNewMessages && mounted) {
      setState(() {});
      _scrollToBottomWithDelay();
    }
  }

  void _scrollToBottomWithDelay() {
    final messages = widget.chat.messages;
    if (messages.isEmpty) return;

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_itemScrollController.isAttached) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final lastIndex = messages.length - 1;
        if (lastIndex >= 0) {
          _itemScrollController.scrollTo(
            index: lastIndex,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            alignment: 0.9,
          );
        }
      });
    });
  }

  void _scrollToBottomInstant() {
    if (!_itemScrollController.isAttached) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messages = widget.chat.messages;
      final lastIndex = messages.length - 1;
      if (lastIndex >= 0) {
        _itemScrollController.jumpTo(index: lastIndex);
      }
    });
  }

  @override
  void didChangeMetrics() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset > 0) {
      _scrollToBottomAfterKeyboardOpens();
    }
    super.didChangeMetrics();
  }

  void _scrollToBottomAfterKeyboardOpens() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messages = widget.chat.messages;
      final lastIndex = messages.length - 1;
      if (_itemScrollController.isAttached && lastIndex >= 0) {
        _itemScrollController.scrollTo(
          index: lastIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: 1.0,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _textFieldFocus.requestFocus();
    setState(() => _isLoading = true);

    try {
      MessageData? messageData = reply != null ? MessageData(resend: reply) : null;
      setState(() => reply = null);

      await widget.onSendMessage(
        text, 
        widget.currentUser?.id ?? ObjectId(), 
        messageData
      );

      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottomWithDelay();
          _textFieldFocus.requestFocus();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'))
      );
      _textFieldFocus.requestFocus();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _textFieldFocus.requestFocus();
      }
    }
  }

  void setReplyMessage(ObjectId messageId) {
    setState(() {
      reply = messageId;
    });
    _textFieldFocus.requestFocus();
  }

  void scrollToMessage(ObjectId messageId) {
    final messages = widget.chat.messages;
    final index = messages.indexWhere((msg) => msg.id == messageId);

    if (index != -1 && _itemScrollController.isAttached) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _itemScrollController.scrollTo(
          index: index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        setState(() {
          _highlightedMessageId = messageId;
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _highlightedMessageId = null);
          }
        });
      });
    }
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

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(child: Text('No hay mensajes aún'))
              : ScrollablePositionedList.builder(
                  itemScrollController: _itemScrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final cachedBubble = _bubbleCache[msg.id!];

                    if (cachedBubble == null || cachedBubble.msg.message != msg.message) {
                      _bubbleCache[msg.id!] = MessageBubble(
                        key: ValueKey(msg.id),
                        chat: widget.chat,
                        msg: msg,
                        isMe: msg.sender == user?.id,
                        isConsecutive: index > 0 && messages[index].sender == messages[index - 1].sender,
                        onQuotedTap: (ObjectId targetId) {
                          scrollToMessage(targetId);
                        }, onReply: (ObjectId messageId) { reply = messageId; },
                      );
                    }

                    return _bubbleCache[msg.id!]!;
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: _buildMessageInput(),
        ),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Column(
      children: [
        if (reply != null) _buildReplyIndicator(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: (FocusNode node, KeyEvent event) {
                    if (!Platform.isAndroid && !Platform.isIOS) {
                      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
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
                      hintText: reply != null ? 'Responder a mensaje...' : 'Escribe un mensaje…',
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
              Material(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: _isLoading || widget.isLoading ? null : _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: _isLoading || widget.isLoading
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyIndicator() {
    final messages = widget.chat.messages;
    final replyMessage = messages.firstWhere(
      (msg) => msg.id == reply,
      orElse: () => Message(message: "Mensaje no encontrado", iv: ""),
    );

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
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
                  style: TextStyle(color: theme.colorScheme.onSurface),
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
            onPressed: () => setState(() => reply = null),
          ),
        ],
      ),
    );
  }
}