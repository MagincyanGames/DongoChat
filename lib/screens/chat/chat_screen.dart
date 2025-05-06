import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/screens/chat/widgets/chat_view.dart';
import 'package:dongo_chat/widgets/buttons/appbar/debug_button.dart';
import 'package:dongo_chat/widgets/app_bar.dart';
import 'package:dongo_chat/widgets/buttons/appbar/theme_toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:provider/provider.dart';
import 'package:dongo_chat/providers/chat_cache_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ChatSummary? summary;
  Chat? chat;
  Future<Chat?>? _futureChat; // Variable para almacenar el Future

  @override
  void initState() {
    super.initState();
    // We'll extract the parameters when the widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractChatParameters();
    });
  }

  void _extractChatParameters() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      if (args.containsKey('chat')) {
        final chatSummary = args['chat'] as ChatSummary;
        setState(() {
          summary = chatSummary;
          _futureChat = _fetchChat(); // Inicializar el Future aquí
        });
      }
    } else {
      print('No chat parameters found in navigation');
    }
  }

  Future<Chat?> _fetchChat() async {
    if (summary == null) return null;

    // Check if we have a cached version first
    final chatCache = Provider.of<ChatCacheProvider>(context, listen: false);
    Chat? cachedChat = chatCache.getCachedChat(summary!.id);

    // Always fetch fresh data from server
    var freshChat = await DBManagers.chat.Get(summary!.id);

    if (freshChat != null) {
      var decryptedChat = freshChat.decrypt();

      // If we have a cached version with potentially more messages,
      // merge them with the fresh data
      if (cachedChat != null &&
          cachedChat.messages.length > decryptedChat!.messages.length) {
        // Create a map of fresh messages for easy lookup
        final freshMessagesById = {
          for (var msg in decryptedChat.messages)
            if (msg.id != null) msg.id!.toHexString(): msg,
        };

        // Include any message from cache that isn't in fresh data
        final mergedMessages = [
          ...decryptedChat.messages,
          ...cachedChat.messages.where(
            (msg) =>
                msg.id != null &&
                !freshMessagesById.containsKey(msg.id!.toHexString()),
          ),
        ];

        // Sort by timestamp
        mergedMessages.sort(
          (a, b) => (a.timestamp ?? DateTime.now()).compareTo(
            b.timestamp ?? DateTime.now(),
          ),
        );

        decryptedChat.messages = mergedMessages;
      }

      // Update the cache
      chatCache.cacheChat(decryptedChat!);
      return decryptedChat;
    }

    // Return cached version if no fresh data
    return cachedChat;
  }

  @override
  Widget build(BuildContext context) {
    // Alternative approach: extract parameters in build method
    // final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    // final chatSummary = args?['chat'] as ChatSummary?;
    // final chatId = chatSummary?.id;
    if (summary == null) {
      return const Center(child: Text('No chat ID provided'));
    }

    var currentUser = context.read<UserProvider>().user;

    return FutureBuilder(
      future: _futureChat,
      builder: (BuildContext context, AsyncSnapshot<Chat?> snapshot) {
        chat = snapshot.data;

        Widget body;

        if (snapshot.connectionState == ConnectionState.waiting) {
          body = const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          body = Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData) {
          body = const Center(child: Text('No chat data found'));
        } else {
          body =
              snapshot.data == null
                  ? const Center(child: Text('No chat'))
                  : ChatView(
                    chat: chat!,
                    currentUser: currentUser,
                    onSendMessage: onSendMessage,
                    onRefreshMessages: onRefreshMessages,
                  );
        }

        return Scaffold(
          appBar: CustomAppBar(
            title: summary?.name ?? 'Chat',
            actions: [ThemeToggleButton(), DebugButton()],
            context: context,
          ),

          body: Stack(
            children: [
              Positioned.fill(
                child: SizedBox.expand(
                  child: Image.asset(
                    'assets/ajolote contrast.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    opacity: const AlwaysStoppedAnimation(0.1),
                    colorBlendMode: BlendMode.multiply,
                  ),
                ),
              ),
              body,
            ],
          ),
        );
      },
    );
  }

  Future<void> onSendMessage(
    String text,
    ObjectId sender,
    MessageData? messageData,
  ) async {
    // Update cache
    final chatCache = Provider.of<ChatCacheProvider>(context, listen: false);
    chatCache.cacheChat(chat!);

    // Update database
    final messageId = await DBManagers.chat.addMessageToChat(
      summary!.id,
      text,
      sender,
      messageData,
    );

    final newMessage = Message(
      id: messageId, // Generate a temporary ID
      message: text,
      sender: sender,
      timestamp: DateTime.now(),
      data: messageData,
    );
    setState(() {
      chat!.messages.add(newMessage);
    });
  }

  Future<List<Message>> onRefreshMessages() async {
    print("Refreshing messages...");
    // Get the updated chat data
    var updatedChat = await DBManagers.chat.checkForChatUpdate(summary!);

    if (chat == null) {
      print("Chat is null, cannot check for updates.");
      return [];
    }

    // If no updates or null returned, return empty list
    if (updatedChat == null) {
      print("No chat found or no updates available.");
      return [];
    }
    // Find messages that are new or updated
    List<Message> changedMessages = [];
    // Create a map of existing messages by ID for easy lookup

    final existingMessagesById = {
      for (var msg in chat!.messages)
        if (msg.id != null) msg.id!: msg,
    };

    print("Existing messages: ${existingMessagesById.length}");
    print("Updated messages: ${updatedChat.messages.length}");

    // Check each message in the updated chat
    for (final newMsg in updatedChat.messages) {
      if (newMsg.id == null) {
        // Message without ID should be included (likely new)
        changedMessages.add(newMsg);
        continue;
      }

      final msgId = newMsg.id!;
      final existingMsg = existingMessagesById[msgId];

      if (existingMsg == null) {
        // Message doesn't exist in current chat, it's new
        changedMessages.add(newMsg);
      } else {
        // Check if message was updated by comparing relevant fields
        final hasChanged =
            newMsg.message != existingMsg.message ||
            newMsg.timestamp != existingMsg.timestamp ||
            newMsg.data?.toString() != existingMsg.data?.toString();

        if (hasChanged) {
          changedMessages.add(newMsg);
        }
      }
    }

    print("Found ${changedMessages.length} changed messages");
    return changedMessages;
  }
}
