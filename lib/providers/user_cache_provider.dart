import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:dongo_chat/models/user.dart';

class UserCacheProvider with ChangeNotifier {
  final Map<String, User> _cache = {};

  void cacheUser(User user) {
    if (user.id != null) {
      _cache[user.id!.toHexString()] = user;
    }
  }

  User? getUser(ObjectId? id) {
    if (id == null) return null;
    return _cache[id.toHexString()];
  }

  Map<ObjectId, User> get allUsers {
    final result = <ObjectId, User>{};
    _cache.forEach((key, user) {
      if (user.id != null) {
        result[user.id!] = user;
      }
    });
    return result;
  }
}