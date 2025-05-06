import 'package:dongo_chat/database/db_managers.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';

class UserProvider extends ChangeNotifier {
  User? _user;
  String? _token;
  static RSAPublicKey? _publicServerKey;
  static RSAPublicKey? get publicServerKey => _publicServerKey;


  User? get user => _user;
  String? get token => _token;

  set user(User? value) {
    _user = value;
    notifyListeners();
  }

  /// Authenticates a user with the provided credentials
  ///
  /// Returns true if login was successful, false otherwise.
  /// Throws exceptions for network errors or other issues.
  Future<bool> login(String username, String password) async {
    try {
      final result = await DBManagers.user.login(username, password);

      if (result != null &&
          result.containsKey('user') &&
          result.containsKey('token')) {
        // Store the user information


        _user = result['user'];
        _token = result['token'];
        _publicServerKey = RSAKeyParser().parse(result['serverPublicKey']) as RSAPublicKey;

        // Save credentials in local storage for session persistence
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        await prefs.setString('password', password);
        await prefs.setString('user_token', _token!);

        // Update FCM token if on Android
        if (Platform.isAndroid) {
          await _updateFcmToken();
        }

        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  /// Registers a new user with the provided information
  ///
  /// Returns true if registration was successful, false otherwise.
  /// Throws exceptions for network errors, username conflicts, or other issues.
  Future<bool> register({
    required String displayName,
    required String username,
    required String password,
    int? color,
    String? fcmToken,
  }) async {
    try {
      // If on Android and fcmToken isn't provided, try to get it
      if (Platform.isAndroid && fcmToken == null) {
        fcmToken = await FirebaseMessaging.instance.getToken();
      }

      final result = await DBManagers.user.signup(
        displayName: displayName,
        username: username,
        password: password,
        color: color,
        fcmToken: fcmToken,
      );
      if (result != null &&
          result.containsKey('user') &&
          result.containsKey('token')) {
        // Store the user information
        _user = result['user'];
        _token = result['token'];
        _publicServerKey = RSAKeyParser().parse(result['serverPublicKey']) as RSAPublicKey;

        // Save credentials in local storage for session persistence
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        await prefs.setString('password', password);
        await prefs.setString('user_token', _token!);

        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  /// Restores a user session from stored credentials
  ///
  /// Returns true if restoration was successful, false otherwise.
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      final password = prefs.getString('password');

      if (username != null && password != null) {
        return await login(username, password);
      }
      return false;
    } catch (e) {
      print('Session restoration error: $e');
      return false;
    }
  }

  /// Updates the FCM token if it has changed
  Future<void> _updateFcmToken() async {
    if (_user != null && _user!.id != null) {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && _user!.fcmToken != fcmToken) {
        _user!.fcmToken = fcmToken;
        await DBManagers.user.Put(_user!.id!, _user!);
      }
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('password');
    await prefs.remove('user_token');

    notifyListeners();
  }
}
