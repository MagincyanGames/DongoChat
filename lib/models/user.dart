import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/models/sizeable.dart';

class User implements Sizeable {
  ObjectId? id; // ID en MongoDB (puede ser null para nuevos usuarios)
  String displayName;
  String username;
  int color; // Color representado como entero
  String? password; // Contraseña (opcional, no se almacena en la base de datos)
  User({
    this.id,
    required this.displayName,
    required this.username,
    required this.color,
    this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'username': username,
      'color': color,
      'password': password,
    };
  }

  @override
  int get size {
    int total = 0;

    // Estimación del overhead base de objeto en Dart
    total += 16;

    // ObjectId (si no es null)
    if (id != null) {
      total += 40; // 12 bytes reales + 28 bytes aproximados de overhead
    }

    // color (int)
    total += 8;

    // displayName
    total += 8; // puntero
    total += displayName.length * 2;

    // username
    total += 8; // puntero
    total += username.length * 2;

    // password (si no es null)
    if (password != null) {
      total += 8; // puntero
      total += password!.length * 2;
    }

    return total;
  }
}
