import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_provider.dart';
import '../../widgets/galaxy_page.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _course;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  int? _yearLevel;

  bool _saving = false;
  bool _changePassword = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).value;
    _name = TextEditingController(text: user?.name ?? '');
    _course = TextEditingController(text: user?.course ?? '');
    _yearLevel = user?.yearLevel;
  }

  @override
  void dispose() {
    _name.dispose();
    _course.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await ref.read(authProvider.notifier).updateProfile(
            name: _name.text.trim(),
            course: _course.text,
            yearLevel: _yearLevel,
            currentPassword: _changePassword ? _currentPassword.text : null,
            newPassword: _changePassword ? _newPassword.text : null,
            newPasswordConfirmation: _changePassword ? _confirmPassword.text : null,
          );

      // The dashboard greeting uses the name.
      ref.invalidate(progressProvider);

      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() => _changePassword = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.fieldErrors.isEmpty ? e.message : null;
          _fieldErrors = e.fieldErrors;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
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

    // The router sends the user to the login screen.
    if (confirmed == true) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = ref.watch(authProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 16, 20, 40),
            children: [
              const GalaxyPageHeader(
                title: 'Profile',
                subtitle: 'Your account details',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GalaxyCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: GalaxyColors.purple.withValues(alpha: 0.25),
                            child: Text(
                              (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: GalaxyColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ?? '',
                                  style: const TextStyle(
                                    color: GalaxyColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  user?.email ?? '',
                                  style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        errorText: _fieldErrors['name'],
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _course,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Course (optional)',
                        hintText: 'e.g. BSIT',
                        prefixIcon: const Icon(Icons.school_outlined),
                        errorText: _fieldErrors['course'],
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: _yearLevel,
                      dropdownColor: GalaxyColors.surface,
                      decoration: InputDecoration(
                        labelText: 'Year level (optional)',
                        prefixIcon: const Icon(Icons.stairs_outlined),
                        errorText: _fieldErrors['year_level'],
                      ),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Not set')),
                        for (var year = 1; year <= 6; year++)
                          DropdownMenuItem<int?>(value: year, child: Text('Year $year')),
                      ],
                      onChanged: (value) => setState(() => _yearLevel = value),
                    ),
                    const SizedBox(height: 8),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _changePassword,
                      onChanged: (value) => setState(() => _changePassword = value),
                      title: const Text(
                        'Change password',
                        style: TextStyle(color: GalaxyColors.textPrimary),
                      ),
                    ),
                    if (_changePassword) ...[
                      TextFormField(
                        controller: _currentPassword,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Current password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          errorText: _fieldErrors['current_password'],
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Enter your current password' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPassword,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          errorText: _fieldErrors['password'],
                        ),
                        validator: (v) =>
                            (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPassword,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: Icon(Icons.lock_reset_rounded),
                        ),
                        validator: (v) =>
                            v != _newPassword.text ? 'Passwords do not match' : null,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Changing your password signs you out on your other devices.',
                        style: TextStyle(color: GalaxyColors.textSecondary, fontSize: 11),
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: GalaxyColors.pink, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text('Save Changes'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Log Out'),
                    ),
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
