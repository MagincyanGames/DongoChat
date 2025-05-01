import 'dart:math';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/database/managers/database_manager.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/utils/crypto.dart';

class ChatManager extends DatabaseManager<Chat> {
  ChatManager(super.databaseService);

  @override
  String get collectionName => "Chats";

  
  @override
  bool get useCache => false;

  @override
  fromMap(Map<String, dynamic> map) => Chat.fromMap(map);

  @override
  Map<String, dynamic> toMap(item) => item.toMap();

  // Mapa para mantener chats cargados en memoria
  final Map<ObjectId, Chat> _loadedChats = {};

  // Verifica si un chat está cargado
  bool isChatLoaded(String chatName) => _loadedChats.containsKey(chatName);
  
  // Obtiene un chat cargado
  Chat? getChat(String chatName) => _loadedChats[chatName];

  // Añade mensaje a cualquier chat
  Future<void> addMessageToChat(
      ObjectId chatId, String text, ObjectId? sender, MessageData? data) async {
    final chat = _loadedChats[chatId];
    if (chat == null) {
      throw Exception("Chat no inicializado: $chatId");
    }

    // 1. Cifrar el contenido
    final encryptedData = CryptoUtils.encryptString(text);

    // 2. Crear el mensaje cifrado
    final message = Message(
      id: ObjectId(),
      message: encryptedData['cipherText']!,
      iv: encryptedData['iv']!,
      sender: sender,
      data: data,
      timestamp: DateTime.now(),
    );

    // 3. Guardar en BD
    final collection = await getCollectionWithRetry();
    await collection.update(
      {'_id': chatId},
      {r'$push': {'messages': message.toMap()}},
    );

    // 4. Añadir al chat local para refresco inmediato
    chat.messages.add(Message(
      id: message.id,
      message: text, // Añadir el texto desencriptado
      sender: sender,
      timestamp: DateTime.now(),
      iv: message.iv,
      data: data,
    ));
  }

  // Verifica nuevos mensajes para cualquier chat
  Future<bool> checkForNewMessages(ObjectId chatId) async {
    final chat = _loadedChats[chatId];
    if (chat == null) return false;
    
    try {
      final collection = await getCollectionWithRetry();
      
      // Use aggregation to get only the latest message
      final pipeline = [
        {
          '\$match': {'_id': chatId}
        },
        {
          '\$project': {
            'latestMessage': {
              '\$arrayElemAt': [
                {'\$sortArray': {
                  'input': '\$messages',
                  'sortBy': {'timestamp': -1}
                }},
                0
              ]
            }
          }
        }
      ];
      
      final result = await collection.aggregateToStream(pipeline).toList();
      
      // If no results or no latest message, nothing to update
      if (result.isEmpty || !result[0].containsKey('latestMessage')) {
        return false;
      }
      
      final latestMessageMap = result[0]['latestMessage'];
      final latestMessageId = latestMessageMap['_id'] as ObjectId;
      
      // Check if this message is already in our loaded chat
      bool messageExists = false;
      for (var message in chat.messages) {
        if (message.id == latestMessageId) {
          messageExists = true;
          break;
        }
      }
      
      // If message doesn't exist, reload the entire chat
      if (!messageExists) {
        final dbChat = await collection.findOne({'_id': chatId});
        if (dbChat == null) return false;
        
        // Update the chat with new messages
        final newChat = Chat.fromMap(dbChat);
        chat.messages = newChat.messages;
        return true;
      }
      
      return false;
    } catch (e) {
      print("❌ Error al comprobar mensajes: $e");
      return false;
    }
  }

  // Inicializa cualquier chat
  Future<Chat?> initChat(ObjectId chatId) async {
    print("🔄 Inicializando chat: $chatId");
    // Si ya está cargado, devolver el chat existente
    if (_loadedChats.containsKey(chatId)) {
      return _loadedChats[chatId];
    }
    
    try {
      final collection = await getCollectionWithRetry();
      final existing = await collection.findOne({'_id': chatId});

      Chat chat = Chat.fromMap(existing!);
      
      // Almacenar en el mapa de chats cargados
      _loadedChats[chatId] = chat;
      return chat;
    } catch (e) {
      print("❌ ERROR en initChat: $e");
      return null;
    }
  }

  bool _areMessagesEqual(List<Message> a, List<Message> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  // Get the latest message for a specific chat
  Future<Message?> getLatestMessage(String chatName) async {
    try {
      final collection = await getCollectionWithRetry();
      
      // Use aggregation pipeline to get the chat with only the latest message
      final pipeline = [
        {
          '\$match': {'name': chatName}
        },
        {
          '\$project': {
            '_id': 1,
            'name': 1,
            'latestMessage': {
              '\$arrayElemAt': [
                {'\$sortArray': {
                  'input': '\$messages',
                  'sortBy': {'timestamp': -1}
                }},
                0
              ]
            }
          }
        }
      ];
      
      final result = await collection.aggregateToStream(pipeline).toList();
      
      if (result.isNotEmpty && result[0].containsKey('latestMessage')) {
        final rawMessage = result[0]['latestMessage'];
        
        // Create and decrypt the message
        final message = Message.fromMap(rawMessage);
        
        // The message will be encrypted, ensure we decrypt it
        if (message.iv != null && message.iv!.isNotEmpty) {
          message.message = CryptoUtils.decryptString(message.message,message.iv);
        }
        
        return message;
      }
      
      return null;
    } catch (e) {
      print("❌ ERROR in getLatestMessage: $e");
      return null;
    }
  }

  // Get all chat summaries with their latest messages
  Future<List<ChatSummary>> findAllChatSummaries() async {
    try {
      final collection = await getCollectionWithRetry();
      
      // Project each chat with just its name and latest message
      final pipeline = [
        {
          '\$project': {
            '_id': 1,
            'name': 1,
            'latestMessage': {
              '\$cond': {
                'if': {'\$gt': [{'\$size': '\$messages'}, 0]},
                'then': {
                  '\$arrayElemAt': [
                    {'\$sortArray': {
                      'input': '\$messages',
                      'sortBy': {'timestamp': -1}
                    }},
                    0
                  ]
                },
                'else': null
              }
            }
          }
        }
      ];
      
      final results = await collection.aggregateToStream(pipeline).toList();
      
      return results.map((doc) {
        final name = doc['name'] as String;
        Message? latestMessage;
        
        if (doc.containsKey('latestMessage') && doc['latestMessage'] != null) {
          latestMessage = Message.fromMap(doc['latestMessage']);
        }
        
        return ChatSummary(
          id: doc['_id'] as ObjectId,
          name: name,
          latestMessage: latestMessage,
        );
      }).toList();
    } catch (e) {
      print("❌ ERROR in getAllChatSummaries: $e");
      return [];
    }
  }
}
