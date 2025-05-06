import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

/// Provider that caches chat data between screen navigations
class ChatCacheProvider extends ChangeNotifier {
  final Map<String, Chat> _chatCache = {};
  
  /// Get a cached chat by ID
  Chat? getCachedChat(ObjectId? chatId) {
    if (chatId == null) return null;
    return _chatCache[chatId.toHexString()];
  }
  
  /// Store or update a chat in the cache
  void cacheChat(Chat chat) {
    if (chat.id == null) return;
    _chatCache[chat.id!.toHexString()] = chat;
    notifyListeners();
  }
  
  /// Update messages in a cached chat
  void updateChatMessages(ObjectId chatId, List<Message> messages) {
    final chatKey = chatId.toHexString();
    if (_chatCache.containsKey(chatKey)) {
      _chatCache[chatKey]!.messages = messages;
      notifyListeners();
    }
  }
}