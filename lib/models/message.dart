import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/models/sizeable.dart';
import 'package:dongo_chat/utils/crypto.dart';

class MessageData implements Sizeable {
  ObjectId? resend;
  String? url;
  String? type;

  MessageData({this.resend, this.url, this.type});

  factory MessageData.fromMap(Map<String, dynamic> map) {
    return MessageData(
      resend: map['resend'] as ObjectId?,
      url: map['url'] as String?,
      type: map['type'] as String?,
    );
  }

  // Convert the MessageData instance to a map
  Map<String, dynamic> toMap() {
    return {'resend': resend, 'url': url, 'type': type};
  }

  @override
  int get size {
    var total = 0;

    // id (ObjectId) si no es null
    if (resend != null) {
      total += 40; // 12 bytes reales + overhead
    }

    return total;
  }
}

class Message implements Sizeable {
  ObjectId? id;
  String message; // Debería contener el texto DESENCRIPTADO
  ObjectId? userId; // Cambiar a non-nullable si es necesario
  ObjectId? sender;
  String iv; // Cambiar a non-nullable (siempre debe tener IV)
  DateTime? timestamp;
  MessageData? data; // Cambiar a non-nullable si es necesario

  Message({
    this.id,
    required this.message,
    this.sender,
    this.timestamp,
    this.userId, // Hacerlo requerido
    required this.iv, // Hacerlo requerido
    this.data,
  });

  // Método fromMap CORREGIDO (con desencriptación)
  factory Message.fromMap(Map<String, dynamic> map) {
    DateTime? timestampDate;
    final rawTimestamp = map['timestamp'];

    if (rawTimestamp != null) {
      try {
        final milliseconds =
            rawTimestamp is int
                ? rawTimestamp
                : int.parse(rawTimestamp.toString());
        timestampDate = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      } catch (e) {
        print("Error al convertir timestamp: $rawTimestamp");
      }
    }

    return Message(
      id: map['_id'] as ObjectId?,
      message: CryptoUtils.decryptString(
        map['message'] as String,
        map['iv'] as String, // Usar el IV almacenado
      ),
      sender: map['sender'] as ObjectId?,
      timestamp: timestampDate,
      iv: map['iv'] as String, // Asegurar que se carga el IV
      data:
          map['data'] != null
              ? MessageData.fromMap(map['data'] as Map<String, dynamic>)
              : null, // Convertir MessageData de mapa a objeto
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'message': message, // Asume que ya viene cifrado
      'sender': sender,
      'timestamp': timestamp?.millisecondsSinceEpoch,
      'iv': iv,
      'data': data?.toMap(), // Convertir MessageData a mapa
    };
  }

  @override
  int get size {
    int total = 0;

    // Overhead base de objeto en Dart
    total += 16;

    // id (ObjectId) si no es null
    if (id != null) {
      total += 40; // 12 bytes reales + overhead
    }

    // message (String)
    total += 8; // puntero
    total += message.length * 2; // 2 bytes por carácter

    // userId (ObjectId) si no es null
    if (userId != null) {
      total += 40; // 12 bytes reales + overhead
    }

    // sender (ObjectId) si no es null
    if (sender != null) {
      total += 40; // 12 bytes reales + overhead
    }

    // iv (String)
    total += 8; // puntero
    total += iv.length * 2; // 2 bytes por carácter

    // timestamp (DateTime) si no es null
    if (timestamp != null) {
      total += 16; // tamaño estimado de DateTime
    }

    return total;
  }
}
