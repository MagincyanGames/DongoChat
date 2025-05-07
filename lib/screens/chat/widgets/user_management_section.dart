import 'package:flutter/material.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class UserManagementSection extends StatefulWidget {
  final Set<ObjectId> initialAdmins;
  final Set<ObjectId> initialReadWrite;
  final Set<ObjectId> initialReadOnly;
  final User? currentUser;

  const UserManagementSection({
    Key? key,
    required this.initialAdmins,
    required this.initialReadWrite,
    required this.initialReadOnly,
    required this.currentUser,
  }) : super(key: key);

  @override
  UserManagementSectionState createState() => UserManagementSectionState();
}

class UserManagementSectionState extends State<UserManagementSection> {
  List<User> allUsers = [];
  bool isLoading = true;
  String searchQuery = '';
  
  final Set<ObjectId> adminUsers = {};
  final Set<ObjectId> readWriteUsers = {};
  final Set<ObjectId> readOnlyUsers = {};
  
  @override
  void initState() {
    super.initState();
    
    // Copy the initial selections
    adminUsers.addAll(widget.initialAdmins);
    readWriteUsers.addAll(widget.initialReadWrite);
    readOnlyUsers.addAll(widget.initialReadOnly);
    
    // Load all users
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final users = await DBManagers.user.getAll();
      setState(() {
        allUsers = users;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando usuarios: ${e.toString()}')),
        );
      }
    }
  }

  List<User> get filteredUsers {
    if (searchQuery.isEmpty) {
      return allUsers;
    }
    final query = searchQuery.toLowerCase();
    return allUsers.where((user) {
      return user.displayName.toLowerCase().contains(query) ||
             user.username.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gestión de usuarios:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        
        TextField(
          decoration: InputDecoration(
            hintText: 'Buscar usuarios...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
        ),
        
        const SizedBox(height: 8),
        
        // User list with fixed height to avoid layout issues
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildUserList(filteredUsers),
        ),
      ],
    );
  }
  
  Widget _buildUserList(List<User> users) {
    final theme = Theme.of(context);
    
    if (users.isEmpty) {
      return Center(
        child: Text(
          'No hay usuarios disponibles',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: users.length,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final user = users[index];
        
        // Skip the current user in the list
        if (user.id == widget.currentUser?.id) {
          return const SizedBox.shrink();
        }
        
        // Determine the current role
        final isAdmin = adminUsers.contains(user.id);
        final isReadWrite = readWriteUsers.contains(user.id);
        final isReadOnly = readOnlyUsers.contains(user.id);
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // First line: User information
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(user.color ?? 0xFF9E9E9E),
                    radius: 16,
                    child: Text(
                      user.displayName.isNotEmpty 
                        ? user.displayName[0].toUpperCase() 
                        : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                padding: const EdgeInsets.only(left: 44.0, top: 8.0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    // Admin role chip
                    FilterChip(
                      label: Text('Admin'),
                      selected: isAdmin,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            adminUsers.add(user.id!);
                            readWriteUsers.remove(user.id);
                            readOnlyUsers.remove(user.id);
                          } else {
                            adminUsers.remove(user.id);
                          }
                        });
                      },
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      selectedColor: Colors.amber,
                      labelStyle: TextStyle(
                        color: isAdmin ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    
                    // Read-write role chip
                    FilterChip(
                      label: Text('Lector/Editor'),
                      selected: isReadWrite,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            readWriteUsers.add(user.id!);
                            adminUsers.remove(user.id);
                            readOnlyUsers.remove(user.id);
                          } else {
                            readWriteUsers.remove(user.id);
                          }
                        });
                      },
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      selectedColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isReadWrite ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    
                    // Read-only role chip  
                    FilterChip(
                      label: Text('Solo lectura'),
                      selected: isReadOnly,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            readOnlyUsers.add(user.id!);
                            adminUsers.remove(user.id);
                            readWriteUsers.remove(user.id);
                          } else {
                            readOnlyUsers.remove(user.id);
                          }
                        });
                      },
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      selectedColor: theme.colorScheme.secondary,
                      labelStyle: TextStyle(
                        color: isReadOnly ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
              Divider(),
            ],
          ),
        );
      },
    );
  }
}