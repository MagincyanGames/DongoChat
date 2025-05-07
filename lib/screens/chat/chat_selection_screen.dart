import 'dart:async'; // Add timer import
import 'dart:convert';

import 'package:bson/src/classes/object_id.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/main.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/providers/user_cache_provider.dart';
import 'package:dongo_chat/screens/chat/widgets/chat_selection.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:dongo_chat/widgets/app_bar.dart';
import 'package:dongo_chat/widgets/buttons/appbar/debug_button.dart';
import 'package:dongo_chat/widgets/buttons/appbar/theme_toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:provider/provider.dart';

// Polling interval in seconds - can be adjusted as needed
const int POLLING_INTERVAL_SECONDS = 5;

class ChatSelectionScreen extends StatefulWidget {
  const ChatSelectionScreen({super.key});

  @override
  State<StatefulWidget> createState() => _ChatSelectionScreenState();
}

class _ChatSelectionScreenState extends State<ChatSelectionScreen> {
  List<ChatSummary>? _chatSummaries;
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // Initial load of chat summaries
    _loadChatSummaries().then((n) {
      _checkForUpdates();
    });

    // Set up periodic polling
    _pollingTimer = Timer.periodic(
      Duration(seconds: POLLING_INTERVAL_SECONDS),
      (_) => _checkForUpdates(),
    );
  }

  @override
  void dispose() {
    // Cancel timer when widget is disposed
    _pollingTimer?.cancel();
    super.dispose();
  }

  // Load all chat summaries from server
  Future<void> _loadChatSummaries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final summaries = await DBManagers.chat.getChatSummaries();

      if (mounted) {
        setState(() {
          _chatSummaries = summaries;
          _isLoading = false;
        });

        // Prefetch de usuarios después de cargar los resúmenes
        await _prefetchUserData();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chats: ${error.toString()}')),
        );
      }
    }
  }

  // Check for updates by sending current summaries to server
  Future<void> _checkForUpdates() async {
    print('Checking for updates...');
    if (_chatSummaries == null || !mounted) return;
    try {
      // Convert summaries to the format expected by the server
      final currentSummaries =
          _chatSummaries!
              .map(
                (summary) => {
                  '_id': summary.id?.toHexString(),
                  'name': summary.name,
                  'latestMessage':
                      summary.latestMessage != null
                          ? {
                            'timestamp':
                                summary
                                    .latestMessage!
                                    .timestamp!
                                    .millisecondsSinceEpoch,
                            // Convert DateTime to milliseconds since epoch for proper serialization
                          }
                          : null,
                  'messageCount': summary.messageCount ?? 0,
                  'privacity': summary.privacity,
                },
              )
              .toList();

      // Send current summaries to server to check for updates
      final response = await DBManagers.chat.checkForSummariesUpdates(
        currentSummaries,
      );

      // Process the update response
      if (mounted) {
        bool hasChanges = false;

        // Handle new chats
        if (response['updates']['new']?.isNotEmpty == true) {
          final newChats =
              (response['updates']['new'] as List)
                  .map((chatData) => ChatSummary.fromMap(chatData))
                  .toList();

          if (newChats.isNotEmpty) {
            setState(() {
              _chatSummaries = [...?_chatSummaries, ...newChats];
            });
            hasChanges = true;
          }
        }

        // Handle updated chats
        if (response['updates']['updated']?.isNotEmpty == true) {
          final updatedChats =
              (response['updates']['updated'] as List)
                  .map((chatData) => ChatSummary.fromMap(chatData))
                  .toList();

          if (updatedChats.isNotEmpty) {
            setState(() {
              // Replace existing chats with updated versions
              for (var updatedChat in updatedChats) {
                int existingIndex = _chatSummaries!.indexWhere(
                  (chat) =>
                      chat.id?.toHexString() == updatedChat.id?.toHexString(),
                );

                if (existingIndex >= 0) {
                  _chatSummaries![existingIndex] = updatedChat;
                }
              }
            });
            hasChanges = true;
          }
        }

        // Handle deleted chats
        if (response['updates']['deleted']?.isNotEmpty == true) {
          final deletedChatIds = response['updates']['deleted'] as List;

          if (deletedChatIds.isNotEmpty) {
            setState(() {
              _chatSummaries!.removeWhere(
                (chat) => deletedChatIds.contains(chat.id?.toHexString()),
              );
            });
            hasChanges = true;
          }
        }

        // Re-sort chats if needed
        if (hasChanges) {
          setState(() {
            _chatSummaries!.sort((a, b) {
              final int aTime =
                  a.latestMessage?.timestamp?.millisecondsSinceEpoch ?? 0;
              final int bTime =
                  b.latestMessage?.timestamp?.millisecondsSinceEpoch ?? 0;
              return bTime.compareTo(aTime); // Most recent first
            });
          });
        }

        // Prefetch user data after updates
        if (hasChanges && mounted) {
          await _prefetchUserData();
        }
      }
    } catch (error) {
      print('Error checking for updates: $error');
      // Don't show UI error on background updates to avoid disruption
    }
  }

  Future<void> _prefetchUserData() async {
    if (_chatSummaries == null || _chatSummaries!.isEmpty) return;

    final userCache = Provider.of<UserCacheProvider>(context, listen: false);
    final Set<ObjectId> userIdsToFetch = {};

    // Recolectar todos los IDs de usuarios de los últimos mensajes
    for (var chatSummary in _chatSummaries!) {
      if (chatSummary.latestMessage?.sender != null) {
        userIdsToFetch.add(chatSummary.latestMessage!.sender!);
      }
    }

    // Obtener los usuarios que no están en caché
    for (var userId in userIdsToFetch) {
      if (userCache.getUser(userId) == null) {
        try {
          final user = await DBManagers.user.Get(userId);
          if (user != null) {
            userCache.cacheUser(user);
          }
        } catch (e) {
          print('Error fetching user $userId: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detectamos si estamos en la ruta /chat
    final isChatRoute = ModalRoute.of(context)?.settings.name == '/chat';
    final screenHeight = MediaQuery.of(context).size.height;

    Widget body;

    final theme = Theme.of(context);
    final chatTheme = theme.extension<ChatTheme>();

    if (_isLoading) {
      body = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else {
      body = Container(
        key: const ValueKey('selector'),
        width: MediaQuery.of(context).size.width,
        height: screenHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              chatTheme?.otherMessageGradient.last ?? Colors.blue.shade900,
              chatTheme?.myMessageGradient.first ?? Colors.deepPurple.shade900,
            ],
          ).withOpacity(0.1),
        ),
        child: ChatSelection(
          chatSummaries: _chatSummaries ?? [],
          onChatSelected: _onChatSelected,
          onCreateChat: _onCreateChat,
          onDeleteChat: _onDeleteChat,
          onEditChat: _onEditChat, // Add this line
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'DongoChat v$appVersion',
        actions: [ThemeToggleButton(), DebugButton()],
        context: context,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SizedBox.expand(
              child: Image.asset(
                'assets/ajolote contrast.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                opacity: const AlwaysStoppedAnimation(0.1),
                colorBlendMode: BlendMode.multiply,
              ),
            ),
          ),
          body,
          RefreshIndicator(onRefresh: _loadChatSummaries, child: body),
        ],
      ),
    );
  }

  void _onChatSelected(ChatSummary value) {
    Navigator.pushNamed(context, '/chat', arguments: {'chat': value});
  }

  void _onCreateChat(String name, String privacity) {
    final user = context.read<UserProvider>().user;
    final chat = Chat(name: name, privacity: privacity);
    if (user != null && user.id != null) {
      chat.adminUsers.add(user.id!);
    }

    DBManagers.chat
        .Post(chat)
        .then((_chat) {
          if (mounted) {
            if (_chat != null) {
              Navigator.pushNamed(
                context,
                '/chat',
                arguments: {'chat': _chat.summary},
              );

              // Refresh chat list after creating new chat
              _loadChatSummaries();
            }
          }
        })
        .catchError((error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error creating chat: ${error.toString()}'),
              ),
            );
          }
        });
  }

  void _onDeleteChat(ObjectId id) {
    // Implement delete functionality
    DBManagers.chat
        .Delete(id)
        .then((_) {
          if (mounted) {
            // Refresh chat list after deletion
            _loadChatSummaries();
          }
        })
        .catchError((error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting chat: ${error.toString()}'),
              ),
            );
          }
        });
  }

  void _onEditChat(ObjectId id, String name, String privacity, ChatSummary updatedChat) {
    setState(() {
      _isLoading = true;
    });

    // Prepare update data including user lists
    final updateData = {
      'name': name, 
      'privacity': privacity,
      'adminUsers': updatedChat.adminUsers.map((id) => id.toHexString()).toList(),
      'readWriteUsers': updatedChat.readWriteUsers.map((id) => id.toHexString()).toList(),
      'readOnlyUsers': updatedChat.readOnlyUsers.map((id) => id.toHexString()).toList(),
    };

    DBManagers.chat
      .updateChat(id, updateData)
      .then((updatedChat) {
        if (mounted) {
          // Refresh chat list after updating
          _loadChatSummaries();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chat actualizado correctamente')),
          );
        }
      })
      .catchError((error) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error actualizando chat: ${error.toString()}'),
            ),
          );
        }
      });
  }
}
