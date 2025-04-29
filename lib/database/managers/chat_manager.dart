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
  fromMap(Map<String, dynamic> map) => Chat.fromMap(map);

  @override
  Map<String, dynamic> toMap(item) => item.toMap();

  // Mapa para mantener chats cargados en memoria
  final Map<String, Chat> _loadedChats = {};

  // Verifica si un chat está cargado
  bool isChatLoaded(String chatName) => _loadedChats.containsKey(chatName);
  
  // Obtiene un chat cargado
  Chat? getChat(String chatName) => _loadedChats[chatName];

  // Añade mensaje a cualquier chat
  Future<void> addMessageToChat(
      String chatName, String text, ObjectId? sender, MessageData? data) async {
    final chat = _loadedChats[chatName];
    if (chat == null) {
      throw Exception("Chat no inicializado: $chatName");
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
      {'name': chatName},
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
  Future<bool> checkForNewMessages(String chatName) async {
    final chat = _loadedChats[chatName];
    if (chat == null) return false;
    
    try {
      final collection = await getCollectionWithRetry();
      final dbChat = await collection.findOne({'name': chatName});
      if (dbChat == null) return false;

      // Chat.fromMap ya descifra los mensajes internamente
      final newChat = Chat.fromMap(dbChat);

      if (!_areMessagesEqual(chat.messages, newChat.messages)) {
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
  Future<Chat?> initChat(String chatName) async {
    // Si ya está cargado, devolver el chat existente
    if (_loadedChats.containsKey(chatName)) {
      return _loadedChats[chatName];
    }
    
    try {
      final collection = await getCollectionWithRetry();
      final existing = await collection.findOne({'name': chatName});
      
      Chat chat;
      if (existing != null) {
        // Chat.fromMap maneja la desencriptación
        chat = Chat.fromMap(existing);
      } else {
        // Crear nuevo chat
        chat = Chat(name: chatName, messages: []);
        await collection.insert(chat.toMap());
      }
      
      // Almacenar en el mapa de chats cargados
      _loadedChats[chatName] = chat;
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
}
