import 'package:dongo_chat/models/user.dart';
import 'package:http/retry.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/sizeable.dart';
import 'package:pointycastle/asymmetric/api.dart';

// Simple class to hold chat summary information
class ChatSummary implements Sizeable {
  final ObjectId id;
  final String name;
  Message? latestMessage;
  Message? latestUpdated;
  List<ObjectId> readOnlyUsers;
  List<ObjectId> readWriteUsers;
  List<ObjectId> adminUsers;
  String privacity = 'private';
  int messageCount; // New property for tracking message count

  ChatSummary({
    required this.id,
    required this.name,
    this.latestMessage,
    this.latestUpdated,
    List<ObjectId>? readOnlyUsers,
    List<ObjectId>? readWriteUsers,
    List<ObjectId>? adminUsers,
    String? privacity,
    this.messageCount = 0, // Default to 0 if not provided
  }) : this.readOnlyUsers = readOnlyUsers ?? [],
       this.readWriteUsers = readWriteUsers ?? [],
       this.adminUsers = adminUsers ?? [],
       this.privacity = privacity ?? 'private';

  // Convert ChatSummary object to a Map
  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'name': name,
      'latestMessage': latestMessage?.toMap(),
      'latestUpdated': latestUpdated?.toMap(),
      'readOnlyUsers': readOnlyUsers,
      'readWriteUsers': readWriteUsers,
      'adminUsers': adminUsers,
      'privacity': privacity,
      'messageCount': messageCount, // Include message count in the map
    };
  }

  // Create a ChatSummary from a Map
  factory ChatSummary.fromMap(Map<String, dynamic> map) {
    try {
      return ChatSummary(
        id: ObjectId.parse(map['_id']),
        name: map['name'] as String,
        latestMessage:
            map['latestMessage'] != null
                ? Message.fromMap(map['latestMessage'])
                : null,
        latestUpdated:
            map['latestUpdated'] != null
                ? Message.fromMap(map['latestUpdated'])
                : null,
        readOnlyUsers:
            map['readOnlyUsers']
                .map<ObjectId>((e) => ObjectId.parse(e))
                .toList(),
        readWriteUsers:
            map['readWriteUsers']
                .map<ObjectId>((e) => ObjectId.parse(e))
                .toList(),
        adminUsers:
            map['adminUsers'].map<ObjectId>((e) => ObjectId.parse(e)).toList(),
        privacity: map['privacity'] as String?,
        messageCount:
            map['messageCount'] as int? ??
            0, // Extract message count with default
      );
    } catch (e) {
      print("❌ Error creating ChatSummary from map: $e");
      rethrow;
    }
  }

  // Implement the size property for Sizeable interface
  @override
  int get size {
    int total = 0;

    // Base object overhead
    total += 16;

    // id (ObjectId)
    total += 40; // 12 bytes real + overhead

    // name (String)
    total += 8; // pointer
    total += name.length * 2; // UTF-16 encoding

    // latestMessage and latestUpdated if not null
    if (latestMessage != null) {
      total += latestMessage!.size;
    }

    if (latestUpdated != null) {
      total += latestUpdated!.size;
    }

    // User lists (each ObjectId is about 40 bytes including overhead)
    total += 16 + (readOnlyUsers.length * 40); // List overhead + elements
    total += 16 + (readWriteUsers.length * 40); // List overhead + elements
    total += 16 + (adminUsers.length * 40); // List overhead + elements

    // privacity string
    total += 8; // pointer
    total += privacity.length * 2; // UTF-16 encoding

    // messageCount (int)
    total += 4; // 4 bytes for int

    return total;
  }

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
    print("Checking read permissions for user: ${user?.id}");
    print("Admin users: $adminUsers");
    print("Read-write users: $readWriteUsers");
    print('privacity: $privacity');
    print("Read-only users: $readOnlyUsers");
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
    if (user == null || user.id == null) return false;
    return adminUsers.contains(user.id) ||
        readWriteUsers.contains(user.id) ||
        privacity == 'public';
  }

  ChatSummary get summary {
    return ChatSummary(
      id: id!,
      name: name!,
      latestMessage: messages.isNotEmpty ? messages.last : null,
      latestUpdated: messages.isNotEmpty ? messages.last : null,
      readOnlyUsers: readOnlyUsers,
      readWriteUsers: readWriteUsers,
      adminUsers: adminUsers,
      privacity: privacity!,
      messageCount: messages.length, // Add the message count
    );
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
        id: ObjectId.parse(map['_id']),
        name: map['name'] as String?,
        messages: messages,
        readOnlyUsers:
            map['readOnlyUsers']
                .map<ObjectId>((e) => ObjectId.parse(e))
                .toList(),
        readWriteUsers:
            map['readWriteUsers']
                .map<ObjectId>((e) => ObjectId.parse(e))
                .toList(),
        adminUsers:
            map['adminUsers'].map<ObjectId>((e) => ObjectId.parse(e)).toList(),
        privacity: map['privacity'],
      );
    } catch (e) {
      print("❌ Error creating Chat from map: $e");
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

  Chat encrypt(RSAPublicKey key) {
    return Chat(
      id: id,
      name: name,
      messages: messages.map((m) => m.encrypt(key)).toList(),
      readOnlyUsers: readOnlyUsers,
      readWriteUsers: readWriteUsers,
      adminUsers: adminUsers,
      privacity: privacity,
    );
  }

  Chat? decrypt() {
    return Chat(
      id: id,
      name: name,
      messages:
          messages.map((m) {
            return m.decrypt()!;
          }).toList(),
      readOnlyUsers: readOnlyUsers,
      readWriteUsers: readWriteUsers,
      adminUsers: adminUsers,
      privacity: privacity,
    );
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

  Chat copyWith({
    ObjectId? id,
    String? name,
    List<Message>? messages,
    List<ObjectId>? readOnlyUsers,
    List<ObjectId>? readWriteUsers,
    List<ObjectId>? adminUsers,
    String? privacity,
  }) {
    return Chat(
      id: id ?? this.id,
      name: name ?? this.name,
      messages: messages ?? List<Message>.from(this.messages),
      readOnlyUsers: readOnlyUsers ?? List<ObjectId>.from(this.readOnlyUsers),
      readWriteUsers: readWriteUsers ?? List<ObjectId>.from(this.readWriteUsers),
      adminUsers: adminUsers ?? List<ObjectId>.from(this.adminUsers),
      privacity: privacity ?? this.privacity,
    );
  }
}
