
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/progress.dart';
import '../../providers/progress_provider.dart';
import '../../widgets/pet_view.dart';

// Evolution milestones match Laravel PetEvolutionService.
const List<String> _petStageKeys = [
  'egg',
  'hatchling',
  'junior',
  'adult',
  'elder',
];

const List<int> _petStageLevels = [1, 2, 5, 10, 20];

// Convert legacy stage names to the five Laravel stage names.
String _normalizeStage(String stage) {
  final normalized = stage.trim().toLowerCase();

  switch (normalized) {
    case 'baby':
      return 'hatchling';
    case 'teen':
      return 'junior';
    default:
      return normalized;
  }
}

String _stageLabel(String stage) {
  final normalized = _normalizeStage(stage);

  if (normalized.isEmpty) return 'Unknown';

  return '${normalized[0].toUpperCase()}'
      '${normalized.substring(1)}';
}

int _stageIndex(String stage) {
  final index = _petStageKeys.indexOf(
    _normalizeStage(stage),
  );

  return index < 0 ? 0 : index;
}

// Display a stage consistent with the current student level,
// even if an older API response still contains 'baby' or 'teen'.
// The backend PetEvolutionService remains responsible for
// storing the actual evolution stage in the database.
String _stageForProgress(Progress progress) {
  final level = progress.level;
  var stageIndex = 0;

  for (var i = 0; i < _petStageLevels.length; i++) {
    if (level >= _petStageLevels[i]) {
      stageIndex = i;
    }
  }

  final expectedStage = _petStageKeys[stageIndex];
  final reportedStage = _normalizeStage(progress.petStage);

  return reportedStage == expectedStage
      ? reportedStage
      : expectedStage;
}

class PetScreen extends ConsumerWidget {
  const PetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(progressProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: progressAsync.when(
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
                    color: GalaxyColors.purple,
                    size: 55,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Unable to load your pet',
                    style: TextStyle(
                      color: GalaxyColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Check your server connection '
                    'and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GalaxyColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(progressProvider);
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),

          data: (progress) => _PetContent(
            progress: progress,
          ),
        ),
      ),
    );
  }
}

class _PetContent extends ConsumerWidget {
  const _PetContent({
    required this.progress,
  });

  final Progress progress;

