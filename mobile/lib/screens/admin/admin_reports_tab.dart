import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../models/admin.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/galaxy_page.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class AdminReportsTab extends ConsumerStatefulWidget {
  const AdminReportsTab({super.key});

  @override
  ConsumerState<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends ConsumerState<AdminReportsTab>
    with AutomaticKeepAliveClientMixin {
  String _period = 'week';
  DateTime _date = DateTime.now();
  late Future<AdminReport> _report = _fetch();

  @override
  bool get wantKeepAlive => true;

  Future<AdminReport> _fetch() =>
      ref.read(adminRepositoryProvider).fetchReport(period: _period, date: _date);

  void _reload() => setState(() => _report = _fetch());

  void _move(int steps) {
    setState(() {
      _date = _period == 'month'
          ? DateTime(_date.year, _date.month + steps, 1)
          : DateTime(_date.year, _date.month, _date.day + 7 * steps);
      _report = _fetch();
    });
  }

  bool get _isCurrent {
    final now = DateTime.now();
    if (_period == 'month') return _date.year == now.year && _date.month == now.month;
    DateTime monday(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));
    return monday(_date) == monday(now);
  }

  String _range(AdminReport r) {
    if (r.period == 'month') return '${_months[r.startDate.month - 1]} ${r.startDate.year}';
    return '${_months[r.startDate.month - 1]} ${r.startDate.day} – '
        '${_months[r.endDate.month - 1]} ${r.endDate.day}, ${r.endDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      color: GalaxyColors.purple,
      backgroundColor: GalaxyColors.surface,
      onRefresh: () async => _reload(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'week', label: Text('Week')),
              ButtonSegment(value: 'month', label: Text('Month')),
            ],
            selected: {_period},
            onSelectionChanged: (value) {
              setState(() {
                _period = value.first;
                _date = DateTime.now();
                _report = _fetch();
              });
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<AdminReport>(
            future: _report,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return galaxyLoading;
              if (snapshot.hasError) {
                final error = snapshot.error;
                return GalaxyError(
                  message: error is ApiException ? error.message : 'Could not load the report.',
                  onRetry: _reload,
                );
              }
              final r = snapshot.data!;
              final hours = r.totalMinutes ~/ 60;
              final minutes = r.totalMinutes % 60;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GalaxyCard(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous',
                          onPressed: () => _move(-1),
                          icon: const Icon(Icons.chevron_left_rounded, color: GalaxyColors.textPrimary),
                        ),
                        Expanded(
                          child: Text(
                            _range(r),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: GalaxyColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next',
                          onPressed: _isCurrent ? null : () => _move(1),
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color: _isCurrent ? GalaxyColors.border : GalaxyColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.7,
                    children: [
                      _Stat(icon: Icons.people_alt_rounded, value: '${r.activeStudents} / ${r.totalStudents}', label: 'Active students'),
                      _Stat(icon: Icons.person_add_alt_1_rounded, value: '${r.newStudents}', label: 'New students'),
                      _Stat(icon: Icons.timer_rounded, value: '${r.sessions}', label: 'Focus sessions'),
                      _Stat(icon: Icons.hourglass_bottom_rounded, value: hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m', label: 'Minutes studied'),
                      _Stat(icon: Icons.task_alt_rounded, value: '${r.tasksCompleted}', label: 'Tasks completed'),
                      _Stat(icon: Icons.bolt_rounded, value: '${r.xpAwarded}', label: 'XP awarded'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GalaxyCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Badges awarded (${r.badgesAwarded})',
                          style: const TextStyle(color: GalaxyColors.textPrimary, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        if (r.badges.isEmpty)
                          const Text(
                            'No badges were awarded in this period.',
                            style: TextStyle(color: GalaxyColors.textSecondary, fontSize: 12),
                          )
                        else
                          for (final badge in r.badges)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.emoji_events_rounded, color: GalaxyColors.gold, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(badge.key, style: const TextStyle(color: GalaxyColors.textPrimary)),
                                  ),
                                  Text(
                                    '${badge.value}',
                                    style: const TextStyle(color: GalaxyColors.textPrimary, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Reports show totals only. A student counts as active if they earned XP in the period.',
                    style: TextStyle(color: GalaxyColors.textSecondary, fontSize: 11),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GalaxyCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: GalaxyColors.purple, size: 20),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(color: GalaxyColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
