import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/database/managers/chat_manager.dart';
import 'package:dongo_chat/main.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/screens/chat/widgets/chat_view.dart';
import 'package:dongo_chat/screens/chat/widgets/loadding_screen.dart';
import 'package:dongo_chat/screens/chat/widgets/logout_button.dart';
import 'package:dongo_chat/screens/debug/debug_button.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:dongo_chat/widgets/theme_toggle_button.dart';
import 'package:dongo_chat/screens/chat/chat_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  late final ChatManager _chatManager;
  late final DatabaseService _dbService;
  String? _debugError;
  bool _isLoading = false;
  final GlobalKey<ChatViewState> _chatViewKey = GlobalKey<ChatViewState>();

  // El chat actual
  Chat? _currentChat;

  // Nombre predeterminado del chat
  var _chatName = 'general';
  // Cambiamos el valor inicial para que abra primero el selector
  bool _showSelector = true;

  @override
  void initState() {
    super.initState();
    _dbService = Provider.of<DatabaseService>(context, listen: false);
    _chatManager = DBManagers.chat;
    // ----------> Añadido: precalentar la conexión/inicialización del chat por defecto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
    try {
      // Inicializar el chat
      final chat = await _chatManager.initChat(_chatName);

      if (mounted) {
        setState(() {
          if (chat != null) {
            _currentChat = chat;
            _debugError = null;
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

  Future<void> _handleSendMessage(
    String text,
    ObjectId userId,
    MessageData? messageData,
  ) async {
    setState(() => _isLoading = true);

    try {
      // Enviar mensaje al chat actual
      await _chatManager.addMessageToChat(_chatName, text, userId, messageData);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _handleRefreshMessages() async {
    if (_currentChat == null) return false;
    return await _chatManager.checkForNewMessages(_chatName);
  }

  // Métodos expuestos para compatibilidad con código existente
  void setReplyMessage(ObjectId messageId) {
    _chatViewKey.currentState?.setReplyMessage(messageId);
  }

  void scrollToMessage(ObjectId messageId) {
    _chatViewKey.currentState?.scrollToMessage(messageId);
  }

  /// Convierte "general" → "General",
  ///         "this-is-a-test" → "This is a test"
  String prettify(String input) {
    // 1. Reemplaza guiones por espacios
    final withSpaces = input.replaceAll('-', ' ');
    if (withSpaces.isEmpty) return withSpaces;
    // 2. Capitaliza la primera letra
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }

  Widget _chatSelectorScreen() {
    return ChatSelectionScreen(
      onChatSelected: (name) {
        setState(() {
          _chatName = name;
          _showSelector = false;
        });
        // Tras seleccionar, inicializamos el chat
        _initializeChat();
      },
    );
  }

  Widget _loadding() {
    return LoadingChatScreen(error: _debugError, onRetry: _initializeChat);
  }

  Widget _chatScreen(User user) {
    return ChatView(
      key: ValueKey(_chatName), // forzar rebuild al cambiar chat
      chat: _currentChat!,
      currentUser: user,
      onSendMessage: _handleSendMessage,
      onRefreshMessages: _handleRefreshMessages,
      isLoading: _isLoading,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget? body;
    List<Widget> actions = [];
    // Si estamos en selector (por defecto true), mostramos la lista
    if (_showSelector) {
      body = _chatSelectorScreen();
      actions = [
        const ThemeToggleButton(),
        const DebugButton(),
        const LogoutButton(),
      ];
    }

    // pantalla de chat normal
    final user = context.watch<UserProvider>().user;
    if (_currentChat == null) {
      body = _loadding();
    }

    if (!_showSelector && _currentChat != null && user != null) {
      body = _chatScreen(user);
       actions=[         Material(
            color: Colors.transparent,
            child: IconButton(
              icon: const Icon(Icons.list),
              onPressed: () => setState(() => _showSelector = true),
            ),
          ),
          const ThemeToggleButton(),
          const DebugButton(),
          const LogoutButton(),
       ];
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(prettify(_chatName)),
        actions: actions,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Theme.of(
                      context,
                    ).extension<ChatTheme>()?.otherMessageGradient.last ??
                    Colors.blue.shade900,
                Theme.of(
                      context,
                    ).extension<ChatTheme>()?.myMessageGradient.first ??
                    Colors.deepPurple.shade900,
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }
}
