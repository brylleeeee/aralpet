
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../models/task.dart';
import '../../providers/progress_provider.dart';
import '../../providers/task_provider.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  bool _showCompleted = false;

  final Set<int> _completingTaskIds = {};

  // Add or edit an existing task.
  Future<void> _openTaskForm([Task? task]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _TaskFormDialog(task: task),
    );

    if (changed == true && mounted) {
      ref.invalidate(taskProvider);
      ref.invalidate(progressProvider);
    }
  }

  // Complete a task and receive the XP awarded by Laravel.
  Future<void> _completeTask(Task task) async {
    if (task.isCompleted ||
        _completingTaskIds.contains(task.id)) {
      return;
    }

    setState(() {
      _completingTaskIds.add(task.id);
    });

    try {
      final result = await ref
          .read(taskRepositoryProvider)
          .completeTask(task.id);

      if (!mounted) return;

      // Refresh the task list and the dashboard's XP data.
      ref.invalidate(taskProvider);
      ref.invalidate(progressProvider);

      if (result.alreadyCompleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This task has already been completed.',
            ),
          ),
        );
        return;
      }

      // Only show earned XP after Laravel confirms completion.
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) => _CompletionDialog(
          taskTitle: task.title,
          xpEarned: result.xpEarned,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not complete the task. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _completingTaskIds.remove(task.id);
        });
      }
    }
  }

  Future<void> _refreshTasks() async {
    try {
      await ref.refresh(taskProvider.future);
    } catch (_) {
      // The error state will appear in the task list.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(taskProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative galaxy mountains.
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GalaxyMountainsPainter(),
                ),
              ),
            ),

            RefreshIndicator(
              color: GalaxyColors.purple,
              backgroundColor: GalaxyColors.surface,
              onRefresh: _refreshTasks,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  22,
                  20,
                  130,
                ),
                children: [
                  _buildHeader(),

                  const SizedBox(height: 30),

                  tasksAsync.when(
                    loading: () => Column(
                      children: [
                        _buildFilters(0, 0),
                        const SizedBox(height: 45),
                        const CircularProgressIndicator(
                          color: GalaxyColors.purple,
                        ),
                      ],
                    ),

                    error: (error, stack) => Column(
                      children: [
                        _buildFilters(0, 0),
                        const SizedBox(height: 24),
                        _buildMessage(
                          icon: Icons.wifi_off_rounded,
                          title: 'Unable to load tasks',
                          subtitle: error is ApiException
                              ? error.message
                              : 'Please check your connection.',
                          buttonText: 'Try Again',
                          onPressed: () =>
                              ref.invalidate(taskProvider),
                        ),
                      ],
                    ),

                    data: (tasks) {
                      final pending = tasks
                          .where((task) => !task.isCompleted)
                          .toList();

                      final completed = tasks
                          .where((task) => task.isCompleted)
                          .toList();

                      final visibleTasks = _showCompleted
                          ? completed
                          : pending;

                      return Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          _buildFilters(
                            pending.length,
                            completed.length,
                          ),

                          const SizedBox(height: 24),

                          if (visibleTasks.isEmpty)
                            _buildMessage(
                              icon: _showCompleted
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.task_alt_rounded,
                              title: _showCompleted
                                  ? 'No completed tasks yet'
                                  : 'No pending tasks',
                              subtitle: _showCompleted
                                  ? 'Your finished tasks will appear here.'
                                  : 'Add your first task to get started.',
                              buttonText: _showCompleted
                                  ? null
                                  : 'Add Task',
                              onPressed: _showCompleted
                                  ? null
                                  : () => _openTaskForm(),
                            )
                          else
                            ...visibleTasks.asMap().entries.map(
                              (entry) {
                                final task = entry.value;

                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 13,
                                  ),
                                  child: _TaskCard(
                                    task: task,
                                    accent: entry.key.isEven
                                        ? GalaxyColors.purple
                                        : GalaxyColors.blue,
                                    isCompleting:
                                        _completingTaskIds.contains(
                                      task.id,
                                    ),
                                    onTap: () =>
                                        _openTaskForm(task),
                                    onCheck: () =>
                                        _completeTask(task),
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: GalaxyColors.purple.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.assignment_outlined,
            color: GalaxyColors.purple,
            size: 27,
          ),
        ),

        const SizedBox(width: 12),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tasks',
                style: TextStyle(
                  color: GalaxyColors.textPrimary,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Your Study Missions',
                style: TextStyle(
                  color: GalaxyColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Glowing Add Task button.
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFB08AFF),
                Color(0xFF7543DA),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFFD6BDFF),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: GalaxyColors.purple.withValues(alpha: 0.38),
                blurRadius: 17,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => _openTaskForm(),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(int pendingCount, int completedCount) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: GalaxyColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: GalaxyColors.border.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _filterButton(
              title: 'Pending',
              count: pendingCount,
              selected: !_showCompleted,
              onTap: () {
                setState(() => _showCompleted = false);
              },
            ),
          ),

          Expanded(
            child: _filterButton(
              title: 'Completed',
              count: completedCount,
              selected: _showCompleted,
              onTap: () {
                setState(() => _showCompleted = true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton({
    required String title,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                colors: [
                  Color(0xFF7543DA),
                  Color(0xFFA78BFA),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? GalaxyColors.purple
              : Colors.transparent,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: GalaxyColors.purple
                      .withValues(alpha: 0.30),
                  blurRadius: 13,
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 5,
            ),
            child: Text(
              '$title ($count)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : GalaxyColors.textSecondary,
                fontSize: 13,
                fontWeight: selected
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 40,
      ),
      decoration: BoxDecoration(
        color: GalaxyColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: GalaxyColors.purple.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 55,
            color: GalaxyColors.purple,
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GalaxyColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GalaxyColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (buttonText != null && onPressed != null) ...[
            const SizedBox(height: 17),
            FilledButton(
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ],
        ],
      ),
    );
  }
}

// Individual task card.
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.accent,
    required this.isCompleting,
    required this.onTap,
    required this.onCheck,
  });

  final Task task;
  final Color accent;
  final bool isCompleting;
  final VoidCallback onTap;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GalaxyColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: accent.withValues(alpha: 0.58),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 14,
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left-side colored accent.
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(17),
                ),
              ),
            ),

            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        // Completion checkbox.
                        if (isCompleting)
                          const SizedBox(
                            width: 32,
                            height: 40,
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: GalaxyColors.purple,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            width: 32,
                            height: 40,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: task.isCompleted
                                  ? 'Completed'
                                  : 'Complete task',
                              onPressed: task.isCompleted
                                  ? null
                                  : onCheck,
                              icon: Icon(
                                task.isCompleted
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                color: task.isCompleted
                                    ? GalaxyColors.mint
                                    : GalaxyColors.textSecondary,
                                size: 25,
                              ),
                            ),
                          ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: GalaxyColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor:
                                      GalaxyColors.textSecondary,
                                ),
                              ),

                              const SizedBox(height: 10),

                              Wrap(
                                spacing: 7,
                                runSpacing: 6,
                                crossAxisAlignment:
                                    WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(
                                        alpha: 0.23,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      task.subjectName ?? 'General',
                                      style: const TextStyle(
                                        color: GalaxyColors.textPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),

                                  if (task.dueDate != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_month_rounded,
                                          size: 13,
                                          color: GalaxyColors
                                              .textSecondary,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          _formatDueDate(task.dueDate!),
                                          style: const TextStyle(
                                            color: GalaxyColors
                                                .textSecondary,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // XP reward and priority.
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (task.isCompleted)
                              const Icon(
                                Icons.verified_rounded,
                                color: GalaxyColors.mint,
                                size: 21,
                              )
                            else
                              const Text(
                                '+50 XP',
                                style: TextStyle(
                                  color: GalaxyColors.gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              task.isCompleted
                                  ? 'DONE'
                                  : task.priority.toUpperCase(),
                              style: TextStyle(
                                color: task.isCompleted
                                    ? GalaxyColors.mint
                                    : _priorityColor(task.priority),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return GalaxyColors.pink;
      case 'low':
        return GalaxyColors.mint;
      default:
        return GalaxyColors.gold;
    }
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Today';

    if (target == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}';
  }
}

// Animated congratulations popup.
class _CompletionDialog extends StatelessWidget {
  const _CompletionDialog({
    required this.taskTitle,
    required this.xpEarned,
  });

  final String taskTitle;
  final int xpEarned;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1.0),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 460),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: ((value - 0.7) / 0.3)
                .clamp(0.0, 1.0)
                .toDouble(),
            child: child,
          ),
        );
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 24,
        ),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF32245D),
                Color(0xFF1C2444),
                Color(0xFF141B35),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: GalaxyColors.purple,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: GalaxyColors.purple
                    .withValues(alpha: 0.4),
                blurRadius: 35,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: GalaxyColors.gold,
                    size: 20,
                  ),
                  SizedBox(width: 15),
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: GalaxyColors.blue,
                    size: 26,
                  ),
                  SizedBox(width: 15),
                  Icon(
                    Icons.star_rounded,
                    color: GalaxyColors.pink,
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      GalaxyColors.gold
                          .withValues(alpha: 0.24),
                      GalaxyColors.purple
                          .withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: GalaxyColors.gold,
                  size: 62,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Congratulations!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GalaxyColors.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 9),

              const Text(
                'You completed your task!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GalaxyColors.textSecondary,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 15),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GalaxyColors.surface
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: GalaxyColors.purple
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      taskTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: GalaxyColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 13),

                    const Icon(
                      Icons.bolt_rounded,
                      color: GalaxyColors.gold,
                      size: 25,
                    ),

                    Text(
                      '+$xpEarned XP',
                      style: const TextStyle(
                        color: GalaxyColors.gold,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Color(0x88FBBF24),
                            blurRadius: 17,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'Experience earned',
                      style: TextStyle(
                        color: GalaxyColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 19),

              const Text(
                'Keep up the great work!',
                style: TextStyle(
                  color: GalaxyColors.textSecondary,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.celebration_rounded,
                  ),
                  label: const Text('Awesome!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable Add / Edit Task dialog.
class _TaskFormDialog extends ConsumerStatefulWidget {
  const _TaskFormDialog({this.task});

  final Task? task;

  @override
  ConsumerState<_TaskFormDialog> createState() =>
      _TaskFormDialogState();
}

class _TaskFormDialogState
    extends ConsumerState<_TaskFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  late String _priority;
  DateTime? _dueDate;

  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.task != null;
  bool get _isCompleted => widget.task?.isCompleted ?? false;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.task?.title ?? '',
    );

    _notesController = TextEditingController(
      text: widget.task?.notes ?? '',
    );

    _priority = widget.task?.priority ?? 'medium';
    _dueDate = widget.task?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    if (_saving || _isCompleted) return;

    final chosen = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (chosen != null && mounted) {
      setState(() => _dueDate = chosen);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      setState(() => _error = 'Please enter a task title.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repository = ref.read(taskRepositoryProvider);

      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      if (_isEditing) {
        await repository.updateTask(
          id: widget.task!.id,
          title: title,
          notes: notes,
          priority: _priority,
          dueDate: _dueDate,
          subjectId: widget.task!.subjectId,
        );
      } else {
        await repository.createTask(
          title: title,
          notes: notes,
          priority: _priority,
          dueDate: _dueDate,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error is ApiException
            ? error.message
            : error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: GalaxyColors.surface,
        title: const Text('Delete Task?'),
        content: const Text(
          'This task will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: GalaxyColors.pink,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(taskRepositoryProvider)
          .deleteTask(widget.task!.id);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error is ApiException
            ? error.message
            : error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: GalaxyColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(23),
        side: BorderSide(
          color: GalaxyColors.purple.withValues(alpha: 0.5),
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 25,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _isEditing
                      ? Icons.edit_note_rounded
                      : Icons.add_task_rounded,
                  color: GalaxyColors.purple,
                  size: 29,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isEditing ? 'Task Details' : 'Add New Task',
                    style: const TextStyle(
                      color: GalaxyColors.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_isCompleted) ...[
              const Text(
                'This task is completed and cannot be edited.',
                style: TextStyle(
                  color: GalaxyColors.mint,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 15),
            ],

            TextField(
              controller: _titleController,
              enabled: !_saving && !_isCompleted,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Task Title',
                hintText: 'e.g. Finish Math assignment',
                prefixIcon: Icon(Icons.assignment_outlined),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _notesController,
              enabled: !_saving && !_isCompleted,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add details about your task',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'low',
                  child: Text('Low'),
                ),
                DropdownMenuItem(
                  value: 'medium',
                  child: Text('Medium'),
                ),
                DropdownMenuItem(
                  value: 'high',
                  child: Text('High'),
                ),
              ],
              onChanged: _saving || _isCompleted
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _priority = value);
                      }
                    },
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _saving || _isCompleted
                  ? null
                  : _selectDate,
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(
                _dueDate == null
                    ? 'Choose Due Date'
                    : 'Due: ${_dueDate!.month}/'
                        '${_dueDate!.day}/${_dueDate!.year}',
              ),
            ),

            if (_dueDate != null &&
                !_isCompleted &&
                !_saving)
              TextButton(
                onPressed: () {
                  setState(() => _dueDate = null);
                },
                child: const Text('Remove Due Date'),
              ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: GalaxyColors.pink,
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 22),

            if (!_isCompleted)
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _isEditing ? 'Save Changes' : 'Create Task',
                ),
              ),

            if (_isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete Task'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GalaxyColors.pink,
                  side: BorderSide(
                    color: GalaxyColors.pink.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Decorative galaxy mountains behind the task list.
class _GalaxyMountainsPainter extends CustomPainter {
  const _GalaxyMountainsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final backMountains = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.83)
      ..lineTo(size.width * 0.15, size.height * 0.76)
      ..lineTo(size.width * 0.31, size.height * 0.87)
      ..lineTo(size.width * 0.56, size.height * 0.75)
      ..lineTo(size.width * 0.77, size.height * 0.88)
      ..lineTo(size.width, size.height * 0.78)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      backMountains,
      Paint()
        ..color = const Color(0xFF292052)
            .withValues(alpha: 0.75),
    );

    final frontMountains = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.94)
      ..lineTo(size.width * 0.22, size.height * 0.83)
      ..lineTo(size.width * 0.41, size.height * 0.94)
      ..lineTo(size.width * 0.64, size.height * 0.85)
      ..lineTo(size.width * 0.86, size.height * 0.96)
      ..lineTo(size.width, size.height * 0.88)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      frontMountains,
      Paint()
        ..color = const Color(0xFF11142F)
            .withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(
    covariant _GalaxyMountainsPainter oldDelegate,
  ) {
    return false;
  }
}
