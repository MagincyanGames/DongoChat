import 'dart:convert';
import 'package:basic_utils/basic_utils.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/utils/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/database/managers/api_manager.dart';
import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/models/user.dart';

class UserManager extends ApiManager<User> {
  UserManager(DatabaseService databaseService) : super(databaseService);

  @override
  bool get needAuth => true;

  @override
  String get endpoint => 'users';

  @override
  bool get useCache => true;

  @override
  User fromMap(Map<String, dynamic> map) {
    // id suele ser un ObjectId, lo convertimos a String
    final id = ObjectId.parse(map['_id']);

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

  /// Login with username and password
  ///
  /// Returns a map containing the user object and authentication token
  /// Throws an exception if login fails
  Future<Map<String, dynamic>> login(String username, String password) async {
    final loginUrl = '$url/login';
    print('Login URL: $loginUrl');
    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'clientPublicKey': CryptoUtils.encodeRSAPublicKeyToPem(
            CryptoUtilities.keyPair!.publicKey,
          ),
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final token = responseData['token'];
        final userData = responseData['user'];
        final user = fromMap(userData);

        // Store token in database service
        databaseService.auth = token;

        return {
          'user': user,
          'token': token,
          'serverPublicKey': responseData['serverPublicKey'],
        };
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  /// Register a new user
  ///
  /// Returns a map containing the created user object and authentication token
  /// Throws an exception if registration fails
  Future<Map<String, dynamic>> signup({
    required String displayName,
    required String username,
    required String password,
    int? color,
    String? fcmToken,
  }) async {
    final signupUrl = '$url/signup';
    try {
      final response = await http.post(
        Uri.parse(signupUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'displayName': displayName,
          'username': username,
          'password': password,
          'color': color ?? 4280391411, // Default color if not provided
          'fcmToken': fcmToken,
          'clientPublicKey': CryptoUtils.encodeRSAPublicKeyToPem(
            CryptoUtilities.keyPair!.publicKey,
          ),
        }),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final token = responseData['token'];
        final userData = responseData['user'];
        final user = fromMap(userData);
        // Store token in database service
        databaseService.auth = token;

        return {
          'user': user,
          'token': token,
          'serverPublicKey': responseData['serverPublicKey'],
        };
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  /// Get user information by ID
  ///
  /// This method extends the standard Get method with authentication
  @override
  Future<User?> Get(ObjectId id) async {
    if (databaseService.auth == null || databaseService.auth!.isEmpty) {
      throw Exception('Authentication required');
    }

    return super.Get(id);
  }
}
