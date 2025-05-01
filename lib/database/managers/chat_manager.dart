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

  // Añadir esta propiedad para almacenar el último hash de los summaries
  String _lastSummariesHash = "";

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
      updatedAt: DateTime.now(),
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
      
      final result = await collection.aggregateToStream(pipeline).toList();
      
      if (result.isNotEmpty && result[0].containsKey('latestMessage')) {
        final rawMessage = result[0]['latestMessage'];
        
        // Create and decrypt the message
        final message = Message.fromMap(rawMessage);
        
        // The message will be encrypted, ensure we decrypt it
        if (message.iv != null && message.iv!.isNotEmpty) {
          message.message = CryptoUtils.decryptString(message.message,message.iv!);
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
      
      // Obtener chats con su mensaje más reciente
      final pipeline = _createChatSummaryPipeline();
      final results = await collection.aggregateToStream(pipeline).toList();
      
      return _processChatSummaryResults(results);
    } catch (e) {
      print("❌ ERROR in findAllChatSummaries: $e");
      return [];
    }
  }

  // Añadir este método para verificar si hay cambios en los chats
  Future<bool> checkForNewChats(List<ChatSummary> currentSummaries) async {
    try {
      // Obtener los summaries actuales de la base de datos
      final collection = await getCollectionWithRetry();
      final pipeline = _createChatSummaryPipeline();
      final results = await collection.aggregateToStream(pipeline).toList();
      final dbSummaries = _processChatSummaryResults(results);
      
      // Calcular un hash simple de los chats actuales
      final currentHash = _calculateSummariesHash(dbSummaries);
      
      // Si el hash ha cambiado, actualizar y retornar true
      final hasChanged = currentHash != _lastSummariesHash;
      if (hasChanged) {
        _lastSummariesHash = currentHash;
      }
      
      return hasChanged;
    } catch (e) {
      print("❌ ERROR al verificar nuevos chats: $e");
      return false; // En caso de error, no forzamos actualización
    }
  }

  // Método auxiliar para calcular un "hash" de los summaries
  String _calculateSummariesHash(List<ChatSummary> summaries) {
    // Ordenamos por ID para asegurar consistencia
    summaries.sort((a, b) => a.id.toString().compareTo(b.id.toString()));
    
    // Creamos un string único basado en IDs y timestamps de últimos mensajes
    final buffer = StringBuffer();
    
    for (var chat in summaries) {
      buffer.write(chat.id.toString());
      buffer.write(':');
      
      if (chat.latestMessage != null) {
        buffer.write(chat.latestMessage!.id.toString());
        buffer.write('-');
        buffer.write(chat.latestMessage!.timestamp?.millisecondsSinceEpoch ?? 0);
      } else {
        buffer.write('no-message');
      }
      
      buffer.write('|');
    }
    
    return buffer.toString();
  }

  // Crea el pipeline de agregación para obtener resúmenes de chat
  List<Map<String, Object>> _createChatSummaryPipeline() {
    return [
      {
        '\$project': {
          '_id': 1,
          'name': 1,
          'latestMessage': {
            '\$cond': {
              'if': {'\$gt': [{'\$size': {'\$ifNull': ['\$messages', []]}}, 0]},
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
  }

  // Procesa los resultados de la agregación
  List<ChatSummary> _processChatSummaryResults(List<Map<String, dynamic>> results) {
    return results.map((doc) {
      final ObjectId id = doc['_id'];
      final String name = doc['name'] as String;
      Message? latestMessage;
      
      if (doc.containsKey('latestMessage') && doc['latestMessage'] != null) {
        final rawMessage = doc['latestMessage'];
        latestMessage = Message.fromMap(rawMessage);
        
        // Descifrar el mensaje si está cifrado
        if (latestMessage.iv != null && latestMessage.iv!.isNotEmpty) {
          try {
            latestMessage.message = CryptoUtils.decryptString(
              latestMessage.message,
              latestMessage.iv!
            );
          } catch (e) {
            print("⚠️ Error al descifrar mensaje en chat '$name': $e");
            // Mantener el mensaje cifrado si hay error
          }
        }
      }
      
      return ChatSummary(
        id: id,
        name: name,
        latestMessage: latestMessage,
      );
    }).toList();
  }
}
