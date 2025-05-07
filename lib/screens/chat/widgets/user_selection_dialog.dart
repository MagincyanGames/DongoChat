import 'package:flutter/material.dart';
import 'package:dongo_chat/models/user.dart';
import 'package:dongo_chat/database/db_managers.dart';
import 'package:dongo_chat/theme/chat_theme.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class UserSelectionDialog extends StatefulWidget {
  final Set<ObjectId> initialAdmins;
  final Set<ObjectId> initialMembers;
  final Set<ObjectId> initialBanned;
  final User currentUser;

  const UserSelectionDialog({
    Key? key,
    required this.initialAdmins,
    required this.initialMembers,
    required this.initialBanned,
    required this.currentUser,
  }) : super(key: key);

  @override
  _UserSelectionDialogState createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<UserSelectionDialog> {
  List<User> allUsers = [];
  bool isLoading = true;
  String searchQuery = '';
  
  final Set<ObjectId> selectedAdmins = {};
  final Set<ObjectId> selectedMembers = {};
  final Set<ObjectId> selectedBanned = {};

  @override
  void initState() {
    super.initState();
    // Copy the initial selections
    selectedAdmins.addAll(widget.initialAdmins);
    selectedMembers.addAll(widget.initialMembers);
    selectedBanned.addAll(widget.initialBanned);
    
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
          SnackBar(content: Text('Error loading users: ${e.toString()}')),
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

  void _toggleUserInList(User user, Set<ObjectId> list, Set<ObjectId> otherList1, Set<ObjectId> otherList2) {
    setState(() {
      if (list.contains(user.id)) {
        list.remove(user.id);
      } else {
        list.add(user.id!);
        // Remove from other lists to ensure a user is only in one list
        otherList1.remove(user.id);
        otherList2.remove(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = theme.extension<ChatTheme>();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Users',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredUsers.isEmpty
                      ? Center(
                          child: Text('No users found', style: theme.textTheme.bodyMedium),
                        )
                      : ListView.builder(
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final isAdmin = selectedAdmins.contains(user.id);
                            final isMember = selectedMembers.contains(user.id);
                            final isBanned = selectedBanned.contains(user.id);
                            
                            // Skip the current user
                            if (user.id == widget.currentUser.id) {
                              return const SizedBox.shrink();
                            }
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Color(user.color),
                                  child: Text(
                                    user.displayName[0].toUpperCase(),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                                title: Text(user.displayName),
                                subtitle: Text('@${user.username}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildRoleChip(
                                      'Admin',
                                      isAdmin,
                                      theme.colorScheme.primary,
                                      () => _toggleUserInList(user, selectedAdmins, selectedMembers, selectedBanned),
                                    ),
                                    const SizedBox(width: 4),
                                    _buildRoleChip(
                                      'Member',
                                      isMember,
                                      theme.colorScheme.secondary,
                                      () => _toggleUserInList(user, selectedMembers, selectedAdmins, selectedBanned),
                                    ),
                                    const SizedBox(width: 4),
                                    _buildRoleChip(
                                      'Banned',
                                      isBanned,
                                      theme.colorScheme.error,
                                      () => _toggleUserInList(user, selectedBanned, selectedAdmins, selectedMembers),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'admins': selectedAdmins,
                      'members': selectedMembers,
                      'banned': selectedBanned,
                    });
                  },
                  child: Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRoleChip(String label, bool isSelected, Color color, VoidCallback onTap) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : null,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      onSelected: (_) => onTap(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}