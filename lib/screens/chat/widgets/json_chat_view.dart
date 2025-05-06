import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/screens/chat/widgets/message_bundle.dart';
import 'package:dongo_chat/theme/chat_theme.dart';

class JsonChatView extends StatefulWidget {
  final String? jsonAssetPath; // Path al archivo JSON local (opcional)
  final String? jsonUrl; // URL al archivo JSON remoto (opcional)
  final User? currentUser;
  final VoidCallback? onChatInitialized;
  final bool isLoading;

  const JsonChatView({
    Key? key,
    this.jsonAssetPath,
    this.jsonUrl,
    this.currentUser,
    this.onChatInitialized,
    this.isLoading = false,
  }) : assert(jsonAssetPath != null || jsonUrl != null, 
         'Debe proporcionar jsonAssetPath o jsonUrl'),
       super(key: key);

  @override
  State<JsonChatView> createState() => JsonChatViewState();
}

class JsonChatViewState extends State<JsonChatView>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // Caching maps
  final Map<String, User> _userCache = {};
  final Map<String, Message> _quotedCache = {};

  // Data
  Chat? _chat;
  List<Message> _messages = [];
  bool _isReadOnly = true;
  String _chatName = "Canal de Noticias";

  ObjectId? _highlightedMessageId;
  bool _showScrollButton = false;
  bool _initialLoadDone = false;
  MessageData messageData = MessageData();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Scroll button visibility listener
    _itemPositionsListener.itemPositions.addListener(() {
      if (!mounted) return;

      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        bool isAtBottom = false;
        for (final position in positions) {
          if (position.index == 0) {
            isAtBottom = true;
            break;
          }
        }
        final shouldShow = !isAtBottom;
        if (_showScrollButton != shouldShow) {
          setState(() => _showScrollButton = shouldShow);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadJsonData().then((_) {
        setState(() => _initialLoadDone = true);
        _scrollToBottom();
        widget.onChatInitialized?.call();
      });
    });
  }

  Future<void> _loadJsonData() async {
    try {
      // Variable para almacenar el JSON string que carguemos
      String jsonString;
      
      // Determinar la fuente del JSON (URL o archivo local)
      if (widget.jsonUrl != null) {
        // Cargar desde URL
        final response = await http.get(Uri.parse(widget.jsonUrl!));
        
        if (response.statusCode == 200) {
          jsonString = response.body;
        } else {
          throw Exception('Error al cargar JSON: ${response.statusCode}');
        }
      } else if (widget.jsonAssetPath != null) {
        // Cargar desde archivo local
        jsonString = await rootBundle.loadString(widget.jsonAssetPath!);
      } else {
        throw Exception('No se proporcionó ninguna fuente de datos JSON');
      }
      
      // Parsear el JSON
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      // Función auxiliar para extraer ObjectId de formato MongoDB
      ObjectId extractObjectId(dynamic value) {
        if (value == null) return ObjectId();
        if (value is Map && value.containsKey('\$oid')) {
          return ObjectId.fromHexString(value['\$oid']);
        }
        if (value is String) {
          return ObjectId.fromHexString(value);
        }
        return ObjectId();
      }

      // Función auxiliar para extraer timestamp de formato MongoDB
      DateTime extractTimestamp(dynamic value) {
        if (value == null) return DateTime.now();
        if (value is Map && value.containsKey('\$numberLong')) {
          final milliseconds = int.parse(value['\$numberLong']);
          return DateTime.fromMillisecondsSinceEpoch(milliseconds);
        }
        if (value is String) {
          return DateTime.parse(value);
        }
        return DateTime.now();
      }
      
      // Obtener nombre del chat
      _chatName = jsonData['name'] ?? "Canal de Noticias";
      _isReadOnly = true; // Siempre solo lectura para noticias

      // Cargar mensajes
      if (jsonData.containsKey('messages') && jsonData['messages'] is List) {
        _messages = (jsonData['messages'] as List).map((msg) {
          final messageId = extractObjectId(msg['_id']);
          final senderId = msg['sender'] != null ? extractObjectId(msg['sender']) : null;
          final timestamp = extractTimestamp(msg['timestamp']);
          
          // Procesar mensaje citado si existe
          if (msg['data'] != null && msg['data']['resend'] != null) {
            final quotedId = extractObjectId(msg['data']['resend']);
            _quotedCache[quotedId.toHexString()] = Message(
              id: quotedId,
              message: "Mensaje citado", // Esto se actualizará después
              sender: senderId,
              timestamp: timestamp,
            );
          }
          
          // Construir objeto MessageData
          MessageData? data;
          if (msg['data'] != null) {
            data = MessageData(
              resend: msg['data']['resend'] != null ? extractObjectId(msg['data']['resend']) : null,
              url: msg['data']['url'] as String?,
              type: msg['data']['type'] as String?,
            );
          }
          
          return Message(
            id: messageId,
            message: msg['message'] as String,
            sender: senderId,
            timestamp: timestamp,
            data: data,
          );
        }).toList();
        
        // Ordenar mensajes por fecha (más reciente primero)
        _messages.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
        
        // Segunda pasada para actualizar mensajes citados con su contenido real
        for (final msg in _messages) {
          if (msg.data?.resend != null) {
            final quotedMsgId = msg.data!.resend!.toHexString();
            final originalMsg = _messages.firstWhere(
              (m) => m.id!.toHexString() == quotedMsgId,
              orElse: () => Message(
                id: msg.data!.resend,
                message: "Mensaje no encontrado",
                sender: null,
                timestamp: DateTime.now(),
              ),
            );
            
            if (originalMsg != null && _quotedCache.containsKey(quotedMsgId)) {
              _quotedCache[quotedMsgId] = Message(
                id: originalMsg.id,
                message: originalMsg.message,
                sender: originalMsg.sender,
                timestamp: originalMsg.timestamp,
              );
            }
          }
        }
      }
      
      // Crear el objeto Chat
      _chat = Chat(
        id: extractObjectId(jsonData['_id']),
        name: _chatName,
        messages: _messages,
        readOnlyUsers: widget.currentUser != null ? [widget.currentUser!.id!] : [],
        readWriteUsers: [],
        adminUsers: jsonData['adminUsers'] is List 
            ? (jsonData['adminUsers'] as List)
                .map((admin) => extractObjectId(admin))
                .toList() 
            : [],
        privacity: jsonData['privacity'] as String? ?? 'publicReadOnly',
      );
    } catch (e) {
      print('Error cargando datos JSON: $e');
      _showSnackbar('Error cargando datos: $e');
      
      // Crear un chat vacío en caso de error
      _chat = Chat(
        id: ObjectId(),
        name: "Error en canal de noticias",
        messages: [
          Message(
            id: ObjectId(),
            message: "No se pudieron cargar las noticias: $e",
            sender: null,
            timestamp: DateTime.now(),
          ),
        ],
        readOnlyUsers: widget.currentUser != null ? [widget.currentUser!.id!] : [],
        readWriteUsers: [],
        adminUsers: [],
        privacity: 'publicReadOnly',
      );
      _messages = _chat!.messages;
    }
  }

  void _scrollToBottom() {
    if (!_itemScrollController.isAttached) return;

    try {
      _itemScrollController.scrollTo(
        index: 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
    } catch (e) {
      print('Error en _scrollToBottom: $e');
    }
  }

  void _ensureInputIsVisible() => _scrollToBottom();

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset > 0) {
      _scrollToBottom();
    }
  }

  // Función simulada para mostrar compatibilidad con la interfaz original
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _showSnackbar('Este es un canal de solo lectura.');
  }

  void scrollToMessage(ObjectId messageId) {
    final index = _messages.indexWhere((msg) => msg.id == messageId);

    if (index != -1 && _itemScrollController.isAttached) {
      try {
        final reversedIndex = _messages.length - 1 - index;
        _itemScrollController.scrollTo(
          index: reversedIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
        setState(() => _highlightedMessageId = messageId);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _highlightedMessageId = null);
        });
      } catch (e) {
        print('Error scrolling to message: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textFieldFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chat == null || !_initialLoadDone) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = widget.currentUser;
    final bool hasWritePermission = !_isReadOnly && _chat!.canWrite(user);

    return Scaffold(
      appBar: AppBar(
        title: Text(_chatName),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Provider.value(
        value: _userCache,
        child: Stack(
          children: [
            // Contenido principal
            Column(
              children: [
                Expanded(
                  child:
                      _messages.isEmpty
                          ? const Center(
                            child: Text('No hay mensajes disponibles'),
                          )
                          : ScrollablePositionedList.builder(
                            key: const PageStorageKey('json-chat-list'),
                            itemScrollController: _itemScrollController,
                            itemPositionsListener: _itemPositionsListener,
                            itemCount: _messages.length,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            addAutomaticKeepAlives: false,
                            minCacheExtent: 2000,
                            itemBuilder: (context, index) {
                              final actualIndex = _messages.length - 1 - index;
                              final msg = _messages[actualIndex];
                              final msgId = msg.id!;

                              // Verificar si este mensaje es consecutivo
                              final isConsecutive =
                                  actualIndex > 0 &&
                                  _messages[actualIndex].sender ==
                                      _messages[actualIndex - 1].sender;

                              // Obtener mensaje citado si está disponible
                              Message? quoted;
                              if (msg.data?.resend != null) {
                                quoted =
                                    _quotedCache[msg.data!.resend!
                                        .toHexString()];
                              }

                              return MessageBubble(
                                key: ValueKey(msgId),
                                centered: true,
                                msg: msg,
                                me: user?.id ?? ObjectId(),
                                user:
                                    msg.sender != null
                                        ? _userCache[msg.sender!.toHexString()]
                                        : null,
                                quoted: quoted,
                                isConsecutive: isConsecutive,
                                isHighlighted: _highlightedMessageId == msgId,
                                onQuotedTap: scrollToMessage,
                                onReply: (_) {}, // No permitir respuestas
                                onShowSnackbar: _showSnackbar,
                                onQuickReply:
                                    (
                                      _,
                                      __,
                                    ) {}, // No permitir respuestas rápidas
                              );
                            },
                          ),
                ),
                _buildMessageInput(hasWritePermission),
              ],
            ),

            // Botón para desplazarse hacia abajo
            Positioned(
              right: 16,
              bottom: 80,
              child: AnimatedOpacity(
                opacity: _showScrollButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child:
                    _showScrollButton
                        ? FloatingActionButton(
                          mini: true,
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          onPressed: _scrollToBottom,
                          child: const Icon(Icons.keyboard_arrow_down),
                        )
                        : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(bool hasWritePermission) {
    // Siempre mostrar un mensaje de solo lectura para canales de noticias
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign,
            color: Theme.of(context).colorScheme.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Canal de noticias - Solo lectura',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }
}
