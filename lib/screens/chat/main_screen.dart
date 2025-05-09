// import 'dart:math';

// import 'package:dongo_chat/database/database_service.dart';
// import 'package:dongo_chat/database/db_managers.dart';
// import 'package:dongo_chat/database/managers/chat_manager.dart';
// import 'package:dongo_chat/main.dart';
// import 'package:dongo_chat/models/chat.dart';
// import 'package:dongo_chat/models/message.dart';
// import 'package:dongo_chat/models/user.dart';
// import 'package:dongo_chat/providers/UserProvider.dart';
// import 'package:dongo_chat/screens/chat/widgets/chat_view.dart';
// import 'package:dongo_chat/screens/chat/widgets/json_chat_view.dart';
// import 'package:dongo_chat/screens/chat/widgets/loadding_screen.dart';
// import 'package:dongo_chat/screens/chat/widgets/logout_button.dart';
// import 'package:dongo_chat/screens/debug/debug_button.dart';
// import 'package:dongo_chat/theme/chat_theme.dart';
// import 'package:dongo_chat/widgets/theme_toggle_button.dart';
// import 'package:dongo_chat/screens/chat/widge.dart';
// import 'package:flutter/material.dart';
// import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
// import 'package:provider/provider.dart';
// import 'dart:async';

// class MainScreen extends StatefulWidget {
//   const MainScreen({super.key});

//   @override
//   State<MainScreen> createState() => MainScreenState();
// }

// class MainScreenState extends State<MainScreen> {
//   // Add a key variable to track state changes
//   int _selectorRebuildCounter = 0;
//   bool _navigatingBackWithGesture = false;
//   bool _navigatingForwardToChat = false; // Add this new flag

//   late final ChatManager _chatManager;
//   late final DatabaseService _dbService;
//   String? _debugError;
//   bool _isLoading = false;
//   final GlobalKey<ChatViewState> _chatViewKey = GlobalKey<ChatViewState>();

//   // El chat actual
//   String? _chatName;
//   Chat? _currentChat;
//   ObjectId? _chatId;
//   bool _showSelector = true;

//   // Almacenar los summaries en el estado principal
//   List<ChatSummary> _chatSummaries = [];
//   bool _loadingSummaries = true;

//   @override
//   void initState() {
//     super.initState();
//     _dbService = Provider.of<DatabaseService>(context, listen: false);
//     _chatManager = DBManagers.chat;

//     // Process route arguments if any
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final args = ModalRoute.of(context)?.settings.arguments;
//       if (args != null && args is Map<String, dynamic>) {
//         if (args.containsKey('connectTo')) {
//           final chatId = args['connectTo'] as ObjectId;
//           print("MainScreen: Connecting to chat ${chatId.toHexString()}");
//           _connectToChat(chatId);
//         }
//       } else {
//         // Si no hay argumentos, inicializamos el chat normalmente
//         _loadChatSummaries();
//       }
//     });
//     // Configurar un timer para verificar nuevos chats periódicamente
//     Timer.periodic(const Duration(seconds: 10), (_) {
//       if (_showSelector && mounted) {
//         checkForChatUpdates();
//       }
//     });
//   }

//   // Método para verificar actualizaciones en los chats
//   Future<void> checkForChatUpdates() async {
//     final hasChanges = await _chatManager.checkForNewChats(_chatSummaries);
//     if (hasChanges && mounted) {
//       // Solo recargamos si hay cambios
//       _loadChatSummaries();
//     }
//   }

//   // Método para cargar los summaries
//   Future<void> _loadChatSummaries() async {
//     setState(() => _loadingSummaries = true);

//     try {
//       final summaries = await _chatManager.findAllChatSummaries();

//       if (mounted) {
//         setState(() {
//           _chatSummaries = summaries;
//           _loadingSummaries = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _loadingSummaries = false;
//           _debugError = "Error cargando los chats: ${e.toString()}";
//         });
//       }
//     }
//   }

//   Future<void> _initializeChat() async {
//     if (_chatId == null) {
//       // Si no hay chat seleccionado, mostramos el selector
//       setState(() => _showSelector = true);
//       return;
//     }

//     try {
//       // Inicializar el chat
//       final chat = await _chatManager.initChat(_chatId!);

