import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../auth/auth_provider.dart';
import 'add_memory_screen.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
    final isAdminOrDelegate =
        ref.watch(isAdminOrDelegateProvider).valueOrNull ?? false;

    if (!isAdminOrDelegate) {
      return Scaffold(
        backgroundColor: AppTheme.cream,
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(
          child: Text('Access denied. You must be an admin or delegate.'),
        ),
      );
    }

    return DefaultTabController(
      length: isAdmin ? 3 : 2,
      child: Scaffold(
        backgroundColor: AppTheme.cream,
        appBar: AppBar(
          title: const Text('Admin Panel'),
          actions: [
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Go to chat',
              onPressed: () => context.go('/home'),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.memory_outlined), text: 'Memories'),
              const Tab(icon: Icon(Icons.people_outline), text: 'Users'),
              if (isAdmin)
                const Tab(
                    icon: Icon(Icons.admin_panel_settings_outlined),
                    text: 'Roles'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MemoriesTab(isAdmin: isAdmin),
            _UsersTab(isAdmin: isAdmin),
            if (isAdmin) const _RolesTab(),
          ],
        ),
        floatingActionButton: isAdmin
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddMemoryScreen()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Memory'),
              )
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Memories Tab
// ---------------------------------------------------------------------------
class _MemoriesTab extends ConsumerWidget {
  const _MemoriesTab({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(Collections.memories)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.library_books_outlined,
                    size: 56, color: AppTheme.textLight),
                const SizedBox(height: 16),
                Text('No memories yet.',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text('Tap the + button to add Kevin\'s first memory.'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final type = data['type'] as String? ?? 'unknown';
            final content = data['content'] as String? ?? '';
            final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                leading: _MemoryTypeIcon(type: type),
                title: Text(
                  type == MemoryType.qa
                      ? (metadata['question'] as String? ?? content)
                      : content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _typeLabel(type),
                    style: TextStyle(
                      color: AppTheme.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                trailing: isAdmin
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        onPressed: () => _confirmDelete(
                            context, docs[i].id),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case MemoryType.journal:
        return 'Journal Entry';
      case MemoryType.qa:
        return 'Q&A Pair';
      case MemoryType.photo:
        return 'Photo Memory';
      case MemoryType.voice:
        return 'Voice Clip';
      default:
        return type;
    }
  }

  Future<void> _confirmDelete(BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Memory'),
        content: const Text(
            'This will remove the memory from Firestore. '
            'You may also need to remove it from Pinecone manually.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection(Collections.memories)
          .doc(docId)
          .delete();
    }
  }
}

class _MemoryTypeIcon extends StatelessWidget {
  const _MemoryTypeIcon({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (type) {
      case MemoryType.journal:
        icon = Icons.book_outlined;
        color = AppTheme.navyDeep;
        break;
      case MemoryType.qa:
        icon = Icons.question_answer_outlined;
        color = AppTheme.amber;
        break;
      case MemoryType.photo:
        icon = Icons.photo_outlined;
        color = Colors.teal;
        break;
      case MemoryType.voice:
        icon = Icons.mic_outlined;
        color = Colors.purple;
        break;
      default:
        icon = Icons.star_outline;
        color = AppTheme.textLight;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

// ---------------------------------------------------------------------------
// Users Tab — Invite users
// ---------------------------------------------------------------------------
class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab({required this.isAdmin});
  final bool isAdmin;

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedRole = 'family';
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _inviteUser() async {
    if (_emailController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      // Force token refresh so custom claims (role) are included
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in.');
      await user.getIdToken(true);

      final callable = FirebaseFunctions.instance
          .httpsCallable(FunctionNames.inviteUser);
      final result = await callable.call({
        'email': _emailController.text.trim(),
        'displayName': _nameController.text.trim(),
        'assignedRole': _selectedRole,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result.data['message'] as String? ?? 'Invite sent.')),
        );
        _emailController.clear();
        _nameController.clear();
        setState(() => _selectedRole = 'family');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Invite Someone',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Send an invitation to a family member or friend.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'family', child: Text('Family')),
              DropdownMenuItem(value: 'delegate', child: Text('Delegate (can invite others)')),
              if (true) // Show admin option only to admins — checked server-side
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (v) => setState(() => _selectedRole = v ?? 'family'),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _inviteUser,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Send Invite'),
          ),

          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 16),

          Text('Family Members',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(Collections.users)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Text('Error loading members: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text('No members yet.',
                    style: Theme.of(context).textTheme.bodyMedium);
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = data['role'] as String? ?? 'family';
                  final name = data['displayName'] as String?;
                  final email = data['email'] as String? ?? '';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: role == 'admin'
                          ? AppTheme.navyDeep
                          : role == 'delegate'
                              ? AppTheme.amber
                              : Colors.teal,
                      child: Text(
                        (name?.isNotEmpty == true ? name! : email)
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(name?.isNotEmpty == true ? name! : email),
                    subtitle: Text(email != (name ?? '') ? email : ''),
                    trailing: Chip(
                      label: Text(role,
                          style: const TextStyle(fontSize: 11, color: Colors.white)),
                      backgroundColor: role == 'admin'
                          ? AppTheme.navyDeep
                          : role == 'delegate'
                              ? AppTheme.amber
                              : Colors.teal,
                      padding: EdgeInsets.zero,
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          Text('Pending Invites',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(Collections.invites)
                .where('status', isEqualTo: 'pending')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 12));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text('No pending invites.',
                    style: Theme.of(context).textTheme.bodyMedium);
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['displayName'] as String?;
                  final email = data['email'] as String? ?? '';
                  final role = data['assignedRole'] as String? ?? 'family';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mark_email_unread_outlined, color: Colors.orange),
                    title: Text(name?.isNotEmpty == true ? name! : email),
                    subtitle: Text('$email • $role'),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Roles Tab — Manage user roles (admin only)
// ---------------------------------------------------------------------------
class _RolesTab extends ConsumerStatefulWidget {
  const _RolesTab();

  @override
  ConsumerState<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends ConsumerState<_RolesTab> {
  final _uidController = TextEditingController();
  String _selectedRole = 'family';
  bool _isLoading = false;

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _updateRole() async {
    if (_uidController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable(FunctionNames.updateUserRole);
      final result = await callable.call({
        'targetUid': _uidController.text.trim(),
        'role': _selectedRole,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result.data['message'] as String? ?? 'Role updated.')),
        );
        _uidController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Update User Role',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Enter a user\'s Firebase UID and select their new role. '
            'This sets custom claims — the user will need to sign out and back in.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _uidController,
            decoration: const InputDecoration(
              labelText: 'User UID',
              hintText: 'Firebase Auth UID',
              prefixIcon: Icon(Icons.fingerprint_outlined),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'New Role',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'family', child: Text('Family')),
              DropdownMenuItem(
                  value: 'delegate',
                  child: Text('Delegate')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (v) => setState(() => _selectedRole = v ?? 'family'),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _updateRole,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.security_outlined),
            label: const Text('Update Role'),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.amber.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppTheme.amber, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'To find a user\'s UID: go to Firebase Console → '
                    'Authentication → Users → copy the UID column.',
                    style: TextStyle(
                        color: AppTheme.navyDeep.withOpacity(0.8),
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
