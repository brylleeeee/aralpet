import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../models/task.dart';
import '../../providers/task_provider.dart';

class TaskForm extends ConsumerStatefulWidget {
  const TaskForm({super.key, this.task});

  final Task? task; // null = add, otherwise edit

  @override
  ConsumerState<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<TaskForm> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  DateTime? _dueDate;
  String _priority = 'medium';
  int? _subjectId;
  bool _saving = false;
  Map<String, String> _errors = {};
  String? _generalError;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _notes = TextEditingController(text: t?.notes ?? '');
    _dueDate = t?.dueDate;
    _priority = t?.priority ?? 'medium';
    _subjectId = t?.subjectId;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _errors = {'title': 'Please enter a title.'});
      return;
    }
    setState(() {
      _saving = true;
      _errors = {};
      _generalError = null;
    });
    final repo = ref.read(taskRepositoryProvider);
    try {
      if (widget.task == null) {
        await repo.create(
          title: _title.text.trim(),
          notes: _notes.text.trim(),
          dueDate: _dueDate,
          priority: _priority,
          subjectId: _subjectId,
        );
      } else {
        await repo.update(
          widget.task!.id,
          title: _title.text.trim(),
          notes: _notes.text.trim(),
          dueDate: _dueDate,
          priority: _priority,
          subjectId: _subjectId,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _errors = e.fieldErrors;
        _generalError = e.fieldErrors.isEmpty ? e.message : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];
    final subjectIds = subjects.map((s) => s.id).toSet();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.task == null ? 'New task' : 'Edit task',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                  labelText: 'Title', errorText: _errors['title']),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: subjectIds.contains(_subjectId) ? _subjectId : null,
              decoration: InputDecoration(
                  labelText: 'Subject', errorText: _errors['subject_id']),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('No subject')),
                for (final s in subjects)
                  DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _subjectId = v),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'low', label: Text('Low')),
                ButtonSegment(value: 'medium', label: Text('Medium')),
                ButtonSegment(value: 'high', label: Text('High')),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(_dueDate == null
                  ? 'Set due date'
                  : 'Due ${formatDate(_dueDate!)}'),
            ),
            if (_errors['due_date'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_errors['due_date']!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                  labelText: 'Notes (optional)', errorText: _errors['notes']),
            ),
            if (_generalError != null) ...[
              const SizedBox(height: 8),
              Text(_generalError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
