
import 'package:dongo_chat/database/managers/chat_manager.dart';
import 'package:dongo_chat/database/managers/user_manager.dart';
import 'package:dongo_chat/main.dart';

class DBManagers{
  static ChatManager chat = ChatManager(databaseService);
  static UserManager user = UserManager(databaseService);
  
  static int get size => user.size + chat.size;
}