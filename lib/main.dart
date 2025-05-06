import 'dart:convert';
import 'dart:io';

import 'package:dongo_chat/api/firebase_api.dart';
import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/firebase_options.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/providers/ThemeProvider.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/providers/chat_cache_provider.dart';
import 'package:dongo_chat/routes/main_routes.dart';
import 'package:dongo_chat/screens/chat/main_screen.dart';
import 'package:dongo_chat/screens/login_screen.dart';
import 'package:dongo_chat/screens/debug/debug_screen.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:dongo_chat/theme/main_theme.dart';
import 'package:dongo_chat/widgets/theme_transition_overlay.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Definición centralizada de la versión de la app
late String appVersion;

final databaseService = DatabaseService();
final navigatorKey = GlobalKey<NavigatorState>();

Future<String> getAccessToken() async {
  // Cargar el archivo JSON desde los assets
  final jsonString = await rootBundle.loadString('assets/credentials.json');

  // Convertir el contenido JSON en un Map
  final Map<String, dynamic> serviceAccount = json.decode(jsonString);

  // Usar el contenido para crear las credenciales de la cuenta de servicio
  final credentials = ServiceAccountCredentials.fromJson(serviceAccount);

  // Los scopes que necesitas para FCM
  final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  // Obtener el token de acceso usando el cliente de OAuth2
  final client = await clientViaServiceAccount(credentials, scopes);

  // Retornar el token de acceso
  return client.credentials.accessToken.data;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get version from pubspec.yaml
  final packageInfo = await PackageInfo.fromPlatform();
  appVersion = packageInfo.version;

  if (Platform.isAndroid) {
    // Inicializar Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FirebaseApi().initNotifications();

    // Inicializar y solicitar permisos de notificaciones
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    // Solicitar permiso de notificaciones explícitamente (Android 13+)
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<FirebaseApi>.value(
          value: FirebaseApi(),
        ), // Proporcionar FirebaseApi
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatCacheProvider()),
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

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final FirebaseApi _firebaseApi = FirebaseApi();
  late Future<User?> _initialUserFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialUserFuture = _restoreSession();

    // Limpiar notificaciones al iniciar
    if (Platform.isAndroid) {
      _firebaseApi.clearAllNotifications();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cuando la app vuelve a primer plano
    if (state == AppLifecycleState.resumed) {
      print('Aplicación resumida - limpiando notificaciones...');
      _firebaseApi.clearAllNotifications();
    }
  }

  Future<User?> _restoreSession() async {
    try {
      final userProvider = context.read<UserProvider>();
      final success = await userProvider.restoreSession()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      
      return success ? userProvider.user : null;
    } catch (e) {
      print('Error al restaurar sesión: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'DongoChat',
      theme: MainTheme(),
      darkTheme: MainDarkTheme(),
      themeMode: themeProvider.themeMode,
      navigatorKey: navigatorKey,
      routes: MainRoutes,
      home: FutureBuilder<User?>(
        future: _initialUserFuture,
        builder: (context, snap) {
          // Manejamos explícitamente el caso de error
          if (snap.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error de conexión',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No se pudo conectar a la base de datos',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _initialUserFuture = _restoreSession();
                        });
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Si todavía está cargando
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Conectando...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            );
          }
          
          if (snap.data != null) {
            print('Restaurando sesión...');
            // Deferred navigation using post-frame callback
            WidgetsBinding.instance.addPostFrameCallback((_) {
              navigatorKey.currentState?.pushReplacementNamed('/main');
            });
          } else {
            print('No hay sesión activa, redirigiendo a login...');
            // Deferred navigation using post-frame callback
            WidgetsBinding.instance.addPostFrameCallback((_) {
              navigatorKey.currentState?.pushReplacementNamed('/login');
            });
          }

          // Conexión exitosa
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      ),
      builder: (context, child) {
        return SafeArea(child: ThemeTransitionOverlay(child: child!));
      },
    );
  }
}
