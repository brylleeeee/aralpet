import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../models/admin.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/galaxy_page.dart';

class AdminBadgesSettingsTab extends ConsumerWidget {
  const AdminBadgesSettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(adminSettingsProvider);
    final badgesAsync = ref.watch(adminBadgesProvider);

    return RefreshIndicator(
      color: GalaxyColors.purple,
      backgroundColor: GalaxyColors.surface,
      onRefresh: () async {
        ref.invalidate(adminSettingsProvider);
        ref.invalidate(adminBadgesProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const _SectionTitle(icon: Icons.bolt_rounded, title: 'XP rules'),
          const SizedBox(height: 4),
          const Text(
            'Changes apply to every student on their next request.',
            style: TextStyle(color: GalaxyColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          settingsAsync.when(
            loading: () => galaxyLoading,
            error: (error, _) => GalaxyError(
              message: error is ApiException ? error.message : 'Could not load the XP rules.',
              onRetry: () => ref.invalidate(adminSettingsProvider),
            ),
            data: (rules) => _SettingsForm(key: ObjectKey(rules), rules: rules),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(icon: Icons.emoji_events_rounded, title: 'Badges'),
              ),
              TextButton.icon(
                onPressed: () => _openBadgeForm(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New badge'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          badgesAsync.when(
            loading: () => galaxyLoading,
            error: (error, _) => GalaxyError(
              message: error is ApiException ? error.message : 'Could not load badges.',
              onRetry: () => ref.invalidate(adminBadgesProvider),
            ),
            data: (badges) => Column(
              children: [
                for (final badge in badges) ...[
                  _BadgeTile(
                    badge: badge,
                    onEdit: () => _openBadgeForm(context, ref, badge: badge),
                    onToggle: (active) => _toggleBadge(context, ref, badge, active),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBadge(BuildContext context, WidgetRef ref, AdminBadge badge, bool active) async {
    try {
      await ref.read(adminRepositoryProvider).saveBadge(badge.toJson(active: active), id: badge.id);
      ref.invalidate(adminBadgesProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _openBadgeForm(BuildContext context, WidgetRef ref, {AdminBadge? badge}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _BadgeForm(badge: badge),
    );
    if (saved == true) ref.invalidate(adminBadgesProvider);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: GalaxyColors.gold, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(color: GalaxyColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

// Number fields for each XP rule, saved together with PUT /admin/settings.
class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.rules});

  final List<XpRule> rules;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final rule in widget.rules) rule.key: TextEditingController(text: '${rule.value}'),
  };
  Map<String, String> _fieldErrors = const {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _fieldErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).saveSettings({
        for (final entry in _controllers.entries) entry.key: int.parse(entry.value.text),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('XP rules saved.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _fieldErrors = e.fieldErrors);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GalaxyCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final rule in widget.rules) ...[
              TextFormField(
                controller: _controllers[rule.key],
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: rule.label,
                  helperText: '${rule.min} to ${rule.max}',
                  errorText: _fieldErrors[rule.key],
                ),
                validator: (value) {
                  final n = int.tryParse(value ?? '');
                  if (n == null || n < rule.min || n > rule.max) {
                    return 'Enter ${rule.min} to ${rule.max}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving...' : 'Save XP Rules'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.onEdit, required this.onToggle});

  final AdminBadge badge;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: badge.isActive ? 1 : 0.6,
      child: GalaxyCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onEdit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.name,
                      style: const TextStyle(color: GalaxyColors.textPrimary, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${conditionLabels[badge.conditionType] ?? badge.conditionType}: ${badge.threshold}',
                      style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 12),
                    ),
                    Text(
                      'Awarded ${badge.awardedCount} ${badge.awardedCount == 1 ? 'time' : 'times'}'
                      '${badge.isActive ? '' : ' · Disabled'}',
                      style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, color: GalaxyColors.textSecondary, size: 20),
            ),
            Switch(value: badge.isActive, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

// Create or edit a badge.
class _BadgeForm extends ConsumerStatefulWidget {
  const _BadgeForm({this.badge});

  final AdminBadge? badge;

  @override
  ConsumerState<_BadgeForm> createState() => _BadgeFormState();
}

class _BadgeFormState extends ConsumerState<_BadgeForm> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.badge?.code ?? '');
  late final _name = TextEditingController(text: widget.badge?.name ?? '');
  late final _description = TextEditingController(text: widget.badge?.description ?? '');
  late final _threshold = TextEditingController(text: '${widget.badge?.threshold ?? 1}');
  late String _condition = widget.badge?.conditionType ?? 'tasks_completed';
  late bool _active = widget.badge?.isActive ?? true;
  Map<String, String> _fieldErrors = const {};
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _description.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _fieldErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).saveBadge({
        'code': _code.text.trim(),
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'condition_type': _condition,
        'threshold': int.parse(_threshold.text),
        'is_active': _active,
      }, id: widget.badge?.id);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _fieldErrors = e.fieldErrors.isEmpty ? {'name': e.message} : e.fieldErrors);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) => (value == null || value.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GalaxyColors.surface,
      title: Text(
        widget.badge == null ? 'New badge' : 'Edit badge',
        style: const TextStyle(color: GalaxyColors.textPrimary, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: 'Name', errorText: _fieldErrors['name']),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _code,
                decoration: InputDecoration(
                  labelText: 'Code',
                  helperText: 'Letters, numbers, - and _ only, e.g. task_legend',
                  errorText: _fieldErrors['code'],
                ),
                validator: (value) {
                  if (_required(value) != null) return 'Required';
                  return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value!.trim())
                      ? null
                      : 'Use letters, numbers, - and _ only';
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: InputDecoration(labelText: 'Description', errorText: _fieldErrors['description']),
                validator: _required,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _condition,
                isExpanded: true,
                dropdownColor: GalaxyColors.surface,
                decoration: const InputDecoration(labelText: 'Earned when'),
                items: [
                  for (final entry in conditionLabels.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) => setState(() => _condition = value ?? _condition),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _threshold,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: 'Reaches at least', errorText: _fieldErrors['threshold']),
                validator: (value) {
                  final n = int.tryParse(value ?? '');
                  return (n == null || n < 1) ? 'Enter 1 or more' : null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                title: const Text('Active', style: TextStyle(color: GalaxyColors.textPrimary)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
