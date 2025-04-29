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

  Chat? _generalChat;
  bool get isGeneralChatReady => _generalChat != null;
  Chat getGeneralChat() => _generalChat!;

  Future<void> addMessageToGeneral(String text, ObjectId? sender) async {
    // 1. Cifrar el contenido
    final encryptedData = CryptoUtils.encryptString(text);

    // 2. Crear el mensaje cifrado
    final message = Message(
      id: ObjectId(),
      message: encryptedData['cipherText']!,
      iv: encryptedData['iv']!,
      sender: sender,
      timestamp: DateTime.now(),
    );

    // 3. Guardar en BD
    final collection = await getCollectionWithRetry();
    await collection.update(
      {'name': 'general'},
      { r'$push': {'messages': message.toMap()} },
    );

    // 4. Añadir al chat local para refresco inmediato
    _generalChat?.messages.add(Message(
      id: message.id,
      message: text, // Añadir el texto desencriptado
      sender: sender,
      timestamp: DateTime.now(),
      iv: message.iv,
    ));
  }

  Future<bool> checkForNewMessages() async {
    if (_generalChat == null) return false;
    try {
      final collection = await getCollectionWithRetry();
      final dbChat = await collection.findOne({'name': 'general'});
      if (dbChat == null) return false;

      // Chat.fromMap ya descifra los mensajes internamente
      final newChat = Chat.fromMap(dbChat);

      if (!_areMessagesEqual(_generalChat!.messages, newChat.messages)) {
        _generalChat!.messages = newChat.messages;
        return true;
      }
      return false;
    } catch (e) {
      print("❌ Error al comprobar mensajes: $e");
      return false;
    }
  }

  Future<bool> initGeneralChat() async {
    if (_generalChat != null) return true;
    try {
      final collection = await getCollectionWithRetry();
      final existing = await collection.findOne({'name': 'general'});
      if (existing != null) {
        // Chat.fromMap maneja la desencriptación
        _generalChat = Chat.fromMap(existing);
      } else {
        _generalChat = Chat(name: 'general', messages: []);
        await collection.insert(_generalChat!.toMap());
      }
      return true;
    } catch (e) {
      print("❌ ERROR en initGeneralChat: $e");
      return false;
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
