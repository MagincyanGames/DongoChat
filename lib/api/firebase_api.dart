import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dongo_chat/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseApi {
  final _firebaseMessaging = Platform.isAndroid ? FirebaseMessaging.instance : null;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;
  bool _isInitialized = false;

  // Verificar si se pueden ENVIAR notificaciones (todas las plataformas)
  Future<bool> canSendNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_send_enabled') ?? true;
  }

  // Verificar si se pueden RECIBIR notificaciones (solo Android)
  Future<bool> canReceiveNotifications() async {
    if (!Platform.isAndroid) return false;
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_receive_enabled') ?? true;
  }

  Future<void> initNotifications() async {
    // Solo inicializar si estamos en Android y las notificaciones están habilitadas
    if (!Platform.isAndroid || !await canReceiveNotifications()) {
      print('Recepción de notificaciones deshabilitada o no disponible');
      return;
    }

    await _firebaseMessaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final FCMToken = await _firebaseMessaging!.getToken();
    print('FCM Token: $FCMToken');

    await initPushNotifications();
    _isInitialized = true;
  }

  Future<void> handleMessage(RemoteMessage? message) async {
    // Verificar si la recepción de notificaciones está habilitada
    if (!await canReceiveNotifications()) {
      print('Notificación ignorada: recepción deshabilitada por el usuario');
      return;
    }

    if (message == null) return;

    print("FIREBASERESPONSE::" + jsonEncode(message.data));

    // Extract chatId from message
    ObjectId? chatId;
    if (message.data.containsKey('chatId')) {
      try {
        chatId = ObjectId.fromHexString(message.data['chatId']);
        print("FIREBASERESPONSE:: ChatId received: " + chatId.toHexString());
      } catch (e) {
        print("Error al convertir chatId: ${e.toString()}");
      }
    }

    // Navigate to main screen with chatId argument
    if (chatId != null) {
      await navigatorKey.currentState?.pushNamed(
        '/main',
        arguments: {'connectTo': chatId},
      );
    } else {
      await navigatorKey.currentState?.pushNamed('/main');
    }

    print("FIREBASERESPONSE::Navigation completed");
  }

  Future<void> initPushNotifications() async {
    // Verificar si la recepción de notificaciones está habilitada
    if (!Platform.isAndroid || !await canReceiveNotifications()) {
      print('Configuración de recepción omitida: deshabilitada por el usuario o plataforma no compatible');
      return;
    }

    await _firebaseMessaging!.subscribeToTopic('general');
    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);

    // Guardar referencia para cancelar después si es necesario
    _onMessageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      handleMessage(message);
    });
  }

  Future<void> sendNotification(
    String title,
    String body,
    ObjectId chatId,
  ) async {
    // Verificar si el envío de notificaciones está habilitado
    if (!await canSendNotifications()) {
      print('Envío de notificación omitido: envío deshabilitado por el usuario');
      return;
    }

    // El resto del código permanece igual...
    final accessToken = await getAccessToken();
    final url = Uri.parse(
      'https://fcm.googleapis.com/v1/projects/onara-6d831/messages:send',
    );
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final payload = {
      'message': {
        'topic': 'general',
        'notification': {'title': title, 'body': body},
        'data': {'chatId': chatId.toHexString()},
      },
    };
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200) {
      print('🔔 Notification sent successfully!');
    } else {
      print('⚠️ Failed to send notification: ${response.statusCode}');
      print('📖 Response body: ${response.body}');
    }
  }

  // Método para limpiar todas las notificaciones visibles
  Future<void> clearAllNotifications() async {
    try {
      // Método 1: Usando flutter_local_notifications
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancelAll();
      
      // Método 2: Usando Firebase directamente (como respaldo)
      if (Platform.isAndroid) {
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
      }
    } catch (e) {
      print('Error al limpiar notificaciones: $e');
    }
  }
  
  // Habilitar recepción de notificaciones (solo Android)
  Future<void> enableNotificationsReceive() async {
    if (!Platform.isAndroid) return;
    await initNotifications();
    print('Recepción de notificaciones habilitada');
  }
  
  // Deshabilitar recepción de notificaciones (solo Android)
  Future<void> disableNotificationsReceive() async {
    if (!Platform.isAndroid) return;
    
    try {
      // Desinscribirse del topic
      await _firebaseMessaging?.unsubscribeFromTopic('general');
      
      // Borrar el token para dejar de recibir notificaciones
      await _firebaseMessaging?.deleteToken();

      // Cancelar suscripciones
      if (_onMessageOpenedSubscription != null) {
        await _onMessageOpenedSubscription!.cancel();
        _onMessageOpenedSubscription = null;
      }
      
      _isInitialized = false;
      print('Recepción de notificaciones deshabilitada');
    } catch (e) {
      print('Error al deshabilitar recepción: $e');
    }
  }
}
