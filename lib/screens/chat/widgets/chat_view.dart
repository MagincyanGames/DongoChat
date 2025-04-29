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

  Timer? _refreshTimer;
  bool _isLoading = false;
  ObjectId? reply;
  ObjectId? _highlightedMessageId;
  final Map<ObjectId, MessageBubble> _bubbleCache = {};
  bool _showScrollButton = false;

  @override
  void initState() {
    super.initState();

    print("ChatViewState initState");

    WidgetsBinding.instance.addObserver(this);

    // Mejorar el detector de posición para mostrar/ocultar el botón
    _itemPositionsListener.itemPositions.addListener(() {
      if (!mounted) return;

      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        // Verificar si el primer elemento (índice 0) está visible
        // lo que significa que estamos en el fondo
        bool isAtBottom = false;

        for (final position in positions) {
          if (position.index == 0) {
            isAtBottom = true;
            break;
          }
        }

        // Sólo mostrar botón si NO estamos en el fondo
        final shouldShow = !isAtBottom;

        if (_showScrollButton != shouldShow) {
          setState(() {
            _showScrollButton = shouldShow;
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRefreshTimer();
      _scrollToBottom();
      _textFieldFocus.requestFocus();
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
    if (hasNewMessages && mounted) setState(() {});
  }

  // Método principal para scroll a la parte inferior
  void _scrollToBottom() {
    if (!_itemScrollController.isAttached) return;

    try {
      // Para listas con reverse: true, el índice 0 es el mensaje más reciente
      _itemScrollController.scrollTo(
        index: 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0, // Esto fuerza alineación en la parte visible
      );

      // Limpia el resaltado después de un tiempo
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
    } catch (e) {
      print('Error en scrollToBottom: $e');
    }
  }

  // Método para asegurar que el campo de entrada es visible
  void _ensureInputIsVisible() {
    // Usar el mismo método _scrollToBottom para consistencia
    _scrollToBottom();
  }

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

    // Limpiar el campo de texto inmediatamente para mejor UX
    _controller.clear();

    // Actualizar estado a "cargando"
    setState(() => _isLoading = true);

    // Preparar datos de respuesta si existen
    MessageData? messageData =
        reply != null ? MessageData(resend: reply) : null;

    // Limpiar estado de respuesta
    setState(() => reply = null);

    try {
      // Enviar mensaje
      await widget.onSendMessage(
        text,
        widget.currentUser?.id ?? ObjectId(),
        messageData,
      );

      // Después de enviar con éxito, hacer scroll
      if (mounted) {
        // Usamos microtask para asegurar que la UI se actualice primero
        Future.microtask(() {
          // Añadimos PostFrameCallback para garantizar que el widget tree
          // está completamente actualizado antes de hacer scroll
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToBottom();
          });
        });
      }
    } catch (e) {
      // Manejar error si ocurre
      if (mounted) {
        _showSnackbar('Error al enviar mensaje: ${e.toString()}');
      }
    } finally {
      // Actualizar estado y devolver foco al campo de texto
      if (mounted) {
        setState(() => _isLoading = false);
        _textFieldFocus.requestFocus();
      }
    }
  }

  void setReplyMessage(ObjectId messageId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          reply = messageId;
        });
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
        );
        setState(() {
          _highlightedMessageId = messageId;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _highlightedMessageId = null);
        });
      } catch (_) {}
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

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child:
                  messages.isEmpty
                      ? const Center(child: Text('No hay mensajes aún'))
                      : ScrollablePositionedList.builder(
                        // Solo reconstruir la lista cuando cambia su longitud
                        key: ValueKey('chat-list'),
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        itemCount: messages.length,
                        reverse: true,
                        padding: const EdgeInsets.all(8),
                        addAutomaticKeepAlives: true,
                        minCacheExtent: 2000,
                        itemBuilder: (context, index) {
                          final actualIndex = messages.length - 1 - index;
                          final msg = messages[actualIndex];

                          // Usar el ID como llave única constante
                          final msgId = msg.id!;

                          // Verificar si necesitamos reconstruir la burbuja
                          final cachedBubble = _bubbleCache[msgId];
                          final shouldRebuild =
                              cachedBubble == null ||
                              cachedBubble.msg.message != msg.message;

                          if (shouldRebuild) {
                            // Solo reconstruir si realmente es necesario
                            print("rebubble for '$msgId'");
                            _bubbleCache[msgId] =  MessageBubble(
                              key: ValueKey(msgId),
                              chat: widget.chat,
                              msg: msg,
                              isHighlighted: _highlightedMessageId == msgId,
                              isMe: msg.sender == user?.id,
                              isConsecutive:
                                  actualIndex > 0 &&
                                  messages[actualIndex].sender ==
                                      messages[actualIndex - 1].sender,
                              onQuotedTap: (ObjectId targetId) {
                                scrollToMessage(targetId);
                              },
                              onReply: (ObjectId messageId) {
                                setReplyMessage(messageId);
                              },
                              onShowSnackbar: (String message) {
                                _showSnackbar(message);
                              },
                            );
                          }

                          return _bubbleCache[msgId]!;
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
                          reply != null
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
              Material(
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
            onPressed: () => setState(() => reply = null),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message) {
    if (!mounted) return;

    // Usar addPostFrameCallback para asegurar que el contexto sea válido
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
