import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/database/managers/database_manager.dart';
import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/models/user.dart';

class UserManager extends DatabaseManager<User> {
  UserManager(DatabaseService databaseService) : super(databaseService);

  @override
  String get collectionName => 'Users';

  @override
  bool get useCache => true;

  @override
  User fromMap(Map<String, dynamic> map) {
    // id suele ser un ObjectId, lo convertimos a String
    final id = map['_id'];

    // Campos obligatorios
    final displayName = map['displayName'] as String? ?? '';
    final username = map['username'] as String? ?? '';

    // color puede venir como Int64, int, double o String
    final rawColor = map['color'];
    final color = rawColor != null ? int.tryParse(rawColor.toString()) ?? 0 : 0;

    final fcmToken = map['fcmToken'] as String?;

    return User(
      id: id,
      displayName: displayName,
      username: username,
      color: color,
      fcmToken: fcmToken,
    );
  }

  @override
  Map<String, dynamic> toMap(User user) {
    final map = {
      'displayName': user.displayName,
      'username': user.username,
      'color': user.color,
      'password': user.password,
      'fcmToken': user.fcmToken,
    };

    // No incluimos el ID para documentos nuevos
    return map;
  }

  // Métodos específicos para usuarios

  /// Busca un usuario por su nombre de usuario
  Future<User?> findByUsername(String username) async {
    final collection = await getCollectionWithRetry();
    final document = await collection.findOne({'username': username});
    return document != null ? fromMap(document) : null;
  }

  /// Verifica si un nombre de usuario ya existe
  Future<bool> usernameExists(String username) async {
    final user = await findByUsername(username);
    return user != null;
  }

  /// Actualiza el color de un usuario
  Future<bool> updateColor(String userId, int newColor) async {
    final collection = await getCollectionWithRetry();
    final modifier = ModifierBuilder();
    modifier.set('color', newColor);

    final result = await collection.updateOne(
      where.id(ObjectId.parse(userId)),
      modifier,
    );

    return result.isSuccess;
  }

  /// Autentifica un usuario verificando su nombre de usuario y contraseña
  Future<bool> authenticateUser(String username, String password) async {
    final collection = await getCollectionWithRetry();

    // Buscar usuario con el nombre de usuario proporcionado
    final document = await collection.findOne({
      'username': username,
      'password': password,
    });

    // Si encontramos documento, usuario autenticado
    return document != null;
  }
}
