
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/progress.dart';
import '../../models/task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/pet_view.dart';
import '../../widgets/galaxy_focus_button.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: progress.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: GalaxyColors.purple,
            ),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: GalaxyColors.blue,
                    size: 55,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Unable to load your galaxy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(progressProvider),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
          data: (data) => _GalaxyHome(progress: data),
        ),
      ),
    );
  }
}

class _GalaxyHome extends ConsumerWidget {
  const _GalaxyHome({required this.progress});

  final Progress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskProvider);

    return RefreshIndicator(
      color: GalaxyColors.purple,
      backgroundColor: GalaxyColors.surface,
      onRefresh: () async {
        await Future.wait([
          ref.refresh(progressProvider.future),
          ref.refresh(taskProvider.future),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 125),
        children: [
          // Welcome header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: GalaxyColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${progress.userName}! 👋',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Ready to conquer today's\nstudy missions?",
                      style: TextStyle(
                        color: GalaxyColors.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: GalaxyColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: GalaxyColors.purple
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: IconButton(
                  tooltip: 'Log out',
                  onPressed: () =>
                      ref.read(authProvider.notifier).logout(),
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: GalaxyColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Animated floating Mochi and galaxy island
          _PetSpotlight(progress: progress),

          const SizedBox(height: 7),

          // Level and XP
          _LevelProgress(progress: progress),

          const SizedBox(height: 20),

          // Streak and tasks due today
          Row(
            children: [
              Expanded(
                child: _MiniStatCard(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: GalaxyColors.gold,
                  value: '${progress.streakDays} days',
                  label: 'Streak',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStatCard(
                  icon: Icons.star_rounded,
                  iconColor: GalaxyColors.gold,
                  value: '${progress.tasksDueToday}',
                  label: 'Tasks Due Today',
                ),
              ),
            ],
          ),

          const SizedBox(height: 21),

          // Animated Start Focus Session button
          GalaxyFocusButton(
            onPressed: () => context.go('/focus'),
          ),

          const SizedBox(height: 25),

          // Today's missions
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Today's Missions",
                  style: TextStyle(
                    color: GalaxyColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/tasks'),
                child: const Text(
                  'See All ›',
                  style: TextStyle(
                    color: GalaxyColors.purple,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          tasksAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 25),
              child: Center(
                child: CircularProgressIndicator(
                  color: GalaxyColors.purple,
                ),
              ),
            ),
            error: (error, stack) => _MissionMessage(
              icon: Icons.wifi_off_rounded,
              message: 'Could not load missions.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(taskProvider),
            ),
            data: (tasks) {
              final pending = tasks
                  .where((task) => !task.isCompleted)
                  .toList();

              if (pending.isEmpty) {
                return _MissionMessage(
                  icon: Icons.check_circle_outline_rounded,
                  message: 'No pending missions. Great work!',
                  actionLabel: 'Add Mission',
                  onAction: () => context.go('/tasks'),
                );
              }

              return Column(
                children: pending
                    .take(3)
                    .map(
                      (task) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MissionCard(task: task),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Home pet spotlight with a floating galaxy island.
class _PetSpotlight extends StatelessWidget {
  const _PetSpotlight({required this.progress});

  final Progress progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 235,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft purple glow behind Mochi
          Positioned(
            bottom: 20,
            child: Container(
              width: 225,
              height: 165,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    GalaxyColors.purple
                        .withValues(alpha: 0.25),
                    GalaxyColors.blue
                        .withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Galaxy island stays stationary.
          const Positioned(
            bottom: 0,
            child: SizedBox(
              width: 250,
              height: 96,
              child: CustomPaint(
                painter: _HomeGalaxyIslandPainter(),
              ),
            ),
          ),

          // NEW: Mochi floats gently up and down.
          Positioned(
            bottom: 48,
            child: _FloatingHomePet(
              stage: progress.petStage,
              mood: progress.petMood,
            ),
          ),

          // Decorative stars around Mochi
          const Positioned(
            top: 18,
            left: 28,
            child: Icon(
              Icons.auto_awesome,
              color: GalaxyColors.gold,
              size: 24,
            ),
          ),
          const Positioned(
            top: 42,
            right: 35,
            child: Icon(
              Icons.star_rounded,
              color: GalaxyColors.pink,
              size: 29,
            ),
          ),
          const Positioned(
            bottom: 65,
            left: 38,
            child: Icon(
              Icons.star_rounded,
              color: GalaxyColors.gold,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// NEW: Floating animation, matching the My Pet screen.
class _FloatingHomePet extends StatefulWidget {
  const _FloatingHomePet({
    required this.stage,
    required this.mood,
  });

  final String stage;
  final String mood;

  @override
  State<_FloatingHomePet> createState() =>
      _FloatingHomePetState();
}

class _FloatingHomePetState extends State<_FloatingHomePet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final reduceMotion =
        MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Float upward by up to 8 pixels,
        // then return to the original position.
        final offset = reduceMotion
            ? 0.0
            : -8.0 * _controller.value;

        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
      child: PetView(
        stage: widget.stage,
        mood: widget.mood,
        size: 135,
        showMood: false,
      ),
    );
  }
}

// Level badge and XP progress bar.
class _LevelProgress extends StatelessWidget {
  const _LevelProgress({required this.progress});

  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final target = progress.xpForNextLevel;
    final current = progress.xpIntoLevel;

    final fraction = target > 0
        ? (current / target).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF6036B5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: GalaxyColors.purple,
            ),
            boxShadow: [
              BoxShadow(
                color: GalaxyColors.purple
                    .withValues(alpha: 0.3),
                blurRadius: 12,
              ),
            ],
          ),
          child: Text(
            'Lv. ${progress.level}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$current / $target XP',
                style: const TextStyle(
                  color: GalaxyColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Container(
                      height: 12,
                      color: GalaxyColors.surfaceLight,
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(
                        height: 12,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              GalaxyColors.purple,
                              GalaxyColors.blue,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Streak and tasks summary cards.
class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 83),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: GalaxyColors.surface
            .withValues(alpha: 0.91),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: GalaxyColors.purple
              .withValues(alpha: 0.26),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 25,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: GalaxyColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: GalaxyColors.textSecondary,
                    fontSize: 11,
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

// Task card on the Home Dashboard.
class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GalaxyColors.surface
            .withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: GalaxyColors.purple
              .withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_box_outline_blank_rounded,
            color: GalaxyColors.purple,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: GalaxyColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: GalaxyColors.purple
                        .withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    task.subjectName ?? 'General',
                    style: const TextStyle(
                      color: GalaxyColors.textPrimary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: GalaxyColors.gold,
          ),
        ],
      ),
    );
  }
}

// Empty state or error message for Today's Missions.
class _MissionMessage extends StatelessWidget {
  const _MissionMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GalaxyColors.surface
            .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: GalaxyColors.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: GalaxyColors.purple,
            size: 32,
          ),
          const SizedBox(height: 9),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GalaxyColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

// Floating galaxy island beneath Mochi.
class _HomeGalaxyIslandPainter extends CustomPainter {
  const _HomeGalaxyIslandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Purple glow behind the island
    final glow = Rect.fromLTWH(
      w * 0.08,
      h * 0.06,
      w * 0.84,
      h * 0.46,
    );

    canvas.drawOval(
      glow,
      Paint()
        ..color = GalaxyColors.purple
            .withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          16,
        ),
    );

    // Rocky underside of the island
    final rock = Path()
      ..moveTo(w * 0.10, h * 0.31)
      ..lineTo(w * 0.90, h * 0.31)
      ..lineTo(w * 0.77, h * 0.61)
      ..lineTo(w * 0.51, h * 0.98)
      ..lineTo(w * 0.26, h * 0.63)
      ..close();

    canvas.drawPath(
      rock,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8D65EE),
            Color(0xFF513894),
            Color(0xFF211747),
          ],
        ).createShader(
          Offset.zero & size,
        ),
    );

    // Left rock facet
    final leftFacet = Path()
      ..moveTo(w * 0.10, h * 0.31)
      ..lineTo(w * 0.38, h * 0.44)
      ..lineTo(w * 0.51, h * 0.98)
      ..lineTo(w * 0.26, h * 0.63)
      ..close();

    canvas.drawPath(
      leftFacet,
      Paint()..color = const Color(0xFF6342B5),
    );

    // Right rock facet
    final rightFacet = Path()
      ..moveTo(w * 0.90, h * 0.31)
      ..lineTo(w * 0.63, h * 0.44)
      ..lineTo(w * 0.51, h * 0.98)
      ..lineTo(w * 0.77, h * 0.61)
      ..close();

    canvas.drawPath(
      rightFacet,
      Paint()..color = const Color(0xFF342568),
    );

    // Surface of the island
    final surface = Rect.fromLTWH(
      w * 0.08,
      h * 0.08,
      w * 0.84,
      h * 0.42,
    );

    canvas.drawOval(
      surface,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFB089FF),
            Color(0xFF7954D7),
            Color(0xFF5847B8),
          ],
        ).createShader(surface),
    );

    // Soft glowing rim
    canvas.drawOval(
      surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = GalaxyColors.blue
            .withValues(alpha: 0.52)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          7,
        ),
    );

    // Bright platform outline
    canvas.drawOval(
      surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFD5A7FF),
    );

    // Small galaxy crystals
    _drawCrystal(
      canvas,
      Offset(w * 0.16, h * 0.25),
      15,
      GalaxyColors.blue,
    );

    _drawCrystal(
      canvas,
      Offset(w * 0.84, h * 0.27),
      18,
      GalaxyColors.purple,
    );

    _drawCrystal(
      canvas,
      Offset(w * 0.72, h * 0.42),
      10,
      GalaxyColors.pink,
    );
  }

  void _drawCrystal(
    Canvas canvas,
    Offset center,
    double height,
    Color color,
  ) {
    final crystal = Path()
      ..moveTo(center.dx, center.dy - height)
      ..lineTo(
        center.dx + height * 0.35,
        center.dy,
      )
      ..lineTo(
        center.dx,
        center.dy + height * 0.2,
      )
      ..lineTo(
        center.dx - height * 0.35,
        center.dy,
      )
      ..close();

    canvas.drawPath(
      crystal,
      Paint()..color = color,
    );

    canvas.drawPath(
      crystal,
      Paint()
        ..color = color.withValues(alpha: 0.50)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          6,
        ),
    );
  }

  @override
  bool shouldRepaint(
    covariant _HomeGalaxyIslandPainter oldDelegate,
  ) {
    return false;
  }
}
