import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:provider/provider.dart';
import 'package:dongo_chat/models/chat.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/providers/UserProvider.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/theme/chat_theme.dart';

class ChatEditDialog extends StatefulWidget {
  final ChatSummary chat;
  final List<ChatSummary> existingChats;
  final Function(ObjectId, String, String, ChatSummary) onSave;

  const ChatEditDialog({
    Key? key,
    required this.chat,
    required this.existingChats,
    required this.onSave,
  }) : super(key: key);

  @override
  _ChatEditDialogState createState() => _ChatEditDialogState();
  
  static Future<void> show({
    required BuildContext context,
    required ChatSummary chat,
    required List<ChatSummary> existingChats,
    required Function(ObjectId, String, String, ChatSummary) onSave,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return ChatEditDialog(
          chat: chat,
          existingChats: existingChats,
          onSave: onSave,
        );
      },
    );
  }
}

class _ChatEditDialogState extends State<ChatEditDialog> {
  late TextEditingController _nameController;
  late String _privacity;
  late Set<ObjectId> _adminUsers;
  late Set<ObjectId> _readWriteUsers;
  late Set<ObjectId> _readOnlyUsers;
  
  List<User> _allUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _formKey = GlobalKey<FormState>();
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.chat.name);
    _privacity = widget.chat.privacity ?? 'private';
    _adminUsers = Set<ObjectId>.from(widget.chat.adminUsers);
    _readWriteUsers = Set<ObjectId>.from(widget.chat.readWriteUsers);
    _readOnlyUsers = Set<ObjectId>.from(widget.chat.readOnlyUsers);
    _loadUsers();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final users = await DBManagers.user.getAll();
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando usuarios: ${e.toString()}')),
        );
      }
    }
  }
  
  List<User> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _allUsers;
    }
    final query = _searchQuery.toLowerCase();
    return _allUsers.where((user) {
      return user.displayName.toLowerCase().contains(query) ||
             user.username.toLowerCase().contains(query);
    }).toList();
  }
  
  void _toggleUserRole(User user, String role) {
    setState(() {
      if (role == 'admin') {
        if (_adminUsers.contains(user.id)) {
          _adminUsers.remove(user.id);
        } else {
          _adminUsers.add(user.id!);
          _readWriteUsers.remove(user.id);
          _readOnlyUsers.remove(user.id);
        }
      } else if (role == 'readWrite') {
        if (_readWriteUsers.contains(user.id)) {
          _readWriteUsers.remove(user.id);
        } else {
          _readWriteUsers.add(user.id!);
          _adminUsers.remove(user.id);
          _readOnlyUsers.remove(user.id);
        }
      } else if (role == 'readOnly') {
        if (_readOnlyUsers.contains(user.id)) {
          _readOnlyUsers.remove(user.id);
        } else {
          _readOnlyUsers.add(user.id!);
          _adminUsers.remove(user.id);
          _readWriteUsers.remove(user.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = Provider.of<UserProvider>(context).user;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Editar Chat',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name field
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del Chat',
                            hintText: 'Ej. soporte, proyectos, general',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor ingresa un nombre válido';
                            }
                            final normalizedName = value
                                .trim()
                                .toLowerCase()
                                .replaceAll(' ', '-');
                            
                            final exists = widget.existingChats.any(
                              (c) => c.name.toLowerCase() == normalizedName && 
                                   c.id != widget.chat.id,
                            );

                            if (exists) {
                              return 'Ya existe un chat con ese nombre';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Privacy options
                        const Text(
                          'Privacidad:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        
                        RadioListTile<String>(
                          title: const Text('Privado'),
                          subtitle: const Text('Solo usuarios invitados pueden acceder'),
                          value: 'private',
                          groupValue: _privacity,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _privacity = value);
                            }
                          },
                        ),
                        
                        RadioListTile<String>(
                          title: const Text('Público'),
                          subtitle: const Text('Cualquiera puede leer y escribir'),
                          value: 'public',
                          groupValue: _privacity,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _privacity = value);
                            }
                          },
                        ),
                        
                        RadioListTile<String>(
                          title: const Text('Público (solo lectura)'),
                          subtitle: const Text(
                            'Cualquiera puede leer, solo usuarios invitados pueden escribir',
                          ),
                          value: 'publicReadOnly',
                          groupValue: _privacity,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _privacity = value);
                            }
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // User management section
                        const Text(
                          'Gestión de usuarios:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        
                        // Search field
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar usuarios...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Users list with fixed height
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                itemCount: _filteredUsers.length,
                                padding: const EdgeInsets.all(0),
                                itemBuilder: (context, index) {
                                  final user = _filteredUsers[index];
                                  
                                  // Skip current user as they're already admin
                                  if (user.id == currentUser?.id) {
                                    return const SizedBox.shrink();
                                  }
                                  
                                  final isAdmin = _adminUsers.contains(user.id);
                                  final isReadWrite = _readWriteUsers.contains(user.id);
                                  final isReadOnly = _readOnlyUsers.contains(user.id);
                                  
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // First line: User information
                                        Row(
                                          children: [
                                            // CircleAvatar(
                                            //   backgroundColor: Color(user.color),
                                            //   child: Text(
                                            //     user.displayName.isNotEmpty 
                                            //       ? user.displayName[0].toUpperCase() 
                                            //       : '?',
                                            //     style: TextStyle(
                                            //       color: theme.colorScheme.onPrimary,
                                            //     ),
                                            //   ),
                                            // ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user.displayName,
                                                    style: theme.textTheme.titleMedium,
                                                  ),
                                                  Text(
                                                    '@${user.username}',
                                                    style: theme.textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        // Second line: Permission buttons
                                        Padding(
                                          padding: const EdgeInsets.only(left: 48.0, top: 8.0),
                                          child: Wrap(
                                            spacing: 8,
                                            children: [
                                              ChoiceChip(
                                                label: const Text('Admin'),
                                                selected: isAdmin,
                                                onSelected: (selected) => _toggleUserRole(user, 'admin'),
                                              ),
                                              ChoiceChip(
                                                label: const Text('Lector/Editor'),
                                                selected: isReadWrite,
                                                onSelected: (selected) => _toggleUserRole(user, 'readWrite'),
                                              ),
                                              ChoiceChip(
                                                label: const Text('Solo lectura'),
                                                selected: isReadOnly,
                                                onSelected: (selected) => _toggleUserRole(user, 'readOnly'),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Divider(),
                                      ],
                                    ),
                                  );
                                },
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final chatName = _nameController.text
                            .trim()
                            .toLowerCase()
                            .replaceAll(' ', '-');
                        
                        // Create updated chat summary
                        final updatedChat = ChatSummary(
                          id: widget.chat.id,
                          name: chatName,
                          latestMessage: widget.chat.latestMessage,
                          latestUpdated: widget.chat.latestUpdated,
                          readOnlyUsers: _readOnlyUsers.toList(),
                          readWriteUsers: _readWriteUsers.toList(),
                          adminUsers: _adminUsers.toList(),
                          privacity: _privacity,
                          messageCount: widget.chat.messageCount,
                        );
                        
                        // Call save callback
                        widget.onSave(
                          widget.chat.id, 
                          chatName, 
                          _privacity, 
                          updatedChat
                        );
                        
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}