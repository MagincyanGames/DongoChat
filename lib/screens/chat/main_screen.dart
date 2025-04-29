import 'dart:async';
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
  final ScrollController _scrollController = ScrollController();
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

  @override
  void didChangeMetrics() {
    // Paso 3: Manejar cambios de teclado
    super.didChangeMetrics();
    _scrollToBottomWithDelay();
  }

  void _scrollToBottomInstant() {
    if (!_scrollController.hasClients) return;

    // Ejecutar después de que se actualice la UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Salto inmediato sin animación
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
    // Paso 4: Scroll optimizado
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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

    // Find the index of the message in the list
    final index = messages.indexWhere((msg) => msg.id == messageId);

    if (index != -1) {
      // Add a small delay to allow the UI to update
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          index * 70.0, // Approximate height of each message
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        // Visual feedback - highlight the message briefly
        setState(() {
          _highlightedMessageId = messageId;
        });

        // Remove highlight after a delay
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _highlightedMessageId = null;
            });
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
    _scrollController.dispose();
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
        title: Text('DongoChat'),
        actions: const [DebugButton(), LogoutButton()],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                messages.isEmpty
                    ? const Center(child: Text('No hay mensajes aún'))
                    : ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return _bubbleCache.putIfAbsent(
                          msg.id!,
                          () => MessageBubble(
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
                          ),
                        );
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
                child: TextField(
                  focusNode: _textFieldFocus,
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText:
                        reply != null
                            ? 'Responder a mensaje...'
                            : 'Escribe un mensaje…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) => _sendMessage(id),
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