  void _showComingSoon(
    BuildContext context,
    String feature,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature is not available yet. '
          'We will connect this feature later.',
        ),
      ),
    );
  }

  // Show evolution information and milestones.
  Future<void> _showEvolutionDetails(
    BuildContext context,
  ) async {
    final currentStage = _stageForProgress(progress);
    final currentIndex = _stageIndex(currentStage);

    final hasNext =
        currentIndex < _petStageKeys.length - 1;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: GalaxyColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(
              color: GalaxyColors.purple,
            ),
          ),
          title: const Text(
            'Pet Evolution',
            style: TextStyle(
              color: GalaxyColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // Current evolution stage.
                Text(
                  'Current stage: '
                  '${_stageLabel(currentStage)}',
                  style: const TextStyle(
                    color: GalaxyColors.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 9),

                // Next evolution requirement.
                Text(
                  hasNext
                      ? 'Next: '
                          '${_stageLabel(_petStageKeys[currentIndex + 1])} '
                          'at Level '
                          '${_petStageLevels[currentIndex + 1]}.'
                      : 'Your companion has reached '
                          'its final stage!',
                  style: const TextStyle(
                    color: GalaxyColors.textPrimary,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Evolution happens automatically '
                  'when you earn enough XP to reach '
                  'the required level.',
                  style: TextStyle(
                    color: GalaxyColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 18),

                // All five pet evolution milestones.
                for (
                  var i = 0;
                  i < _petStageKeys.length;
                  i++
                )
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          progress.level >=
                                  _petStageLevels[i]
                              ? Icons.check_circle_rounded
                              : Icons.lock_outline_rounded,
                          color: progress.level >=
                                  _petStageLevels[i]
                              ? GalaxyColors.mint
                              : GalaxyColors.textSecondary,
                          size: 19,
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Text(
                            _stageLabel(
                              _petStageKeys[i],
                            ),
                            style: const TextStyle(
                              color: GalaxyColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),

                        Text(
                          'Lv. ${_petStageLevels[i]}',
                          style: const TextStyle(
                            color: GalaxyColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return RefreshIndicator(
      color: GalaxyColors.purple,
      backgroundColor: GalaxyColors.surface,
      onRefresh: () =>
          ref.refresh(progressProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          19,
          22,
          19,
          130,
        ),
        children: [
          // PAGE HEADER
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: GalaxyColors.pink
                      .withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.pets_rounded,
                  color: GalaxyColors.purple,
                  size: 28,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pet',
                      style: TextStyle(
                        color: GalaxyColors.textPrimary,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your Study Companion',
                      style: TextStyle(
                        color: GalaxyColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // NEW: Refresh pet progress from Laravel.
              IconButton(
                tooltip: 'Refresh pet progress',
                onPressed: () {
                  ref.invalidate(progressProvider);
                },
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: GalaxyColors.blue,
                  size: 25,
                ),
              ),

              const Icon(
                Icons.auto_awesome_rounded,
                color: GalaxyColors.gold,
                size: 24,
              ),
            ],
          ),

          const SizedBox(height: 17),

          // PET ON FLOATING GALAXY PLATFORM
          _PetSpotlight(
            progress: progress,

            onFeed: () {
              _showComingSoon(
                context,
                'Feeding',
              );
            },

            onCustomize: () {
              _showComingSoon(
                context,
                'Pet customization',
              );
            },

            // NEW: Show pet evolution milestones.
            onEvolve: () {
              _showEvolutionDetails(context);
            },
          ),

          const SizedBox(height: 10),

          // PET INFORMATION CARD
          _PetInfoCard(
            progress: progress,
          ),

          const SizedBox(height: 22),

          // MOTIVATIONAL MESSAGE
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: GalaxyColors.surface
                  .withValues(alpha: 0.83),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: GalaxyColors.purple
                    .withValues(alpha: 0.30),
              ),
            ),
            child: const Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: GalaxyColors.gold,
                  size: 25,
                ),

                SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keep Growing Together!',
                        style: TextStyle(
                          color: GalaxyColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      SizedBox(height: 7),

                      Text(
                        'Stay consistent with your studies, '
                        'complete your tasks, and keep building '
                        'your progress with your companion.',
                        style: TextStyle(
                          color: GalaxyColors.textSecondary,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
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

// Main pet display with floating island and action buttons.
class _PetSpotlight extends StatelessWidget {
  const _PetSpotlight({
    required this.progress,
    required this.onFeed,
    required this.onCustomize,
    required this.onEvolve,
  });

  final Progress progress;
  final VoidCallback onFeed;
  final VoidCallback onCustomize;
  final VoidCallback onEvolve;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 355,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final islandWidth = width * 0.73;
          final islandLeft = width * 0.015;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Galaxy glow behind the pet.
              Positioned(
                left: width * 0.03,
                top: 30,
                width: width * 0.77,
                height: 255,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        GalaxyColors.purple
                            .withValues(alpha: 0.30),
                        GalaxyColors.blue
                            .withValues(alpha: 0.09),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Decorative stars.
              const Positioned(
                left: 14,
                top: 86,
                child: Icon(
                  Icons.star_rounded,
                  color: GalaxyColors.gold,
                  size: 27,
                ),
              ),

              const Positioned(
                left: 65,
                top: 30,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: GalaxyColors.purple,
                  size: 22,
                ),
              ),

              const Positioned(
                right: 95,
                top: 48,
                child: Icon(
                  Icons.star_rounded,
                  color: GalaxyColors.pink,
                  size: 18,
                ),
              ),

              const Positioned(
                left: 37,
                bottom: 76,
                child: Icon(
                  Icons.auto_awesome,
                  color: GalaxyColors.blue,
                  size: 18,
                ),
              ),

              // Floating island.
              Positioned(
                left: islandLeft,
                bottom: 18,
                width: islandWidth,
                height: 126,
                child: const CustomPaint(
                  painter: _FloatingIslandPainter(),
                ),
              ),

              // Animated pet.
              Positioned(
                left: width * 0.045,
                bottom: 105,
                width: width * 0.68,
                height: 235,
                child: Center(
                  child: _FloatingPet(
                    stage: _stageForProgress(progress),
                    mood: progress.petMood,
                  ),
                ),
              ),

              // Right-side action buttons.
              Positioned(
                right: 0,
                top: 50,
                child: Column(
                  children: [
                    _PetActionButton(
                      icon: Icons.favorite_rounded,
                      label: 'Feed',
                      color: GalaxyColors.pink,
                      onTap: onFeed,
                    ),

                    const SizedBox(height: 17),

                    _PetActionButton(
                      icon: Icons.checkroom_rounded,
                      label: 'Customize',
                      color: GalaxyColors.purple,
                      onTap: onCustomize,
                    ),

                    const SizedBox(height: 17),

                    _PetActionButton(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Evolve',
                      color: GalaxyColors.mint,
                      onTap: onEvolve,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Gentle floating animation for the pet.
class _FloatingPet extends StatefulWidget {
  const _FloatingPet({
    required this.stage,
    required this.mood,
  });

  final String stage;
  final String mood;

  @override
  State<_FloatingPet> createState() =>
      _FloatingPetState();
}

class _FloatingPetState extends State<_FloatingPet>
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

    if (MediaQuery.disableAnimationsOf(context)) {
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
        size: 165,
        showMood: false,
      ),
    );
  }
}

// Feed, Customize, and Evolve action buttons.
class _PetActionButton extends StatelessWidget {
  const _PetActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 77,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GalaxyColors.surface
                  .withValues(alpha: 0.95),
              border: Border.all(
                color: color.withValues(alpha: 0.65),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.16),
                  blurRadius: 13,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
            ),
          ),

          const SizedBox(height: 7),

          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GalaxyColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Pet name, level, XP, mood, and evolution information.
class _PetInfoCard extends StatelessWidget {
  const _PetInfoCard({
    required this.progress,
  });

  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final currentXp = progress.xpIntoLevel;
    final targetXp = progress.xpForNextLevel;

    final fraction = targetXp > 0
        ? (currentXp / targetXp)
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;

    // Mood comes from Laravel's PetMoodService.
    final currentMood = progress.petMood.trim().toLowerCase();
    final mood = currentMood.isEmpty
        ? 'Unknown'
        : '${currentMood[0].toUpperCase()}'
            '${currentMood.substring(1)}';
    final IconData moodIcon;
    final Color moodColor;
    switch (currentMood) {
      case 'happy':
        moodIcon = Icons.sentiment_very_satisfied_rounded;
        moodColor = GalaxyColors.gold;
        break;
      case 'sad':
        moodIcon = Icons.sentiment_dissatisfied_rounded;
        moodColor = GalaxyColors.pink;
        break;
      default:
        moodIcon = Icons.sentiment_neutral_rounded;
        moodColor = GalaxyColors.blue;
    }

    final currentStage = _stageForProgress(progress);
    final stage = _stageLabel(currentStage);
    final currentStageIndex = _stageIndex(currentStage);

    final hasNextStage =
        currentStageIndex < _petStageKeys.length - 1;

    final nextStageText = hasNextStage
        ? 'Next: '
            '${_stageLabel(_petStageKeys[currentStageIndex + 1])} '
            'at Level ${_petStageLevels[currentStageIndex + 1]}'
        : 'Final evolution stage reached!';

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF29224E),
            Color(0xFF19213B),
            Color(0xFF172342),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: GalaxyColors.purple
              .withValues(alpha: 0.58),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: GalaxyColors.purple
                .withValues(alpha: 0.18),
            blurRadius: 23,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pet name and level.
          Row(
            children: [
              Expanded(
                child: Text(
                  progress.petName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: GalaxyColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF7543DA),
                      Color(0xFFA78BFA),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFDDCBFF),
                  ),
                ),
                child: Text(
                  'Lv. ${progress.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          // XP progress.
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EXPERIENCE',
                style: TextStyle(
                  color: GalaxyColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                '$currentXp / $targetXp XP',
                style: const TextStyle(
                  color: GalaxyColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          LayoutBuilder(
            builder: (context, constraints) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 12,
                  color: GalaxyColors.surfaceLight,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: constraints.maxWidth * fraction,
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
              );
            },
          ),

          const SizedBox(height: 20),

          Divider(
            color: GalaxyColors.border
                .withValues(alpha: 0.7),
          ),

          const SizedBox(height: 13),

          // Dynamic pet mood from the Laravel API.
          Row(
            children: [
              Icon(
                moodIcon,
                color: moodColor,
                size: 22,
              ),

              const SizedBox(width: 9),

              const Text(
                'Mood:',
                style: TextStyle(
                  color: GalaxyColors.textSecondary,
                  fontSize: 13,
                ),
              ),

              const SizedBox(width: 6),

              Text(
                mood,
                style: const TextStyle(
                  color: GalaxyColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const Spacer(),

              const Icon(
                Icons.auto_awesome_rounded,
                color: GalaxyColors.pink,
                size: 18,
              ),
            ],
          ),

          const SizedBox(height: 15),

          // Pet growth stage from Laravel.
          Row(
            children: [
              const Icon(
                Icons.stars_rounded,
                color: GalaxyColors.purple,
                size: 22,
              ),

              const SizedBox(width: 9),

              const Text(
                'Growth Stage:',
                style: TextStyle(
                  color: GalaxyColors.textSecondary,
                  fontSize: 13,
                ),
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  stage,
                  style: const TextStyle(
                    color: GalaxyColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // NEW: Next evolution stage information.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: GalaxyColors.purple
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: GalaxyColors.purple
                    .withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 17,
                  color: GalaxyColors.gold,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    nextStageText,
                    style: const TextStyle(
                      color: GalaxyColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
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

// Draw the floating galaxy island behind the pet.
class _FloatingIslandPainter extends CustomPainter {
  const _FloatingIslandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Glowing atmosphere.
    canvas.drawOval(
      Rect.fromLTWH(
        w * 0.06,
        h * 0.05,
        w * 0.88,
        h * 0.48,
      ),
      Paint()
        ..color = GalaxyColors.purple
            .withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          20,
        ),
    );

    // Lower rocky floating island.
    final lower = Path()
      ..moveTo(w * 0.10, h * 0.28)
      ..lineTo(w * 0.89, h * 0.28)
      ..lineTo(w * 0.78, h * 0.57)
      ..lineTo(w * 0.64, h * 0.72)
      ..lineTo(w * 0.53, h * 0.98)
      ..lineTo(w * 0.40, h * 0.73)
      ..lineTo(w * 0.22, h * 0.60)
      ..close();

    canvas.drawPath(
      lower,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7051CD),
            Color(0xFF3A2875),
            Color(0xFF17183E),
          ],
        ).createShader(
          Offset.zero & size,
        ),
    );

    // Polygon details in the rocky island.
    final leftRock = Path()
      ..moveTo(w * 0.11, h * 0.32)
      ..lineTo(w * 0.38, h * 0.42)
      ..lineTo(w * 0.53, h * 0.98)
      ..lineTo(w * 0.22, h * 0.60)
      ..close();

    canvas.drawPath(
      leftRock,
      Paint()
        ..color = const Color(0xFF48318A)
            .withValues(alpha: 0.7),
    );

    // Top surface.
    final topRect = Rect.fromLTWH(
      w * 0.08,
      h * 0.10,
      w * 0.84,
      h * 0.37,
    );

    canvas.drawOval(
      topRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF8864E6),
            Color(0xFF4A358D),
            Color(0xFF7957D3),
          ],
        ).createShader(topRect),
    );

    // Glowing island edge.
    canvas.drawOval(
      topRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = GalaxyColors.purple,
    );

    // Small crystal decorations.
    _drawCrystal(
      canvas,
      Offset(w * 0.17, h * 0.27),
      19,
      GalaxyColors.blue,
    );

    _drawCrystal(
      canvas,
      Offset(w * 0.81, h * 0.29),
      23,
      GalaxyColors.purple,
    );

    _drawCrystal(
      canvas,
      Offset(w * 0.72, h * 0.39),
      12,
      GalaxyColors.pink,
    );
  }

  void _drawCrystal(
    Canvas canvas,
    Offset center,
    double height,
    Color color,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - height)
      ..lineTo(
        center.dx + height * 0.36,
        center.dy,
      )
      ..lineTo(
        center.dx,
        center.dy + height * 0.22,
      )
      ..lineTo(
        center.dx - height * 0.36,
        center.dy,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.9),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          7,
        ),
    );
  }

  @override
  bool shouldRepaint(
    covariant _FloatingIslandPainter oldDelegate,
  ) {
    return false;
  }
}
