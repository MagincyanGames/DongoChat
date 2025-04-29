import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/database/managers/chat_manager.dart';
import 'package:dongo_chat/main.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/screens/chat/widgets/chat_view.dart';
import 'package:dongo_chat/screens/chat/widgets/loadding_screen.dart';
import 'package:dongo_chat/screens/chat/widgets/logout_button.dart';
import 'package:dongo_chat/screens/debug/debug_button.dart';
import 'package:dongo_chat/widgets/theme_toggle_button.dart';
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
  final String _chatName = 'general';

  @override
  void initState() {
    super.initState();
    _dbService = Provider.of<DatabaseService>(context, listen: false);
    _chatManager = DBManagers.chat;

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

  Future<void> _handleSendMessage(String text, ObjectId userId, MessageData? messageData) async {
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    if (_currentChat == null) {
      return LoadingChatScreen(error: _debugError, onRetry: _initializeChat);
    }

    // Quitar el ScaffoldMessenger anidado
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('DongoChat v${appVersion}'),
        actions: const [ThemeToggleButton(), DebugButton(), LogoutButton()],
      ),
      body: ChatView(
        key: _chatViewKey,
        chat: _currentChat!,
        currentUser: user,
        onSendMessage: _handleSendMessage,
        onRefreshMessages: _handleRefreshMessages,
        isLoading: _isLoading,
      ),
    );
  }
}
