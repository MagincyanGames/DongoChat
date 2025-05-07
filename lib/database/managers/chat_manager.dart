import 'dart:convert';

import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/managers/api_manager.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/utils/crypto.dart';

class ChatManager extends ApiManager<Chat> {
  ChatManager(DatabaseService databaseService) : super(databaseService);

  @override
  bool get needAuth => true;

  @override
  String get endpoint => "chats"; // Use plural naming convention for REST APIs

  @override
  bool get useCache => true; // Enable caching for better performance

  @override
  Chat fromMap(Map<String, dynamic> map) => Chat.fromMap(map);

  @override
  Map<String, dynamic> toMap(Chat item) => item.toMap();

  Future<ObjectId> addMessageToChat(
    ObjectId id,
    String text,
    ObjectId sender,
    MessageData? messageData,
  ) async {
    final url = "${this.url}/${id.oid}/messages";
    var msg = Message(id: id, sender: sender, message: text, data: messageData);
    print("Adding message to chat: $url");
    print(UserProvider.publicServerKey);
    final body = msg.encrypt(UserProvider.publicServerKey!).toMap();

    final res = await http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${auth}',
      },
    );

    final data = jsonDecode(res.body);

    return ObjectId.parse(data['messageId']);
  }

  /// Fetches a list of all chat summaries for the current user.
  ///
  /// Returns a list of Chat objects with summary information including:
  /// - Basic chat details (id, name)
  /// - Latest message information
  /// - User permissions (admin, read/write, read-only)
  /// - Privacy settings
  /// - Message count
  Future<List<ChatSummary>> getChatSummaries() async {
    final url = "${this.url}/summary";
    print("Fetching chat summaries from: $url");

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${auth}',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((summary) => ChatSummary.fromMap(summary)).toList();
    } else {
      throw Exception('Failed to load chat summaries: ${response.statusCode}');
    }
  }

  /// Checks for updates to chat summaries
  ///
  /// Sends the current summaries to the server which will return information
  /// about which chats need to be updated
  Future<Map<String, dynamic>> checkForSummariesUpdates(
    List<Map<String, dynamic>> currentSummaries,
  ) async {
    final customUrl = "$url/updates";

    try {
      final response = await http.post(
        Uri.parse(customUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${databaseService.auth}',
        },
        body: jsonEncode({'summaries': currentSummaries}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to check for updates: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error checking for updates: $e');
      rethrow;
    }
  }

  Future<Chat?> checkForChatUpdate(ChatSummary summary) async {
    final customUrl = "$url/check";

    try {
      final response = await http.post(
        Uri.parse(customUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth}',
        },
        body: jsonEncode(summary.toMap()),
      );

      if (response.statusCode == 200) {
        var res = jsonDecode(response.body);
        if (res == null) return null;
        return Chat.fromMap(res).decrypt();
      } else {
        throw Exception(
          'Failed to check for updates: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error checking for updates: $e');
      rethrow;
    }
  }

  Future<ChatSummary?> updateChat(ObjectId id, Map<String, dynamic> updateData) async {
    try {
      final response = await http.put(
        Uri.parse('$url/${id.toHexString()}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth}',
        },
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['summary'] != null) {
          // Update the summary in local cache if needed
          final updatedSummary = ChatSummary.fromMap(responseData['summary']);
          return updatedSummary;
        }
      } else {
        throw Exception('Failed to update chat: ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error updating chat: $e');
      throw e;
    }
  }
}