//       if (mounted) {
//         setState(() {
//           if (chat != null) {
//             _currentChat = chat;
//             _debugError = null;
//           } else {
//             _debugError = "Error al inicializar el chat";
//           }
//         });
//       }
//     } catch (error) {
//       if (mounted) {
//         setState(() => _debugError = error.toString());
//       }
//     }
//   }

//   Future<void> _handleSendMessage(
//     String text,
//     ObjectId userId,
//     MessageData? messageData,
//   ) async {
//     setState(() => _isLoading = true);

//     if (_chatId == null) {
//       // Si no hay chat seleccionado, mostramos el selector
//       setState(() => _showSelector = true);
//       setState(() => _isLoading = false);

//       return;
//     }

//     try {
//       // Enviar mensaje al chat actual
//       await _chatManager.addMessageToChat(_chatId!, text, userId, messageData);
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<bool> _handleRefreshMessages() async {
//     if (_currentChat == null) return false;

//     // Si estamos en el selector, también actualizamos los summaries
//     if (_showSelector) {
//       await _loadChatSummaries();
//     }

//     return await _chatManager.checkForNewMessages(_chatId!);
//   }

//   // Métodos expuestos para compatibilidad con código existente
//   void setReplyMessage(ObjectId messageId) {
//     _chatViewKey.currentState?.setReplyMessage(messageId);
//   }

//   void scrollToMessage(ObjectId messageId) {
//     _chatViewKey.currentState?.scrollToMessage(messageId);
//   }

//   /// Convierte "general" → "General",
//   ///         "this-is-a-test" → "This is a test"
//   String prettify(String input) {
//     // 1. Reemplaza guiones por espacios
//     final withSpaces = input.replaceAll('-', ' ');
//     if (withSpaces.isEmpty) return withSpaces;
//     // 2. Capitaliza la primera letra
//     return withSpaces[0].toUpperCase() + withSpaces.substring(1);
//   }

//   void setChatName(String name) {
//     setState(() {
//       _chatName = name;
//     });
//   }

//   Widget _chatSelectorScreen() {
//     return _loadingSummaries
//         ? const Center(child: CircularProgressIndicator())
//         : ChatSelection(
//           key: const ValueKey('selector'), // Añadir clave explícita aquí
//           chatSummaries: _chatSummaries,
//           onCreateChat: (name, privacy) {
//             print("Creating chat with name: $name and privacy: $privacy");

//             final user = context.read<UserProvider>().user;
//             final chat = Chat(name: name, privacity: privacy);
//             if (user != null && user.id != null) {
//               chat.adminUsers.add(user.id!);
//             }

//             setState(() => _isLoading = true); // Show loading indicator

//             DBManagers.chat
//                 .add(chat)
//                 .then((chatId) {
//                   if (mounted) {
//                     DBManagers.chat.findById(chatId).then((chat) {
//                       setState(() {
//                         _chatId = chatId;
//                         _chatName = name;
//                         _showSelector = false;
//                         _navigatingForwardToChat =
//                             true; // Enable forward animation
//                         _isLoading = false; // Hide loading indicator
//                       });

//                       // Initialize the chat immediately
//                       _initializeChat();

//                       // Reset the navigation flag after animation completes
//                       Future.delayed(const Duration(milliseconds: 300), () {
//                         if (mounted)
//                           setState(() => _navigatingForwardToChat = false);
//                       });
//                     });
//                   }
//                 })
//                 .catchError((error) {
//                   if (mounted) {
//                     setState(() => _isLoading = false);
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text(
//                           'Error creating chat: ${error.toString()}',
//                         ),
//                       ),
//                     );
//                   }
//                 });
//           },
//           onDeleteChat: (chatId) {
//             setState(() => _isLoading = true); // Show loading indicator

//             DBManagers.chat
//                 .delete(chatId)
//                 .then((_) {
//                   if (mounted) {
//                     setState(() {
//                       _isLoading = false; // Hide loading indicator
//                       _loadChatSummaries(); // Reload summaries after deletion
//                     });
//                   }
//                 })
//                 .catchError((error) {
//                   if (mounted) {
//                     setState(() => _isLoading = false);
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text(
//                           'Error deleting chat: ${error.toString()}',
//                         ),
//                       ),
//                     );
//                   }
//                 });
//           }, onChatSelected: (ChatSummary value) {  },
//         );
//   }

//   Widget _loadding() {
//     return LoadingChatScreen(error: _debugError, onRetry: _initializeChat);
//   }

//   Widget _chatScreen(User user) {
//     return ChatView(
//       key: ValueKey(_chatId), // forzar rebuild al cambiar chat
//       chat: _currentChat!,
//       currentUser: user,
//       onSendMessage: _handleSendMessage,
//       onRefreshMessages: _handleRefreshMessages,
//       isLoading: _isLoading,
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     Widget? body;
//     List<Widget> actions = [];

//     final theme = Theme.of(context);
//     final chatTheme = theme.extension<ChatTheme>();

//     // Si estamos en selector (por defecto true), mostramos la lista
//     if (_showSelector) {
//       body = Container(
//         key: const ValueKey('selector'), // Añadir clave explícita aquí
//         width: double.infinity,
//         height: double.infinity,
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.centerLeft,
//             end: Alignment.centerRight,
//             colors: [
//               chatTheme?.otherMessageGradient.last ?? Colors.blue.shade900,
//               chatTheme?.myMessageGradient.first ?? Colors.deepPurple.shade900,
//             ],
//           ).withOpacity(0.6),
//         ),
//         child: _chatSelectorScreen(),
//       );
//     }

//     // pantalla de chat normal
//     final user = context.watch<UserProvider>().user;
//     if (_currentChat == null && !_showSelector) {
//       body = _loadding();
//     }

//     if (!_showSelector && _currentChat != null && user != null) {
//       body = _chatScreen(user);
//     }

//     actions = [
//       const ThemeToggleButton(),

//       Material(
//         color: Colors.transparent,
//         child: IconButton(
//           iconSize: 20,
//           icon: const Icon(Icons.newspaper),
//           tooltip: 'News',
//           onPressed:
//               () => Navigator.of(context).push(
//                 MaterialPageRoute(
//                   builder:
//                       (context) => JsonChatView(
//                         jsonUrl: 'https://raw.githubusercontent.com/MagincyanGames/DongoChat/refs/heads/master/news.json',
//                         currentUser:
//                             Provider.of<UserProvider>(
//                               context,
//                               listen: false,
//                             ).user,
//                       ),
//                 ),
//               ),
//         ),
//       ),
//       const DebugButton(),
//     ];

//     return PopScope(
//       canPop: _showSelector, // Only allow app to close when in selector view
//       onPopInvoked: (didPop) {
//         // If we're in chat view and back was pressed
//         if (!didPop) {
//           _loadChatSummaries(); // Recargar summaries al volver al selector
//           setState(() {
//             _navigatingBackWithGesture =
//                 true; // Renombramos esta variable para mayor claridad
//             _showSelector = true;
//             _selectorRebuildCounter++; // Increment counter to force rebuild
//           });

//           // Reset the flag after animation completes
//           Future.delayed(const Duration(milliseconds: 300), () {
//             if (mounted) setState(() => _navigatingBackWithGesture = false);
//           });
//         }
//       },
//       child: Scaffold(
//         resizeToAvoidBottomInset: true,
//         appBar: AppBar(
//           title: Text(
//             _showSelector
//                 ? 'Chats - $appVersion'
//                 : prettify(_chatName ?? 'Unnamed Chat'),
//           ),
//           actions: actions,
//           flexibleSpace: Container(
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.centerLeft,
//                 end: Alignment.centerRight,
//                 colors: [
//                   Theme.of(
//                         context,
//                       ).extension<ChatTheme>()?.otherMessageGradient.last ??
//                       Colors.blue.shade900,
//                   Theme.of(
//                         context,
//                       ).extension<ChatTheme>()?.myMessageGradient.first ??
//                       Colors.deepPurple.shade900,
//                 ],
//               ),
//             ),
//           ),
//           backgroundColor: Colors.transparent,
//           foregroundColor: Colors.white,
//         ),
//         body: Stack(
//           children: [
//             // Background image - add this as the first child in the Stack
//             Positioned.fill(
//               child: SizedBox.expand(
//                 child: Image.asset(
//                   'assets/ajolote contrast.png',
//                   fit: BoxFit.cover,
//                   width: double.infinity,
//                   height: double.infinity,
//                   opacity: const AlwaysStoppedAnimation(0.1),
//                   colorBlendMode: BlendMode.multiply,
//                 ),
//               ),
//             ),

//             AnimatedSwitcher(
//               duration: const Duration(milliseconds: 300),
//               switchInCurve: Curves.easeOut,
//               switchOutCurve: Curves.easeIn,
//               transitionBuilder: (
//                 Widget newChild,
//                 Animation<double> animation,
//               ) {
//                 if ((newChild is ChatSelection ||
//                         (newChild.key is ValueKey &&
//                             (newChild.key as ValueKey).value == 'selector')) &&
//                     _navigatingBackWithGesture) {
//                   final offset = Tween<Offset>(
//                     begin: const Offset(0, -1), // Deslizar desde arriba
//                     end: Offset.zero,
//                   ).animate(animation);

//                   return ClipRect(
//                     child: SlideTransition(position: offset, child: newChild),
//                   );
//                 }
//                 // Add a fallback for when we're not transitioning
//                 return FadeTransition(opacity: animation, child: newChild);
//               },
//               child: body,
//             ),

//             // Botón flotante posicionado para que sobresalga del AppBar
//             if (!_showSelector)
//               Positioned(
//                 top: 10,
//                 left: 0,
//                 right: 0,
//                 child: Center(
//                   child: Container(
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       gradient: LinearGradient(
//                         begin: Alignment.centerLeft,
//                         end: Alignment.centerRight,
//                         colors: [
//                           Theme.of(context).extension<ChatTheme>()?.otherMessageGradient.last ?? Colors.blue.shade900,
//                           Theme.of(context).extension<ChatTheme>()?.myMessageGradient.first ?? Colors.deepPurple.shade900,
//                         ],
//                       ),
//                     ),
//                     padding: const EdgeInsets.all(2), // Border thickness
//                     child: Material(
//                       color: Theme.of(context).scaffoldBackgroundColor,
//                       shape: const CircleBorder(),
//                       elevation: 3,
//                       child: Ink(
//                         decoration: const ShapeDecoration(
//                           shape: CircleBorder(),
//                           color: Colors.transparent,
//                         ),
//                         child: InkWell(
//                           customBorder: const CircleBorder(),
//                           onTap: () {
//                             _loadChatSummaries();
//                             setState(() {
//                               _navigatingBackWithGesture = true;
//                               _showSelector = true;
//                               _selectorRebuildCounter++;
//                             });

//                             // Reset the flag after animation completes
//                             Future.delayed(const Duration(milliseconds: 300), () {
//                               if (mounted) setState(() => _navigatingBackWithGesture = false);
//                             });
//                           },
//                           child: Padding(
//                             padding: const EdgeInsets.all(8.0),
//                             child: Icon(
//                               Icons.group,
//                               size: 30,
//                               color: Theme.of(context).extension<ChatTheme>()?.actionIconColor ?? Colors.white,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Add this helper method to connect to a specific chat
//   Future<void> _connectToChat(ObjectId chatId) async {
//     try {
//       // Get chat summary
//       final summary = await _chatManager.getChatSummary(id: chatId);
//       if (summary == null) return;

//       // Select the chat
//       setState(() {
//         _chatId = chatId;
//         _chatName = summary.name;
//         _showSelector = false;
//       });

//       // Initialize the chat
//       await _initializeChat();
//     } catch (e) {
//       print("Error connecting to chat: $e");
//     }
//   }
// }

// // Un clipper personalizado para el efecto de cortina
// class CurtainClipper extends CustomClipper<Path> {
//   final double value;

//   CurtainClipper(this.value);

//   @override
//   Path getClip(Size size) {
//     // Si la animación ha terminado, mostrar todo el contenido sin recorte
//     if (value >= 0.99) {
//       return Path()..addRect(Rect.fromLTRB(0, 0, size.width, size.height));
//     }

//     final path = Path();
//     // La cortina baja, revelando gradualmente el contenido
//     final height = size.height * value;
//     path.addRect(Rect.fromLTRB(0, 0, size.width, height));
//     return path;
//   }

//   @override
//   bool shouldReclip(CurtainClipper oldClipper) => value != oldClipper.value;
// }
