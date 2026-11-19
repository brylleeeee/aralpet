import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../models/admin.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/galaxy_page.dart';

class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  Timer? _debounce;

  String? _status; // null = all, 'active', 'inactive'
  final List<AdminUser> _users = [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = false;
  String? _error;
  final Set<int> _updating = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await ref.read(adminRepositoryProvider).fetchUsers(
            search: _search.text,
            status: _status,
            page: reset ? 1 : _page + 1,
          );
      if (!mounted) return;
      setState(() {
        if (reset) _users.clear();
        _users.addAll(page.users);
        _page = page.currentPage;
        _lastPage = page.lastPage;
        _total = page.total;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load users.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  Future<void> _toggle(AdminUser user, bool active) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: GalaxyColors.surface,
          title: Text(
            'Deactivate ${user.name}?',
            style: const TextStyle(color: GalaxyColors.textPrimary),
          ),
          content: const Text(
            'They will be signed out right away and cannot log in until you activate the account again.',
            style: TextStyle(color: GalaxyColors.textSecondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _updating.add(user.id));
    try {
      final updated = await ref.read(adminRepositoryProvider).setActive(user.id, active);
      if (!mounted) return;
      setState(() {
        final i = _users.indexWhere((u) => u.id == user.id);
        if (i >= 0) _users[i] = updated;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _updating.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      color: GalaxyColors.purple,
      backgroundColor: GalaxyColors.surface,
      onRefresh: () => _load(reset: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search by name or email',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in const {null: 'All', 'active': 'Active', 'inactive': 'Inactive'}.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _status == entry.key,
                  onSelected: (_) {
                    setState(() => _status = entry.key);
                    _load(reset: true);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$_total ${_total == 1 ? 'account' : 'accounts'}',
            style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            GalaxyError(message: _error!, onRetry: () => _load(reset: true))
          else if (_users.isEmpty && _loading)
            galaxyLoading
          else if (_users.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text(
                'No accounts match.',
                textAlign: TextAlign.center,
                style: TextStyle(color: GalaxyColors.textSecondary),
              ),
            )
          else ...[
            for (final user in _users) ...[
              _UserTile(
                user: user,
                updating: _updating.contains(user.id),
                onChanged: (value) => _toggle(user, value),
              ),
              const SizedBox(height: 10),
            ],
            if (_page < _lastPage)
              Center(
                child: TextButton(
                  onPressed: _loading ? null : () => _load(),
                  child: Text(_loading ? 'Loading...' : 'Load more'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.updating, required this.onChanged});

  final AdminUser user;
  final bool updating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final details = user.isAdmin
        ? 'Administrator'
        : 'Level ${user.level} · ${user.totalXp} XP · ${user.streakDays}-day streak'
            '${user.lastActiveOn != null ? '\nLast active ${user.lastActiveOn}' : ''}';

    return GalaxyCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: (user.isActive ? GalaxyColors.purple : GalaxyColors.border)
                .withValues(alpha: 0.3),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: const TextStyle(color: GalaxyColors.textPrimary, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(color: GalaxyColors.textPrimary, fontWeight: FontWeight.w800),
                ),
                Text(
                  user.email,
                  style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 11, height: 1.4),
                ),
                if (!user.isActive)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Deactivated',
                      style: TextStyle(color: GalaxyColors.pink, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          if (updating)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (!user.isAdmin)
            Switch(value: user.isActive, onChanged: onChanged),
        ],
      ),
    );
  }
}
