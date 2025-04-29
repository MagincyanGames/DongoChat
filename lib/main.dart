import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/providers/ThemeProvider.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/screens/chat/main_screen.dart';
import 'package:dongo_chat/screens/login_screen.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Definición centralizada de la versión de la app
const String appVersion = '0.7.2';

final databaseService = DatabaseService();
final navigatorKey = GlobalKey<NavigatorState>();

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
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
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

  @override
  void initState() {
    super.initState();
    _initialUserFuture = _restoreSession();
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

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
            extensions: [
              ChatTheme(
                // Gradientes de mensaje
                myMessageGradient: [
                  Colors.deepPurple,
                  Colors.deepPurple.shade700,
                ],
                otherMessageGradient: [
                  Colors.blue.shade600,
                  Colors.blue.shade800,
                ],

                // Mis mensajes citados (borde morado)
                myQuotedMessageBorderColor: Colors.purple.shade300,
                myQuotedMessageBackgroundColor: Colors.white,

                // Mensajes de otros citados (borde azul)
                otherQuotedMessageBorderColor: Colors.deepPurple.shade200,
                otherQuotedMessageBackgroundColor: Colors.white.withAlpha(200),

                // Colores de texto comunes
                quotedMessageTextColor: Colors.grey.shade800,
                quotedMessageNameColor: Colors.deepPurple.shade700,
              ),
            ],
          ),
          darkTheme: ThemeData(
            useMaterial3: false,
            brightness: Brightness.dark,
            primarySwatch: Colors.deepPurple,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.deepPurple,
              brightness: Brightness.dark,
            ).copyWith(
              secondary: Colors.blue.shade800,
              onSecondary: const Color.fromARGB(255, 255, 255, 255),
              background: Color.fromARGB(255, 0, 0, 0),
              surface: Colors.grey[850],
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey[900],
              foregroundColor: Colors.white,
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            cardColor: Colors.grey[850],
            canvasColor: const Color.fromARGB(255, 27, 25, 34),
            extensions: [
              ChatTheme(
                // Gradientes de mensaje
                myMessageGradient: [
                  Colors.deepPurple.shade600,
                  Colors.deepPurple.shade900,
                ],
                otherMessageGradient: [
                  Colors.blue.shade700,
                  Colors.blue.shade900,
                ],

                // Mis mensajes citados (borde morado claro)
                myQuotedMessageBorderColor: Colors.purple.shade300,
                myQuotedMessageBackgroundColor: Colors.black.withAlpha(175),

                // Mensajes de otros citados (borde azul)
                otherQuotedMessageBorderColor: Colors.blue.shade200,
                otherQuotedMessageBackgroundColor: Colors.black.withAlpha(100),

                // Colores de texto comunes
                quotedMessageTextColor: Colors.grey.shade300,
                quotedMessageNameColor: Colors.deepPurple.shade300,
              ),
            ],
          ),
          themeMode: themeProvider.themeMode,
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
