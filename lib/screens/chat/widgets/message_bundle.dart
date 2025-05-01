import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/models/message.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:dongo_chat/utils/time_ago.dart';
import 'package:dongo_chat/screens/chat/widgets/message_context_menu.dart';
import 'dart:io' show Directory, Platform;
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

class MessageBubble extends StatefulWidget {
  final Message msg;
  final ObjectId me;
  final User? user;
  final Message? quoted;
  final bool isConsecutive;
  final bool isHighlighted;
  final Function(ObjectId) onQuotedTap;
  final Function(ObjectId) onReply;
  final Function(String)? onShowSnackbar;

  const MessageBubble({
    Key? key,
    required this.msg,
    required this.me,
    this.user,
    this.quoted,
    this.isConsecutive = false,
    this.isHighlighted = false,
    required this.onQuotedTap,
    required this.onReply,
    this.onShowSnackbar,
  }) : super(key: key);

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  bool get isMe => widget.msg.sender == widget.me;

  void _showContextMenu(BuildContext context, Offset tapPosition) {
    showMessageContextMenu(
      context: context,
      position: tapPosition,
      message: widget.msg,
      isMe: isMe,
      onReply: widget.onReply,
      onShowSnackbar: widget.onShowSnackbar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Create the message content container
    final messageContainer = Container(
      margin: const EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient:
            isMe
                ? LinearGradient(
                  colors:
                      theme.extension<ChatTheme>()?.myMessageGradient ??
                      [Colors.deepPurple, Colors.deepPurple.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                : LinearGradient(
                  colors:
                      theme.extension<ChatTheme>()?.otherMessageGradient ??
                      [Colors.blue.shade900, Colors.blue.shade700],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.quoted != null) _buildQuotedMessage(widget.quoted!, theme),

          // Different display based on message type
          if (widget.msg.data != null &&
              widget.msg.data!.type != null &&
              widget.msg.data!.type! == 'apk')
            // APK message with Android logo wrapped in IntrinsicWidth
            IntrinsicWidth(
              child: GestureDetector(
                onTap: () async {
                  if (_isDownloading)
                    return; // Prevent multiple download attempts
                  if (!Platform.isAndroid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Solo para dispositivos android.',
                        ),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    return;
                  }
                  ;

                  setState(() {
                    _isDownloading = true;
                    _downloadProgress = 0.0;
                  });

                  final url = widget.msg.data!.url as String;

                  // En Android 11+ verificar por ambos permisos
                  bool permissionGranted = false;

                  if (await Permission.storage.request().isGranted) {
                    permissionGranted = true;
                  } else {
                    // Si el primer método falla, intenta con requestInstallPackages
                    if (await Permission.requestInstallPackages
                        .request()
                        .isGranted) {
                      permissionGranted = true;
                    }
                  }

                  if (!permissionGranted) {
                    if (widget.onShowSnackbar != null) {
                      widget.onShowSnackbar!(
                        'Se requiere permiso de almacenamiento para descargar la APK',
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Permiso de almacenamiento denegado. No se puede descargar la APK.',
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                    return;
                  }

                  // 2. Obtener directorio donde guardar la APK
                  final Directory dir =
                      Platform.isAndroid
                          ? (await getExternalStorageDirectory())!
                          : await getApplicationDocumentsDirectory();
                  final String filePath = '${dir.path}/app_downloaded.apk';

                  // 3. Descargar el archivo
                  final dio = Dio();
                  try {
                    await dio.download(
                      url,
                      filePath,
                      onReceiveProgress: (received, total) {
                        if (total != -1) {
                          setState(() {
                            _downloadProgress = received / total;
                          });
                        }
                      },
                    );
                  } catch (e) {
                    setState(() {
                      _isDownloading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al descargar: $e')),
                    );
                    return;
                  }

                  // 4. Lanzar la instalación
                  final result = await OpenFile.open(filePath);
                  // opcional: manejar el resultado de la apertura
                  print('OpenFile result: ${result.message}');

                  setState(() {
                    _isDownloading = false;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        isMe
                            ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.3)
                            : Theme.of(
                              context,
                            ).colorScheme.secondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child:
                      _isDownloading
                          ? _buildDownloadProgress(theme)
                          : _buildApkContent(theme),
                ),
              ),
            )
          else
            // Default text message
            Text(
              widget.msg.message,
              style: TextStyle(
                color:
                    isMe
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSecondary,
              ),
            ),

          if (!widget.isConsecutive) const SizedBox(height: 4),
          Text(
            _getFormattedTime(widget.msg.timestamp!),
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color:
                  isMe
                      ? theme.colorScheme.onPrimary.withOpacity(0.5)
                      : theme.colorScheme.onSecondary.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );

    // Create the full message widget with username if needed
    final messageContent = Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!widget.isConsecutive && widget.user != null)
          Container(
            margin: EdgeInsets.only(left: 8, right: 8, top: 16, bottom: 0),
            padding: EdgeInsets.only(
              left: isMe ? 0 : 10,
              right: isMe ? 10 : 0,
              bottom: 0,
            ),
            child: Text(
              widget.user?.displayName ?? 'Desconocido',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
        // Apply the highlight effect only to the message container
        if (widget.isHighlighted)
          Stack(
            children: [
              // Mensaje original fijo (sin animación)
              messageContainer,
              
              // Efecto de highlight superpuesto que no afecta la posición
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1800),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  final darkValue = (math.sin(value * 2 * math.pi) * 0.5 + 0.5);
                  final rawShadowValue = math.sin(value * 2 * math.pi);
                  final shadowValue = (rawShadowValue.abs() * 0.6) + 0.4;
                  
                  return Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16), // Match message container
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(shadowValue * 0.5),
                            blurRadius: 24 * shadowValue,
                            spreadRadius: 4 * shadowValue,
                          ),
                        ],
                      ),
                      // Overlay oscuro para el efecto de oscurecimiento
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: Colors.black.withOpacity(0.15 * darkValue),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          )
        else
          messageContainer,
      ],
    );

    // Wrap with gesture detector and alignment
    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      onLongPress: () {
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        final tapPosition = Offset(
          position.dx + size.width / 2,
          position.dy + size.height / 2,
        );
        _showContextMenu(context, tapPosition);
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: messageContent,
      ),
    );
  }

  Widget _buildDownloadProgress(ThemeData theme) {
    return SizedBox(
      width: 150,
      child: Column(
        children: [
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: _downloadProgress,
                valueColor: AlwaysStoppedAnimation(
                  isMe
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSecondary,
                ),
                backgroundColor: (isMe
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSecondary)
                    .withOpacity(0.3),
              ),
              Text(
                '${(_downloadProgress * 100).toInt()}%',
                style: TextStyle(
                  color:
                      isMe
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Descargando APK...',
            style: TextStyle(
              color:
                  isMe
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildApkContent(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.android,
          color:
              isMe
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSecondary,
          size: 24,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.msg.message,
                style: TextStyle(
                  color:
                      isMe
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSecondary,
                ),
              ),
              Text(
                Platform.isAndroid
                    ? "Toca para instalar"
                    : "Toca para descargar",
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color:
                      isMe
                          ? theme.colorScheme.onPrimary.withOpacity(0.7)
                          : theme.colorScheme.onSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuotedMessage(Message originalMessage, ThemeData theme) {
    final chatTheme = theme.extension<ChatTheme>();

    return Builder(
      builder: (context) {
        final isMyMessage = originalMessage.sender == widget.me;

        // Choose border and background colors based on who is the author
        final borderColor =
            isMe
                ? chatTheme?.myQuotedMessageBorderColor
                : chatTheme?.otherQuotedMessageBorderColor;

        final backgroundColor =
            isMyMessage
                ? chatTheme?.myQuotedMessageBackgroundColor
                : chatTheme?.otherQuotedMessageBackgroundColor;

        return GestureDetector(
          onTap: () {
            widget.onQuotedTap(originalMessage.id!);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  backgroundColor ??
                  theme.colorScheme.surfaceVariant.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: borderColor ?? theme.colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Provider.of<Map<ObjectId, User>>(
                        context,
                        listen: false,
                      )[originalMessage.sender]?.displayName ??
                      'Desconocido',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: borderColor ?? theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  originalMessage.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        chatTheme?.quotedMessageTextColor ??
                        theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getFormattedTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    // If the message is from today
    if (messageDate.isAtSameMomentAs(today)) {
      return TimeAgo.getTimeAgo(timestamp);
    }
    // If the message is from yesterday or earlier
    else {
      // Format the date and time
      final hours = timestamp.hour.toString().padLeft(2, '0');
      final minutes = timestamp.minute.toString().padLeft(2, '0');

      // If it's from this year, don't show the year
      if (timestamp.year == now.year) {
        return '${timestamp.day}/${timestamp.month} $hours:$minutes';
      } else {
        return '${timestamp.day}/${timestamp.month}/${timestamp.year} $hours:$minutes';
      }
    }
  }
}
