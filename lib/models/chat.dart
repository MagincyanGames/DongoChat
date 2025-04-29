import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/sizeable.dart';

class Chat implements Sizeable {
  final ObjectId? id;
  final String? name;
  List<Message> messages;

  Chat({this.id, required this.name, required this.messages});

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'name': name,
      'messages':
          messages
              .map((m) => m.toMap())
              .toList(), // Convertir cada Message a un mapa
    };
  }

  factory Chat.fromMap(Map<String, dynamic> map) {
    print("🔄 Convirtiendo mapa a Chat: ${map.keys}");
    try {
      final messages =
          (map['messages'] as List<dynamic>?)?.map((m) {
            print("   - Procesando mensaje: ${m.runtimeType}");
            return Message.fromMap(m as Map<String, dynamic>);
          }).toList() ??
          [];
      print("   - Total mensajes procesados: ${messages.length}");

      return Chat(
        id: map['_id'] as ObjectId?,
        name: map['name'] as String?,
        messages: messages,
      );
    } catch (e) {
      print("❌ ERROR en Chat.fromMap: $e");
      rethrow; // Relanza el error para que se pueda manejar arriba
    }
  }

  @override
  int get size {
    int total = 0;

    // Overhead base del objeto Chat
    total += 16;

    // id (ObjectId) si no es null
    if (id != null) {
      total += 40; // 12 bytes reales + overhead
    }

    // name (String) si no es null
    if (name != null) {
      total += 8; // puntero
      total += name!.length * 2; // 2 bytes por carácter
    }

    // messages (List<Message>)
    total += 16; // Overhead de la lista
    for (var message in messages) {
      total += message.size; // El tamaño de cada Message
    }

    return total;
  }

  Future<Message?> findMessageById(ObjectId objectId) async {
    try {
      // Search through the messages list for a message with matching ID
      for (var message in messages) {
        if (message.id == objectId) {
          return message;
        }
      }

      // No matching message found
      return null;
    } catch (e) {
      print("❌ ERROR in findMessageById: $e");
      return null;
    }
  }
}
