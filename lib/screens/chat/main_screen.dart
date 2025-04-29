import 'dart:async';
import 'dart:io' show Platform;
import 'package:dongo_chat/main.dart';
import 'package:dongo_chat/widgets/theme_toggle_button.dart';
import 'package:flutter/services.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:provider/provider.dart';
import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/database/managers/chat_manager.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/screens/chat/widgets/loadding_screen.dart';
import 'package:dongo_chat/screens/chat/widgets/message_bundle.dart';
import 'package:dongo_chat/screens/debug/debug_button.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'widgets/logout_button.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  // Paso 1: Añadir Observer
  final TextEditingController _controller = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();
  final ItemScrollController _itemScrollController = ItemScrollController();
  late final ChatManager _chatManager;
  late final DatabaseService dbService;
  String? _debugError;
  Timer? _refreshTimer;
  bool _isLoading = false;
  ObjectId? reply; // Add this variable to track the message being replied to
  ObjectId?
  _highlightedMessageId; // Add this variable to track the highlighted message
  final Map<ObjectId, MessageBubble> _bubbleCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Paso 2: Registrar Observer
    dbService = Provider.of<DatabaseService>(context, listen: false);
    _chatManager = DBManagers.chat;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
      _textFieldFocus.requestFocus();
    });

    // Enfoque del TextField
    _textFieldFocus.addListener(() {
      if (_textFieldFocus.hasFocus) {
        // Scroll instantáneo cuando se enfoca
        _scrollToBottomInstant();
      }
    });

    // REMOVER ESTE LISTENER - causa problemas de foco al escribir
    // _controller.addListener(() {
    //   _scrollToBottomWithDelay();
    // });
  }

  void _scrollToBottomAfterKeyboardOpens() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var messages = _chatManager.getGeneralChat().messages;

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

  @override
  void didChangeMetrics() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset > 0) {
      _scrollToBottomAfterKeyboardOpens();
    }
    super.didChangeMetrics();
  }

  void _scrollToBottomInstant() {
    if (!_itemScrollController.isAttached) return;

    // Ejecutar después de que se actualice la UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messages = _chatManager.getGeneralChat().messages;

      final lastIndex = messages.length - 1;
      if (lastIndex >= 0) {
        _itemScrollController.jumpTo(index: lastIndex);
      }
    });
  }

  Future<void> _initializeChat() async {
    _refreshTimer?.cancel();

    try {
      if (_chatManager.isGeneralChatReady) {
        _startRefreshTimer();
        return;
      }

      final success = await _chatManager.initGeneralChat();

      if (mounted) {
        setState(() {
          if (success) {
            _debugError = null;
            _startRefreshTimer();
            _scrollToBottomWithDelay();
          } else {
            _debugError = "Error al inicializar el chat";
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _debugError = error.toString());
      }
    }
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _refreshMessages();
    });
  }

  void _refreshMessages() async {
    if (!_chatManager.isGeneralChatReady || !mounted) return;

    final hasNewMessages = await _chatManager.checkForNewMessages();
    if (hasNewMessages && mounted) {
      setState(() {});
      _scrollToBottomWithDelay();
    }
  }

  void _scrollToBottomWithDelay() {
    final messages = _chatManager.getGeneralChat().messages;

    // Usar un retraso ligeramente mayor para asegurar que la UI esté lista
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_itemScrollController.isAttached) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final lastIndex = messages.length - 1;
        if (lastIndex >= 0) {
          _itemScrollController.scrollTo(
            index: lastIndex,
            // Aumentar la duración para una animación más suave
            duration: const Duration(milliseconds: 400),
            // Usar una curva más natural para el movimiento
            curve: Curves.easeOutCubic,
            // Añadir un pequeño offset para ver mejor el último mensaje
            alignment: 0.9,
          );
        }
      });
    });
  }

  Future<void> _sendMessage(ObjectId id) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    // Evita que pierda el foco al limpiar
    _textFieldFocus.requestFocus();
    setState(() => _isLoading = true);

    try {
      // Create MessageData with reply ID if we have a reply
      MessageData? messageData = MessageData(resend: reply);
      setState(() => reply = null);

      // Pass the messageData to addMessageToGeneral
      await _chatManager.addMessageToGeneral(text, id, messageData);

      if (mounted) {
        setState(() {});

        // Hacer scroll y luego solicitar foco nuevamente
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottomWithDelay();
          // Asegurar que el foco vuelva al campo
          _textFieldFocus.requestFocus();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      // Si hay error, también mantener el foco
      _textFieldFocus.requestFocus();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        // Y mantener foco después de todo
        _textFieldFocus.requestFocus();
      }
    }
  }

  // Add this method to set a message as a reply
  void setReplyMessage(ObjectId messageId) {
    setState(() {
      reply = messageId;
    });
    // Focus the text field after selecting to reply
    _textFieldFocus.requestFocus();
  }

  // Add this method to MainScreenState
  void scrollToMessage(ObjectId messageId) {
    final messages = _chatManager.getGeneralChat().messages;

    final index = messages.indexWhere((msg) => msg.id == messageId);

    if (index != -1 && _itemScrollController.isAttached) {
      // Esperar a que se estabilice el render
      Future.delayed(const Duration(milliseconds: 100), () {
        _itemScrollController.scrollTo(
          index: index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        // Visual feedback (highlight)
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
    WidgetsBinding.instance.removeObserver(this); // Paso 5: Limpiar Observer
    _textFieldFocus.dispose();
    _refreshTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final displayName = user?.displayName ?? 'Invitado';

    if (!_chatManager.isGeneralChatReady) {
      return LoadingChatScreen(error: _debugError, onRetry: _initializeChat);
    }

    final chat = _chatManager.getGeneralChat();
    final messages = chat.messages;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Flutter ajusta automáticamente
      appBar: AppBar(
        title: Text('DongoChat v${appVersion}'),
        actions: const [ThemeToggleButton(), DebugButton(), LogoutButton()],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                messages.isEmpty
                    ? const Center(child: Text('No hay mensajes aún'))
                    : ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final cachedBubble = _bubbleCache[msg.id!];

                        if (cachedBubble == null ||
                            cachedBubble.msg.message != msg.message) {
                          // Si no existe en la caché o el contenido ha cambiado, actualiza la caché
                          _bubbleCache[msg.id!] = MessageBubble(
                            key: ValueKey(msg.id),
                            chat: chat,
                            msg: msg,
                            isMe: msg.sender == user?.id,
                            isConsecutive:
                                index > 0 &&
                                messages[index].sender ==
                                    messages[index - 1].sender,
                            onQuotedTap: (ObjectId targetId) {
                              scrollToMessage(targetId);
                            },
                          );
                        }

                        return _bubbleCache[msg.id!]!;
                      },
                    ),
          ),
          // Simplificar el padding para evitar espacio excesivo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _buildMessageInput(user?.id ?? ObjectId()),
          ),
        ],
      ),
    );
  }

  // Modify _buildMessageInput to show reply indicator
  Widget _buildMessageInput(ObjectId id) {
    return Column(
      children: [
        // Show reply indicator if there's a reply
        if (reply != null) _buildReplyIndicator(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: (FocusNode node, KeyEvent event) {
                    // Solo aplicar en plataformas de escritorio (Windows, macOS, Linux)
                    if (!Platform.isAndroid && !Platform.isIOS) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter) {
                        // Si shift está presionado, permitir nueva línea (comportamiento predeterminado)
                        if (!HardwareKeyboard.instance.isShiftPressed) {
                          // Si no hay shift, enviar mensaje
                          _sendMessage(id);
                          return KeyEventResult
                              .handled; // Prevenir comportamiento predeterminado
                        }
                      }
                    }
                    return KeyEventResult
                        .ignored; // Comportamiento normal en otros casos
                  },
                  child: TextFormField(
                    focusNode: _textFieldFocus,
                    controller: _controller,
                    minLines: 1, // Mantiene 2 líneas mínimas
                    maxLines: 5, // Permite hasta 5 líneas antes de scrollear
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textAlignVertical: TextAlignVertical.center,
                    expands:
                        false, // Asegura que no se expanda más allá de lo necesario
                    style: TextStyle(
                      height: 1.5, // Aumentado para mejor distribución vertical
                    ),
                    decoration: InputDecoration(
                      hintText:
                          reply != null
                              ? 'Responder a mensaje...'
                              : 'Escribe un mensaje…',
                      hintStyle: TextStyle(
                        height: 1.5, // Aumentado igual que el estilo principal
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical:
                            16, // Aumentado de 10 a 16 para mejor centrado
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
                  onTap: _isLoading ? null : () => _sendMessage(id),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child:
                        _isLoading
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

  // Add this method to build the reply indicator
  Widget _buildReplyIndicator() {
    // Find the message being replied to
    final messages = _chatManager.getGeneralChat().messages;
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
