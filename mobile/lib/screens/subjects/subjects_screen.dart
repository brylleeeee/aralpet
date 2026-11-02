import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../models/subject.dart';
import '../../providers/task_provider.dart';

const _palette = [
  '#2E9E6B', '#4F46E5', '#E11D48', '#F59E0B',
  '#0EA5E9', '#9333EA', '#EA580C', '#64748B',
];

Color colorFromHex(String? hex) {
  if (hex == null || !hex.startsWith('#') || hex.length != 7) {
    return Colors.grey;
  }
  final value = int.tryParse('FF${hex.substring(1)}', radix: 16);
  return value == null ? Colors.grey : Color(value);
}

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      {Subject? subject}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SubjectDialog(subject: subject),
    );
    if (saved == true) {
      ref.invalidate(subjectsProvider);
      ref.invalidate(tasksProvider);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Subject s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete subject?'),
        content: Text('"${s.name}" will be removed. Its tasks are kept, '
            'but they will have no subject.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(taskRepositoryProvider).deleteSubject(s.id);
      ref.invalidate(subjectsProvider);
      ref.invalidate(tasksProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subjects')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add subject'),
      ),
      body: subjects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e is ApiException ? e.message : 'Something went wrong.'),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: () => ref.invalidate(subjectsProvider),
                  child: const Text('Try again')),
            ],
          ),
        ),
        data: (list) => list.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No subjects yet. Add one, such as "Mathematics", '
                    'to group your tasks.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final s = list[i];
                  return ListTile(
                    leading: CircleAvatar(
                        radius: 14, backgroundColor: colorFromHex(s.color)),
                    title: Text(s.name),
                    onTap: () => _openForm(context, ref, subject: s),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) => v == 'edit'
                          ? _openForm(context, ref, subject: s)
                          : _delete(context, ref, s),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _SubjectDialog extends ConsumerStatefulWidget {
  const _SubjectDialog({this.subject});

  final Subject? subject;

  @override
  ConsumerState<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends ConsumerState<_SubjectDialog> {
  late final TextEditingController _name;
  late String _color;
  bool _saving = false;
  String? _nameError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.subject?.name ?? '');
    final existing = widget.subject?.color;
    _color = (existing != null && existing.length == 7) ? existing : _palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter a name.');
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
      _generalError = null;
    });
    final repo = ref.read(taskRepositoryProvider);
    try {
      if (widget.subject == null) {
        await repo.createSubject(name: name, color: _color);
      } else {
        await repo.updateSubject(widget.subject!.id, name: name, color: _color);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _nameError = e.fieldErrors['name'];
        _generalError = e.fieldErrors.isEmpty ? e.message : e.fieldErrors['color'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.subject == null ? 'New subject' : 'Edit subject'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration:
                  InputDecoration(labelText: 'Name', errorText: _nameError),
            ),
            const SizedBox(height: 8),
            const Text('Color'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in _palette)
                  GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: colorFromHex(hex),
                      child: _color == hex
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
              ],
            ),
            if (_generalError != null) ...[
              const SizedBox(height: 12),
              Text(_generalError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
