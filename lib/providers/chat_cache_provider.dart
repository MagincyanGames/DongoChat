import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

/// Provider that caches chat data between screen navigations
class ChatCacheProvider extends ChangeNotifier {
  final Map<String, Chat> _chatCache = {};
  final Map<String, ChatSummary> _summaryCache = {};
  
  /// Get a cached chat by ID
  Chat? getCachedChat(ObjectId? chatId) {
    if (chatId == null) return null;
    return _chatCache[chatId.toHexString()];
  }
  
  /// Merge messages from two sources, prioritizing the newer ones
  List<Message> mergeMessages(List<Message> existingMessages, List<Message> newMessages) {
    // Create a map of existing messages by ID for quick lookup
    final messagesById = <String, Message>{};
    
    // Add all existing messages to the map
    for (var msg in existingMessages) {
      if (msg.id != null) {
        messagesById[msg.id!.toHexString()] = msg;
      }
    }
    
    // Add or update with new messages
    for (var msg in newMessages) {
      if (msg.id != null) {
        messagesById[msg.id!.toHexString()] = msg;
      }
    }
    
    // Keep messages without IDs (likely pending messages)
    final pendingMessages = [
      ...existingMessages.where((msg) => msg.id == null),
      ...newMessages.where((msg) => msg.id == null)
    ];
    
    // Combine and sort all messages
    final result = [...messagesById.values, ...pendingMessages];
    result.sort((a, b) => 
      (a.timestamp ?? DateTime.now()).compareTo(b.timestamp ?? DateTime.now()));
    
    return result;
  }

  /// Store or update a chat in the cache with proper message merging
  void cacheChat(Chat chat) {
    if (chat.id == null) return;
    
    final chatId = chat.id!.toHexString();
    if (_chatCache.containsKey(chatId)) {
      // Merge messages if this chat already exists in cache
      final existingChat = _chatCache[chatId]!;
      chat.messages = mergeMessages(existingChat.messages, chat.messages);
    }
    
    _chatCache[chatId] = chat;
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

  /// Update chat summary in the cache
  void updateChatSummary(ChatSummary summary) {
    if (summary.id != null) {
      // Actualiza el resumen en la caché
      _summaryCache[summary.id!.toHexString()] = summary;
      notifyListeners();
    }
  }
}