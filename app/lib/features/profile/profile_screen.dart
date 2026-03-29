import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../auth/auth_provider.dart';
import '../chat/chat_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final voiceEnabled = ref.watch(voiceEnabledProvider);
    final roleAsync = ref.watch(userRoleProvider);

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Profile header ---
            _ProfileHeader(user: user),

            const SizedBox(height: 32),

            // --- Role badge ---
            roleAsync.when(
              data: (role) => role != null
                  ? _RoleBadge(role: role)
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // --- Settings card ---
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    // Voice responses toggle
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: voiceEnabled
                              ? AppTheme.amber.withOpacity(0.12)
                              : AppTheme.navyDeep.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          voiceEnabled
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: voiceEnabled
                              ? AppTheme.amber
                              : AppTheme.textLight,
                        ),
                      ),
                      title: const Text('Voice Responses'),
                      subtitle: Text(
                        voiceEnabled
                            ? 'Kevin will speak his replies aloud.'
                            : 'Kevin\'s replies are text only.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      value: voiceEnabled,
                      activeColor: AppTheme.amber,
                      onChanged: (val) {
                        ref.read(voiceEnabledProvider.notifier).state = val;
                      },
                    ),

                    const Divider(indent: 72, endIndent: 16),

                    // Clear conversation history
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.navyDeep.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.restart_alt_rounded,
                          color: AppTheme.navyDeep,
                        ),
                      ),
                      title: const Text('New Conversation'),
                      subtitle: Text(
                        'Start fresh with Kevin.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ref
                            .read(conversationProvider.notifier)
                            .startNewConversation();
                        context.go('/home');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Conversation cleared.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- About card ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About Kevin',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This app was built with love to keep Kevin Yancy\'s '
                      'voice, stories, and spirit alive for the family and '
                      'friends who miss him. It uses AI to let you have '
                      'conversations grounded in his real memories and words.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // --- Sign out ---
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(loginProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            // App version
            Text(
              'Version 1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textLight,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile header widget
// ---------------------------------------------------------------------------
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final User? user;

  @override
  Widget build(BuildContext context) {
    final email = user?.email ?? '';
    final displayName = user?.displayName ?? email.split('@').first;
    final initials = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '?';

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.navyDeep,
            boxShadow: [
              BoxShadow(
                color: AppTheme.navyDeep.withOpacity(0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Role badge
// ---------------------------------------------------------------------------
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  Color get _color {
    switch (role) {
      case UserRole.admin:
        return Colors.red.shade700;
      case UserRole.delegate:
        return AppTheme.amber;
      default:
        return AppTheme.navyDeep;
    }
  }

  IconData get _icon {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings_outlined;
      case UserRole.delegate:
        return Icons.supervisor_account_outlined;
      default:
        return Icons.family_restroom_outlined;
    }
  }

  String get _label {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.delegate:
        return 'Delegate';
      default:
        return 'Family Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, color: _color, size: 18),
            const SizedBox(width: 8),
            Text(
              _label,
              style: TextStyle(
                color: _color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
