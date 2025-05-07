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
import 'package:dongo_chat/main.dart' show routeObserver;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with RouteAware {
  ChatSummary? summary;
  Chat? chat;
  Future<Chat?>? _futureChat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractChatParameters();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    print('Volviendo a ChatScreen - refrescando mensajes');
    if (chat != null && summary != null) {
      onRefreshMessages().then((messages) {
        if (messages.isNotEmpty) {
          print(
            'Se actualizaron ${messages.length} mensajes al volver a la pantalla',
          );
          setState(() {
            chat = Provider.of<ChatCacheProvider>(
              context,
              listen: false,
            ).getCachedChat(summary!.id);
          });
        }
      });
    }
    super.didPopNext();
  }

  void _extractChatParameters() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      if (args.containsKey('chat')) {
        final chatSummary = args['chat'] as ChatSummary;
        setState(() {
          summary = chatSummary;
          _futureChat = _fetchChat();
        });
      }
    } else {
      print('No chat parameters found in navigation');
    }
  }

  Future<Chat?> _fetchChat() async {
    if (summary == null) return null;

    final chatCache = Provider.of<ChatCacheProvider>(context, listen: false);
    Chat? cachedChat = chatCache.getCachedChat(summary!.id);

    var freshChat = await DBManagers.chat.Get(summary!.id);

    if (freshChat != null) {
      var decryptedChat = freshChat.decrypt();

      if (cachedChat != null &&
          cachedChat.messages.length > decryptedChat!.messages.length) {
        final freshMessagesById = {
          for (var msg in decryptedChat.messages)
            if (msg.id != null) msg.id!.toHexString(): msg,
        };

        final mergedMessages = [
          ...decryptedChat.messages,
          ...cachedChat.messages.where(
            (msg) =>
                msg.id != null &&
                !freshMessagesById.containsKey(msg.id!.toHexString()),
          ),
        ];

        mergedMessages.sort(
          (a, b) => (a.timestamp ?? DateTime.now()).compareTo(
            b.timestamp ?? DateTime.now(),
          ),
        );

        decryptedChat.messages = mergedMessages;
      }

      chatCache.cacheChat(decryptedChat!);
      return decryptedChat;
    }

    return cachedChat;
  }

  @override
  Widget build(BuildContext context) {
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
    final chatCache = Provider.of<ChatCacheProvider>(context, listen: false);
    chatCache.cacheChat(chat!);

    try {
      final messageId = await DBManagers.chat.addMessageToChat(
        summary!.id,
        text,
        sender,
        messageData,
      );
      final tempMessage = Message(
        id: messageId,
        message: text,
        sender: sender,
        timestamp: DateTime.now(),
        data: messageData,
      );

      setState(() {
        chat!.messages.add(tempMessage);
      });

      chatCache.cacheChat(chat!);

      if (summary != null) {
        summary!.latestMessage = tempMessage;
        chatCache.updateChatSummary(summary!);
      }
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<List<Message>> onRefreshMessages() async {
    try {
      print("Refreshing messages...");

      if (!mounted) {
        print("Widget no longer mounted, skipping refresh");
        return [];
      }

      if (chat == null || summary == null) {
        print("Chat is null, cannot check for updates.");
        return [];
      }

      var updatedChat = await DBManagers.chat.checkForChatUpdate(summary!);

      if (updatedChat == null) {
        print("No chat found or no updates available.");
        return [];
      }

      final chatCache = Provider.of<ChatCacheProvider>(context, listen: false);
      chatCache.cacheChat(updatedChat);

      return updatedChat.messages;
    } catch (e) {
      print('Error in onRefreshMessages: $e');
      return [];
    }
  }
}
