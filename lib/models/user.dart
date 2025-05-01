import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/models/sizeable.dart';

class User implements Sizeable {
  ObjectId? id; // ID en MongoDB (puede ser null para nuevos usuarios)
  String displayName;
  String username;
  int color; // Color representado como entero
  String? password; // Contraseña (opcional, no se almacena en la base de datos)
  String? fcmToken; // Token de Firebase Cloud Messaging (opcional)

  User({
    this.id,
    required this.displayName,
    required this.username,
    required this.color,
    this.password,
    this.fcmToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'username': username,
      'color': color,
      'password': password,
      'fcmToken': fcmToken,
    };
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

    // color (int)
    total += 8;

    // displayName (String)
    total += 8; // pointer
    total += displayName.length * 2; // UTF-16 encoding

    // username (String)
    total += 8; // pointer
    total += username.length * 2; // UTF-16 encoding

    // password (String) if not null
    if (password != null) {
      total += 8; // pointer
      total += password!.length * 2; // UTF-16 encoding
    }

    return total;
  }
}
