import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dongo_chat/database/managers/api_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

class DatabaseService extends ChangeNotifier {
  // Authentication token for API requests
  String? auth;
  
  // Connection state
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  // Lock for synchronized operations
  final _lock = Lock();
  
  // Server URLs
  final String _localServerUrl = 'http://192.168.0.71:10000/api';
  final String _onlineServerUrl = 'https://dongoserver.onrender.com/api';
  
  // Current connection string
  String _connectionString = '';
  String get connectionString => _connectionString;
  
  // Initialize the service
  Future<void> initialize() async {
    // Load the preferred server from SharedPreferences
    await loadSelectedServer();
    
    // Try to connect to the server
    await connectToDatabase();
  }
  
  // Load selected server preference from SharedPreferences
  Future<bool> loadSelectedServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLocal = prefs.getBool('use_local_server') ?? false;
      
      // Set the connection string based on the saved preference
      _connectionString = isLocal ? _localServerUrl : _onlineServerUrl;
      
      // Update ApiManager base URL
      ApiManager.setBaseUrl(_connectionString);
      
      return isLocal;
    } catch (e) {
      print('Error loading server selection: $e');
      // Default to local server if an error occurs
      _connectionString = _localServerUrl;
      ApiManager.setBaseUrl(_connectionString);
      return true;
    }
  }
  
  // Save server selection to SharedPreferences
  Future<bool> saveSelectedServer(bool useLocalServer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_local_server', useLocalServer);
      
      // Set the connection string based on the new preference
      _connectionString = useLocalServer ? _localServerUrl : _onlineServerUrl;
      
      // Update ApiManager base URL
      ApiManager.setBaseUrl(_connectionString);
      
      return true;
    } catch (e) {
      print('Error saving server selection: $e');
      return false;
    }
  }
  
  // Change server URL
  Future<bool> changeServerUrl(String newUrl) async {
    return await _lock.synchronized(() async {
      try {
        _connectionString = newUrl;
        
        // Update ApiManager base URL
        ApiManager.setBaseUrl(_connectionString);
        
        // Test connection to the new server
        final connected = await connectToDatabase();
        
        if (connected) {
          // If connection is successful, save the preference
          bool isLocal = newUrl == _localServerUrl;
          await saveSelectedServer(isLocal);
          return true;
        } else {
          return false;
        }
      } catch (e) {
        print('Error changing server URL: $e');
        return false;
      }
    });
  }
  
  // Check connection to the database
  Future<bool> connectToDatabase() async {
    return await _lock.synchronized(() async {
      try {
        // Attempt to ping the server
        final response = await http.get(
          Uri.parse('$_connectionString/ping'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 5));
        
        _isConnected = response.statusCode == 200;
        
        // Notify listeners of connection state change
        notifyListeners();
        
        return _isConnected;
      } catch (e) {
        print('Error connecting to server: $e');
        _isConnected = false;
        notifyListeners();
        return false;
      }
    });
  }
  
  // Load authentication token from SharedPreferences
  Future<String?> loadAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      auth = prefs.getString('user_token');
      return auth;
    } catch (e) {
      print('Error loading auth token: $e');
      return null;
    }
  }
  
  // Save authentication token to SharedPreferences
  Future<bool> saveAuthToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_token', token);
      auth = token;
      return true;
    } catch (e) {
      print('Error saving auth token: $e');
      return false;
    }
  }
  
  // Clear authentication token from SharedPreferences
  Future<bool> clearAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_token');
      auth = null;
      return true;
    } catch (e) {
      print('Error clearing auth token: $e');
      return false;
    }
  }
  
  // Create an authenticated HTTP client
  http.Client createClient() {
    return http.Client();
  }
}
