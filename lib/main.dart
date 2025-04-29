import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/screens/chat/main_screen.dart';
import 'package:dongo_chat/screens/login_screen.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Definición centralizada de la versión de la app
const String appVersion = '0.5.2';

final databaseService = DatabaseService();
final navigatorKey = GlobalKey<NavigatorState>();

// /// Handler global para mensajes en segundo plano
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   // Inicializar Firebase nuevamente en isolate de background
//   await Firebase.initializeApp();
//   print('🔔 Mensaje en segundo plano: ${message.messageId}');
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp();

  // Registrar el handler para mensajes en background
  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Solicitar permisos de notificación (Android 13+ / iOS)
  // NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
  //   alert: true,
  //   badge: true,
  //   provisional: false,
  //   sound: true,
  // );

  // print('Permisos de notificación: ${settings.authorizationStatus}');

  // Cargar el servidor seleccionado
  final isConnected = await databaseService.connectToPreferences();
  print(
    isConnected
        ? 'Conexión a la base de datos exitosa'
        : 'Error al conectar a la base de datos',
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: databaseService),
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late Future<User?> _initialUserFuture;
  // late final FirebaseMessaging _messaging;

  @override
  void initState() {
    super.initState();
    _initialUserFuture = _restoreSession();

    // Inicializar instancia de FirebaseMessaging
    // _messaging = FirebaseMessaging.instance;

    // 1. Listener: mensajes en primer plano
    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //   print('📥 Mensaje en foreground: ${message.notification?.title} - ${message.notification?.body}');
    //   if (message.notification != null) {
    //     // Mostrar SnackBar o alerta
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text(message.notification!.body ?? 'Nueva notificación'),
    //       ),
    //     );
    //   }
    // });

    // // 2. Handler: app iniciada por notificación (app cerrada)
    // FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    //   if (message != null) {
    //     _handleMessageOpen(message);
    //   }
    // });

    // // 3. Listener: app en background -> abierta por notificación
    // FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);
  }

  Future<User?> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final pwdHash = prefs.getString('password');
    if (username != null && pwdHash != null) {
      final userMgr = DBManagers.user;
      final ok = await userMgr.authenticateUser(username, pwdHash);
      if (ok) {
        final doc = await userMgr.findByUsername(username);
        if (doc != null) {
          doc.password = pwdHash;
          context.read<UserProvider>().user = doc;
          return doc;
        }
      }
    }
    return null;
  }

  // void _handleMessageOpen(RemoteMessage message) {
  //   print('🚀 App abierta desde notificación con data: ${message.data}');
  //   // Ejemplo: navegar a pantalla de chat si contiene campo 'chatId'
  //   final chatId = message.data['chatId'];
  //   if (chatId != null) {
  //     navigatorKey.currentState?.pushNamed(
  //       '/main',
  //       arguments: {'chatId': chatId},
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _initialUserFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        final homeWidget =
            snap.data != null ? const MainScreen() : const LoginScreen();

        return MaterialApp(
          title: 'Base',
          theme: ThemeData(
            useMaterial3: false,
            primarySwatch: Colors.deepPurple,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.deepPurple,
            ).copyWith(
              secondary: Colors.deepPurple.shade900,
              onSecondary: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          navigatorKey: navigatorKey,
          routes: {
            '/login': (_) => const LoginScreen(),
            '/main': (_) => const MainScreen(),
          },
          home: homeWidget,
          builder:
              (ctx, child) => SafeArea(top: true, bottom: true, child: child!),
        );
      },
    );
  }
}
