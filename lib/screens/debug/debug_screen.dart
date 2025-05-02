// debug_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/main.dart' show appVersion;

const TOTAL_BYTES = 5 * 1024 * 1024; // 5 MB
const RED_BYTES = 3 * 1024 * 1024; // 1 MB
const ORANGE_BYTES = 512 * 1024; // 512 KB

class DebugScreen extends StatefulWidget {
  const DebugScreen({Key? key}) : super(key: key);

  @override
  _DebugScreenState createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  late DatabaseService _databaseService;
  final _hostController = TextEditingController();
  final _databaseNameController = TextEditingController();
  String _selectedProtocol = 'mongodb://';
  bool _isLoading = false;

  final String _localConnectionString =
      'mongodb://play.onara.top:27017/DongoChat';
  final String _onlineConnectionString =
      'mongodb+srv://onara:AduLHQ6icblTnfCV@onaradb.5vdzp.mongodb.net/?retryWrites=true&w=majority&appName=onaradb/DongoChat';
  bool _isUsingLocalConnection = true; // Track which connection is active

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Asigno siempre el servicio
    _databaseService = Provider.of<DatabaseService>(context, listen: false);

    // Leer el estado del servidor seleccionado desde SharedPreferences
    _loadServerSelection();
  }

  Future<void> _loadServerSelection() async {
    final isUsingLocal = await _databaseService.loadSelectedServer();
    setState(() {
      _isUsingLocalConnection = isUsingLocal;
      _parseCurrentConnectionString();
    });
  }

  void _parseCurrentConnectionString() {
    final connectionString = _databaseService.connectionString;

    if (connectionString.startsWith('mongodb+srv://')) {
      _selectedProtocol = 'mongodb+srv://';
    } else {
      _selectedProtocol = 'mongodb://';
    }

    final withoutProtocol = connectionString.replaceFirst(
      _selectedProtocol,
      '',
    );
    final parts = withoutProtocol.split('/');

    _hostController.text = parts.isNotEmpty ? parts[0] : '';
    _databaseNameController.text = parts.length > 1 ? parts[1] : '';
  }

  @override
  void dispose() {
    _hostController.dispose();
    _databaseNameController.dispose();
    super.dispose();
  }

  String _buildConnectionString() {
    return _isUsingLocalConnection
        ? _localConnectionString
        : _onlineConnectionString;
  }

  Future<void> _reconnectToDatabase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final connected = await _databaseService.connectToDatabase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connected
                ? 'Conexión exitosa a la base de datos'
                : 'Error al conectar con la base de datos',
          ),
          backgroundColor: connected ? Colors.green : Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _changeServerUrl() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_hostController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor ingresa la dirección del servidor'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (_databaseNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor ingresa el nombre de la base de datos'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final newUrl = _buildConnectionString();

      final success = await _databaseService.changeServerUrl(newUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Servidor cambiado correctamente'
                : 'Error al conectar al nuevo servidor',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyLocalPrefab() async {
    setState(() {
      _isUsingLocalConnection = true;
      _selectedProtocol = 'mongodb://';
      _hostController.text = 'play.onara.top:27017';
      _databaseNameController.text = 'DongoChat';
    });

    // Guardar la selección del servidor
    await _databaseService.saveSelectedServer(true);
  }

  void _applyOnlinePrefab() async {
    setState(() {
      _isUsingLocalConnection = false;
      _selectedProtocol = 'mongodb+srv://';
      _hostController.text = 'onara:AduLHQ6icblTnfCV@onaradb.5vdzp.mongodb.net';
      _databaseNameController.text = 'DongoChat';
    });

    // Guardar la selección del servidor
    await _databaseService.saveSelectedServer(false);
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtenemos el provider de usuario
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Mostrar diálogo de confirmación
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text(
                    '¿Estás seguro que deseas cerrar sesión?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!confirmed) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Realizar el logout
      await userProvider.logout();

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión cerrada correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navegar a la pantalla de login
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatSize(int size) {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Herramientas de Debug'),
        backgroundColor:
            theme.colorScheme.primary, // Usar color primario del tema
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uso de almacenamiento en caché',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Consumer<DatabaseService>(
                      builder: (context, dbService, _) {
                        final cacheSize =
                            DBManagers.size; // Cambiado a DBManager.size
                        final formattedSize = _formatSize(cacheSize);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tamaño actual de la caché: $formattedSize',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value:
                                  cacheSize > TOTAL_BYTES
                                      ? 1.0
                                      : cacheSize / TOTAL_BYTES,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                cacheSize > RED_BYTES
                                    ? Colors.red
                                    : cacheSize > ORANGE_BYTES
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado de la conexión',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _databaseService.isConnected
                              ? Icons.check_circle
                              : Icons.error,
                          color:
                              _databaseService.isConnected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _databaseService.isConnected
                              ? 'Conectado a la base de datos'
                              : 'No conectado a la base de datos',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                _databaseService.isConnected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child:
                          _isLoading
                              ? Center(
                                child: CircularProgressIndicator(
                                  color: theme.colorScheme.primary,
                                ),
                              )
                              : ElevatedButton(
                                onPressed: _reconnectToDatabase,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Reconectar a la base de datos',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Segundo card (configuración del servidor)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuración del servidor',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Connection info display (read-only)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Conexión actual:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Protocolo: $_selectedProtocol'),
                          const SizedBox(height: 4),
                          Text('Servidor: ${_hostController.text}'),
                          const SizedBox(height: 4),
                          Text(
                            'Base de datos: ${_databaseNameController.text}',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'Seleccionar conexión:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Selection buttons with active state indication
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _applyLocalPrefab,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isUsingLocalConnection
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.surfaceVariant,
                              foregroundColor:
                                  _isUsingLocalConnection
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side:
                                    _isUsingLocalConnection
                                        ? BorderSide(
                                          color: theme.colorScheme.primary,
                                          width: 2,
                                        )
                                        : BorderSide.none,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.computer, size: 24),
                                const SizedBox(height: 8),
                                const Text('LOCAL'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _applyOnlinePrefab,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  !_isUsingLocalConnection
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.surfaceVariant,
                              foregroundColor:
                                  !_isUsingLocalConnection
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side:
                                    !_isUsingLocalConnection
                                        ? BorderSide(
                                          color: theme.colorScheme.primary,
                                          width: 2,
                                        )
                                        : BorderSide.none,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.cloud, size: 24),
                                const SizedBox(height: 8),
                                const Text('ONLINE'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child:
                          _isLoading
                              ? Center(
                                child: CircularProgressIndicator(
                                  color: theme.colorScheme.primary,
                                ),
                              )
                              : ElevatedButton(
                                onPressed: _changeServerUrl,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.secondary,
                                  foregroundColor:
                                      theme.colorScheme.onSecondary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Aplicar cambios',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tercer card (gestión de sesión)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestión de sesión',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer<UserProvider>(
                      builder: (context, userProvider, _) {
                        final user = userProvider.user;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Usuario actual: ${user?.displayName ?? 'No hay sesión activa'}',
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                    SizedBox(
                      width: double.infinity,
                      child:
                          _isLoading
                              ? Center(
                                child: CircularProgressIndicator(
                                  color: theme.colorScheme.primary,
                                ),
                              )
                              : ElevatedButton(
                                onPressed: _logout,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.error,
                                  foregroundColor: theme.colorScheme.onError,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Cerrar sesión',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cuarto card (información adicional)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información adicional',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Versión de la app: $appVersion',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text('Modo: Debug', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nuevo card (servidor seleccionado)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Servidor seleccionado',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isUsingLocalConnection ? 'Servidor: Local' : 'Servidor: Online',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
