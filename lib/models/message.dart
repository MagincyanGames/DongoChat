import 'dart:convert';

import 'package:dongo_chat/models/chat.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/models/sizeable.dart';
import 'package:dongo_chat/utils/crypto.dart';
import 'package:pointycastle/asymmetric/api.dart';

class MessageData implements Sizeable {
  ObjectId? resend;
  String? url;
  String? type;

  MessageData({this.resend, this.url, this.type});

  factory MessageData.fromMap(Map<String, dynamic> map) {
    return MessageData(
      resend: map['resend'] != null
          ? ObjectId.parse(map['resend'])
          : null, // Convertir a ObjectId si no es null
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
    int total = 0;

    // Base object overhead
    total += 16;

    // resend (ObjectId) if not null
    if (resend != null) {
      total += 40; // 12 bytes real + overhead
    }

    // url (String) if not null
    if (url != null) {
      total += 8; // pointer
      total += url!.length * 2; // UTF-16 encoding
    }

    // type (String) if not null
    if (type != null) {
      total += 8; // pointer
      total += type!.length * 2; // UTF-16 encoding
    }

    return total;
  }

  MessageData encrypt(RSAPublicKey key) {
    return MessageData(
      resend: resend,
      url: url != null ? CryptoUtilities.encryptString(url!) : null,
      type: type,
    );
  }

  MessageData decrypt() {
    return MessageData(
      resend: resend,
      url: url != null ? CryptoUtilities.decryptString(url!) : null,
      type: type,
    );
  }
}

class Message implements Sizeable {
  ObjectId? id;
  String message; // Debería contener el texto DESENCRIPTADO
  ObjectId? userId; // Cambiar a non-nullable si es necesario
  ObjectId? sender;
  DateTime? timestamp;
  DateTime? updatedAt; // Cambiar a non-nullable si es necesario
  MessageData? data; // Cambiar a non-nullable si es necesario

  Message({
    this.id,
    required this.message,
    this.sender,
    this.timestamp,
    this.userId, // Hacerlo requerido
    this.data,
    this.updatedAt,
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

    final rawUpdatedAt = map['updatedAt'];
    DateTime? updatedAtDate;
    if (rawUpdatedAt != null) {
      try {
        final milliseconds =
            rawUpdatedAt is int
                ? rawUpdatedAt
                : int.parse(rawUpdatedAt.toString());
        updatedAtDate = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      } catch (e) {
        print("Error al convertir updatedAt: $rawUpdatedAt");
      }
    }

    return Message(
      id: ObjectId.parse(map['_id']),
      message: map['message'] as String,
      sender: ObjectId.parse(map['sender']),
      timestamp: timestampDate,
      updatedAt: updatedAtDate,
      data:
          map['data'] != null
              ? map['data'] is String
                  ? MessageData.fromMap(jsonDecode(map['data']))
                  : MessageData.fromMap(map['data'])
              : null, // Convertir MessageData de mapa a objeto
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'message': message, // Asume que ya viene cifrado
      'sender': sender,
      'timestamp': timestamp?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
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

    // timestamp (DateTime) si no es null
    if (timestamp != null) {
      total += 16; // tamaño estimado de DateTime
    }

    // updatedAt (DateTime) si no es null
    if (updatedAt != null) {
      total += 16; // tamaño estimado de DateTime
    }

    return total;
  }

  Message encrypt(RSAPublicKey key) {
    var encrypter = CryptoUtilities.getEncrypter(publicKey: key);

    return Message(
      id: id,
      message: encrypter.encrypt(message).base64,
      sender: sender,
      timestamp: timestamp,
      userId: userId,
      data: data?.encrypt(key), // Asegúrate de que los datos estén presentes
    );
  }

  Message? decrypt() {
    return Message(
      id: id,
      message: CryptoUtilities.decryptString(message),
      sender: sender,
      timestamp: timestamp,
      userId: userId,
      data: data?.decrypt(), // Asegúrate de que los datos estén presentes
    );
  }
}
