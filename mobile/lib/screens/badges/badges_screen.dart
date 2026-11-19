import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../models/badge.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/galaxy_page.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  static const Map<String, IconData> _icons = {
    'sessions_completed': Icons.timer_rounded,
    'streak': Icons.local_fire_department_rounded,
    'tasks_completed': Icons.task_alt_rounded,
    'focus_minutes': Icons.hourglass_bottom_rounded,
    'level': Icons.military_tech_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(badgesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          color: GalaxyColors.purple,
          backgroundColor: GalaxyColors.surface,
          onRefresh: () => ref.refresh(badgesProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 16, 20, 40),
            children: [
              const GalaxyPageHeader(
                title: 'Badges',
                subtitle: 'Milestones you have unlocked',
                icon: Icons.emoji_events_rounded,
                iconColor: GalaxyColors.gold,
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: badgesAsync.when(
                  loading: () => galaxyLoading,
                  error: (error, _) => GalaxyError(
                    message: error is ApiException
                        ? error.message
                        : 'Could not load your badges.',
                    onRetry: () => ref.invalidate(badgesProvider),
                  ),
                  data: (badges) => _BadgeList(badges: badges, icons: _icons),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeList extends StatelessWidget {
  const _BadgeList({required this.badges, required this.icons});

  final List<StudyBadge> badges;
  final Map<String, IconData> icons;

  @override
  Widget build(BuildContext context) {
    final earned = badges.where((b) => b.earned).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$earned of ${badges.length} earned',
          style: const TextStyle(
            color: GalaxyColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        for (final badge in badges) ...[
          _BadgeTile(
            badge: badge,
            icon: icons[badge.conditionType] ?? Icons.star_rounded,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.icon});

  final StudyBadge badge;
  final IconData icon;

  String _date(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final earned = badge.earned;
    final accent = earned ? GalaxyColors.gold : GalaxyColors.textSecondary;

    return Opacity(
      opacity: earned ? 1 : 0.75,
      child: GalaxyCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: earned ? 0.18 : 0.10),
                border: Border.all(color: accent.withValues(alpha: 0.6)),
              ),
              child: Icon(earned ? icon : Icons.lock_rounded, color: accent, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge.name,
                    style: const TextStyle(
                      color: GalaxyColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    badge.description,
                    style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (earned)
                    Text(
                      badge.awardedAt != null
                          ? 'Earned ${_date(badge.awardedAt!)}'
                          : 'Earned',
                      style: const TextStyle(
                        color: GalaxyColors.mint,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: badge.fraction,
                        minHeight: 6,
                        color: GalaxyColors.purple,
                        backgroundColor: GalaxyColors.surfaceLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${badge.current} / ${badge.threshold}',
                      style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
