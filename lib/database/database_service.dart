import 'dart:async';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/database/managers/chat_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  late Db db;
  bool isConnected = false;
  String _connectionString = 'mongodb+srv://onara:AduLHQ6icblTnfCV@onaradb.5vdzp.mongodb.net/?retryWrites=true&w=majority&appName=onaradb/DongoChat';
  // String _connectionString = 'mongodb://play.onara.top:27017/WeLearning';
  Timer? _keepAliveTimer;

  static const String _serverKey = 'selected_server'; // Key for SharedPreferences

  String get connectionString => _connectionString;

  Future<void> saveSelectedServer(bool isUsingLocal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serverKey, isUsingLocal);
  }

  Future<bool> loadSelectedServer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_serverKey) ?? true; // Default to local server
  }

  Future<bool> connectToDatabase([String? customUrl]) async {
    try {
      if (customUrl != null && customUrl.isNotEmpty) {
        _connectionString = customUrl;
      }

      if (isConnected) {
        await db.close();
        isConnected = false;
      }

      db = await Db.create(_connectionString);
      await db.open();

      // Configurar el keep-alive
      _startKeepAlive();

      // Verificación básica de conexión
      await db.runCommand({'ping': 1});

      isConnected = true;
      return true;
    } catch (e) {
      print("Error de conexión: $e");
      isConnected = false;
      _stopKeepAlive();
      return false;
    }
  }

  void _startKeepAlive() {
    _stopKeepAlive(); // Detener cualquier timer existente

    // Enviar un ping cada 5 minutos para mantener la conexión activa
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        if (isConnected) {
          await db.runCommand({'ping': 1});
          print('Keep-alive ping enviado');
        }
      } catch (e) {
        print('Error en keep-alive: $e');
        isConnected = false;
      }
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  Future<bool> changeServerUrl(String newUrl) async {
    return await connectToDatabase(newUrl);
  }

  Future<void> closeConnection() async {
    _stopKeepAlive();
    if (isConnected) {
      await db.close();
      isConnected = false;
    }
  }
}
