import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../models/subject.dart';
import '../../providers/subject_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/galaxy_page.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  Future<void> _openForm(BuildContext context, WidgetRef ref, [Subject? subject]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => SubjectFormDialog(subject: subject),
    );
    if (saved == true) {
      ref.invalidate(subjectsProvider);
      ref.invalidate(taskProvider); // task cards show the subject name and color
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Subject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: GalaxyColors.surface,
        title: Text(
          'Delete ${subject.name}?',
          style: const TextStyle(color: GalaxyColors.textPrimary),
        ),
        content: Text(
          subject.tasksCount == 0
              ? 'This subject has no tasks.'
              : 'Its ${subject.tasksCount} ${subject.tasksCount == 1 ? 'task' : 'tasks'} '
                  'will be kept, but without a subject.',
          style: const TextStyle(color: GalaxyColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(subjectRepositoryProvider).deleteSubject(subject.id);
      ref.invalidate(subjectsProvider);
      ref.invalidate(taskProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Subject'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: GalaxyColors.purple,
          backgroundColor: GalaxyColors.surface,
          onRefresh: () => ref.refresh(subjectsProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 16, 20, 100),
            children: [
              const GalaxyPageHeader(
                title: 'Subjects',
                subtitle: 'Group your tasks by class',
                icon: Icons.class_rounded,
                iconColor: GalaxyColors.mint,
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: subjectsAsync.when(
                  loading: () => galaxyLoading,
                  error: (error, _) => GalaxyError(
                    message: error is ApiException ? error.message : 'Could not load your subjects.',
                    onRetry: () => ref.invalidate(subjectsProvider),
                  ),
                  data: (subjects) {
                    if (subjects.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No subjects yet.\nAdd your classes, like "Math" or "IT Elective".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: GalaxyColors.textSecondary, height: 1.5),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (final subject in subjects) ...[
                          GalaxyCard(
                            padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                            child: Row(
                              children: [
                                CircleAvatar(radius: 9, backgroundColor: subject.colorValue),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subject.name,
                                        style: const TextStyle(
                                          color: GalaxyColors.textPrimary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        '${subject.tasksCount} ${subject.tasksCount == 1 ? 'task' : 'tasks'}',
                                        style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () => _openForm(context, ref, subject),
                                  icon: const Icon(Icons.edit_rounded, color: GalaxyColors.textSecondary, size: 20),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () => _delete(context, ref, subject),
                                  icon: const Icon(Icons.delete_outline_rounded, color: GalaxyColors.textSecondary, size: 20),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add or edit a subject. Pops `true` when saved.
/// Also used from the task form to add a subject on the spot.
class SubjectFormDialog extends ConsumerStatefulWidget {
  const SubjectFormDialog({super.key, this.subject});

  final Subject? subject;

  @override
  ConsumerState<SubjectFormDialog> createState() => _SubjectFormDialogState();
}

class _SubjectFormDialogState extends ConsumerState<SubjectFormDialog> {
  late final _name = TextEditingController(text: widget.subject?.name ?? '');
  late String _color = widget.subject?.color.toUpperCase() ?? subjectColors.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a subject name.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(subjectRepositoryProvider);
      if (widget.subject == null) {
        await repo.createSubject(name: name, color: _color);
      } else {
        await repo.updateSubject(widget.subject!.id, name: name, color: _color);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save the subject.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GalaxyColors.surface,
      title: Text(
        widget.subject == null ? 'New subject' : 'Edit subject',
        style: const TextStyle(color: GalaxyColors.textPrimary, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Name', errorText: _error),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 6),
          const Text('Color', style: TextStyle(color: GalaxyColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hex in subjectColors)
                Semantics(
                  label: 'Color $hex',
                  selected: _color == hex,
                  button: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: hexToColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == hex ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: _color == hex
                          ? const Icon(Icons.check_rounded, color: Colors.black87, size: 18)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
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
