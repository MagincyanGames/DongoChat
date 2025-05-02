import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/main.dart';
import 'package:dongo_chat/screens/chat/main_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class FirebaseApi {
  final _firebaseMessaging = Platform.isAndroid ? FirebaseMessaging.instance : null;
  Future<void> initNotifications() async {
    await _firebaseMessaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final FCMToken = await _firebaseMessaging.getToken();
    print('FCM Token: $FCMToken');

    initPushNotifications();
  }

  Future<void> handleMessage(RemoteMessage? message) async {
    if (message == null) return;

    print("FIREBASERESPONSE::" + jsonEncode(message.data));

    // Extract chatId from message
    ObjectId? chatId;
    if (message.data.containsKey('chatId')) {
      chatId = message.data['chatId'] as ObjectId;
      print("FIREBASERESPONSE:: ChatId received: " + chatId.toHexString());
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

  Future initPushNotifications() async {
    FirebaseMessaging.instance.subscribeToTopic('general');
    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleMessage(message);
    });
  }

  Future<void> sendNotification(
    String title,
    String body,
    ObjectId chatId,
  ) async {
    // 1) Obtén un OAuth2 token válido con tu service-account
    final accessToken = await getAccessToken();

    // 2) Endpoint v1 (con tu project_id)
    final url = Uri.parse(
      'https://fcm.googleapis.com/v1/projects/onara-6d831/messages:send',
    );

    // 3) Headers con Bearer <access_token>
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    // 4) Payload v1 correcto
    final payload = {
      'message': {
        'topic': 'general', // sólo el nombre del tema
        'notification': {'title': title, 'body': body},
        'data': {'chatId': chatId.toHexString()},
      },
    };

    // 5) Envía la petición
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    // 6) Comprueba el resultado
    if (response.statusCode == 200) {
      print('🔔 Notification sent successfully!');
    } else {
      print('⚠️ Failed to send notification: ${response.statusCode}');
      print('📖 Response body: ${response.body}');
    }
  }
}
