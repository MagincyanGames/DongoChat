import 'package:dongo_chat/models/user.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/sizeable.dart';

// Simple class to hold chat summary information
class ChatSummary {
  final ObjectId id;
  final String name;
  final Message? latestMessage;
  final Message? latestUpdated;
  List<ObjectId> readOnlyUsers;
  List<ObjectId> readWriteUsers;
  List<ObjectId> adminUsers;
  String privacity = 'private';
  ChatSummary({
    required this.id,
    required this.name,
    this.latestMessage,
    this.latestUpdated,
    List<ObjectId>? readOnlyUsers,
    List<ObjectId>? readWriteUsers,
    List<ObjectId>? adminUsers,
    String? privacity,
  }) : this.readOnlyUsers = readOnlyUsers ?? [],
       this.readWriteUsers = readWriteUsers ?? [],
       this.adminUsers = adminUsers ?? [],
       this.privacity = privacity ?? 'private';

  bool isAdmin(User user) {
    return user.id != null && adminUsers.contains(user.id);
  }

  // Add this new method to check write permissions
  bool canWrite(User? user) {
    if (user == null || user.id == null) return false;
    return adminUsers.contains(user.id) ||
        readWriteUsers.contains(user.id) ||
        privacity == 'public';
  }

  bool canRead(User? user) {
    if (user == null || user.id == null) return false;
    return adminUsers.contains(user.id) ||
        readWriteUsers.contains(user.id) ||
        readOnlyUsers.contains(user.id) ||
        privacity == 'public' ||
        privacity == 'publicReadOnly';
  }
}

class Chat implements Sizeable {
  final ObjectId? id;
  final String? name;
  List<Message> messages;
  List<ObjectId> readOnlyUsers;
  List<ObjectId> readWriteUsers;
  List<ObjectId> adminUsers;
  String? privacity;

  bool isAdmin(User user) {
    return user.id != null && adminUsers.contains(user.id);
  }

  bool canWrite(User? user) {
    print("privacity: $privacity");
    print("user: ${user != null}");
    if (user == null || user.id == null) return false;
    print("privacity: $privacity");
    return adminUsers.contains(user.id) ||
        readWriteUsers.contains(user.id) ||
        privacity == 'public';
  }

  bool canRead(User? user) {
    if (user == null || user.id == null) return false;
    return adminUsers.contains(user.id) ||
        readWriteUsers.contains(user.id) ||
        readOnlyUsers.contains(user.id) ||
        privacity == 'public' ||
        privacity == 'publicReadOnly';
  }

  Chat({
    this.id,
    required this.name,
    List<Message>? messages,
    List<ObjectId>? readOnlyUsers,
    List<ObjectId>? readWriteUsers,
    List<ObjectId>? adminUsers,
    String? privacity,
  }) : this.messages = messages ?? [],
       this.readOnlyUsers = readOnlyUsers ?? [],
       this.readWriteUsers = readWriteUsers ?? [],
       this.adminUsers = adminUsers ?? [],
       this.privacity = privacity ?? 'private';

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'name': name,
      'messages':
          messages
              .map((m) => m.toMap())
              .toList(), // Convertir cada Message a un mapa
      'readOnlyUsers': readOnlyUsers,
      'readWriteUsers': readWriteUsers,
      'adminUsers': adminUsers,
      'privacity': privacity,
    };
  }

  factory Chat.fromMap(Map<String, dynamic> map) {
    try {
      final messages =
          (map['messages'] as List<dynamic>?)?.map((m) {
            return Message.fromMap(m as Map<String, dynamic>);
          }).toList() ??
          [];

      return Chat(
        id: map['_id'] as ObjectId?,
        name: map['name'] as String?,
        messages: messages,
        readOnlyUsers: List<ObjectId>.from(map['readOnlyUsers'] ?? []),
        readWriteUsers: List<ObjectId>.from(map['readWriteUsers'] ?? []),
        adminUsers: List<ObjectId>.from(map['adminUsers'] ?? []),
        privacity: map['privacity'],
      );
    } catch (e) {
      rethrow; // Relanza el error para que se pueda manejar arriba
    }
  }

  @override
  int get size {
    int total = 0;

    // Base object overhead
    total += 16;

    // id (ObjectId) if not null
    if (id != null) {
      total += 40; // 12 bytes real + overhead
    }

    // name (String) if not null
    if (name != null) {
      total += 8; // pointer
      total += name!.length * 2; // UTF-16 encoding
    }

    // messages (List<Message>)
    total += 16; // List overhead
    // Add overhead for each list slot (not just filled ones)
    total += 8 * messages.length; // 8 bytes per list element pointer

    // Add size of each message
    for (var message in messages) {
      total += message.size;
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
