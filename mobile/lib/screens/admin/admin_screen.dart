import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import 'admin_badges_settings_tab.dart';
import 'admin_reports_tab.dart';
import 'admin_users_tab.dart';

/// Home screen for administrator accounts: Users, Reports, Badges & Settings.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: GalaxyColors.surface,
        title: const Text('Log out?', style: TextStyle(color: GalaxyColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: GalaxyColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded,
                          color: GalaxyColors.gold, size: 26),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin',
                            style: TextStyle(
                              color: GalaxyColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Manage AralPet',
                            style: TextStyle(color: GalaxyColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Profile',
                      onPressed: () => context.push('/profile'),
                      icon: const Icon(Icons.person_rounded, color: GalaxyColors.textPrimary),
                    ),
                    IconButton(
                      tooltip: 'Log out',
                      onPressed: () => _logout(context, ref),
                      icon: const Icon(Icons.logout_rounded, color: GalaxyColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const TabBar(
                indicatorColor: GalaxyColors.purple,
                labelColor: GalaxyColors.textPrimary,
                unselectedLabelColor: GalaxyColors.textSecondary,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(icon: Icon(Icons.people_alt_rounded), text: 'Users'),
                  Tab(icon: Icon(Icons.insights_rounded), text: 'Reports'),
                  Tab(icon: Icon(Icons.tune_rounded), text: 'Badges & XP'),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    AdminUsersTab(),
                    AdminReportsTab(),
                    AdminBadgesSettingsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
