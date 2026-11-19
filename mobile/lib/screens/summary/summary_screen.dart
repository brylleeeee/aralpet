import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../models/weekly_summary.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/galaxy_page.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

String _time(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  // Monday of the week being shown.
  late DateTime _weekOf = _mondayOf(DateTime.now());

  static DateTime _mondayOf(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  bool get _isThisWeek => _weekOf == _mondayOf(DateTime.now());

  void _moveWeek(int weeks) {
    setState(() {
      // Calendar arithmetic keeps midnight even across DST changes.
      _weekOf = DateTime(_weekOf.year, _weekOf.month, _weekOf.day + 7 * weeks);
    });
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(weeklySummaryProvider(_weekOf));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          color: GalaxyColors.purple,
          backgroundColor: GalaxyColors.surface,
          onRefresh: () => ref.refresh(weeklySummaryProvider(_weekOf).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 16, 20, 40),
            children: [
              const GalaxyPageHeader(
                title: 'Weekly Summary',
                subtitle: 'Your study effort, day by day',
                icon: Icons.bar_chart_rounded,
                iconColor: GalaxyColors.blue,
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WeekPicker(
                      weekOf: _weekOf,
                      isThisWeek: _isThisWeek,
                      onPrevious: () => _moveWeek(-1),
                      onNext: _isThisWeek ? null : () => _moveWeek(1),
                    ),
                    const SizedBox(height: 14),
                    summaryAsync.when(
                      loading: () => galaxyLoading,
                      error: (error, _) => GalaxyError(
                        message: error is ApiException
                            ? error.message
                            : 'Could not load the weekly summary.',
                        onRetry: () => ref.invalidate(weeklySummaryProvider(_weekOf)),
                      ),
                      data: (summary) => _SummaryBody(summary: summary),
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

class _WeekPicker extends StatelessWidget {
  const _WeekPicker({
    required this.weekOf,
    required this.isThisWeek,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime weekOf;
  final bool isThisWeek;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final end = DateTime(weekOf.year, weekOf.month, weekOf.day + 6);

    return GalaxyCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous week',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded, color: GalaxyColors.textPrimary),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  isThisWeek ? 'This week' : 'Week of ${_shortDate(weekOf)}',
                  style: const TextStyle(
                    color: GalaxyColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${_shortDate(weekOf)} – ${_shortDate(end)}, ${end.year}',
                  style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next week',
            onPressed: onNext,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: onNext == null ? GalaxyColors.border : GalaxyColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.summary});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final hours = summary.totalMinutes ~/ 60;
    final minutes = summary.totalMinutes % 60;
    final studied = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Totals
        Row(
          children: [
            Expanded(child: _Total(value: studied, label: 'Studied')),
            const SizedBox(width: 8),
            Expanded(child: _Total(value: '${summary.totalSessions}', label: 'Sessions')),
            const SizedBox(width: 8),
            Expanded(child: _Total(value: '${summary.totalTasks}', label: 'Tasks done')),
            const SizedBox(width: 8),
            Expanded(child: _Total(value: '${summary.totalXp}', label: 'XP')),
          ],
        ),
        const SizedBox(height: 14),

        // Chart: minutes studied per day
        GalaxyCard(
          padding: const EdgeInsets.fromLTRB(12, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Minutes studied per day',
                  style: TextStyle(
                    color: GalaxyColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(height: 190, child: _MinutesChart(days: summary.days)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Table view of the same numbers
        GalaxyCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              const _DayRow(day: 'Day', minutes: 'Min', sessions: 'Sessions', tasks: 'Tasks', xp: 'XP', header: true),
              for (final day in summary.days)
                _DayRow(
                  day: '${day.day} ${day.date.day}',
                  minutes: '${day.minutes}',
                  sessions: '${day.sessions}',
                  tasks: '${day.tasksCompleted}',
                  xp: '${day.xp}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _ItemList(
          title: 'Focus sessions',
          icon: Icons.timer_rounded,
          empty: 'No sessions of 10 minutes or more this week.',
          items: summary.sessions,
          trailing: (item) => '${item.minutes ?? 0} min',
        ),
        const SizedBox(height: 14),
        _ItemList(
          title: 'Completed tasks',
          icon: Icons.task_alt_rounded,
          empty: 'No tasks completed this week.',
          items: summary.tasks,
          trailing: (item) => '',
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GalaxyCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: GalaxyColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// One series, so one color and no legend; the card title names it.
class _MinutesChart extends StatelessWidget {
  const _MinutesChart({required this.days});

  final List<SummaryDay> days;

  @override
  Widget build(BuildContext context) {
    final most = days.fold<int>(0, (m, d) => math.max(m, d.minutes));
    // Round the top of the axis up to a multiple of 30 minutes.
    final maxY = math.max(30, ((most + 29) ~/ 30) * 30).toDouble();
    final step = maxY <= 60 ? 15.0 : (maxY <= 180 ? 30.0 : 60.0);

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (_) => FlLine(
            color: GalaxyColors.border.withValues(alpha: 0.35),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: step,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    days[i].day,
                    style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => GalaxyColors.surfaceLight,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = days[group.x];
              return BarTooltipItem(
                '${day.day}: ${day.minutes} min\n${day.sessions} sessions',
                const TextStyle(
                  color: GalaxyColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].minutes.toDouble(),
                  width: 18,
                  color: GalaxyColors.purple,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.minutes,
    required this.sessions,
    required this.tasks,
    required this.xp,
    this.header = false,
  });

  final String day;
  final String minutes;
  final String sessions;
  final String tasks;
  final String xp;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: header ? GalaxyColors.textSecondary : GalaxyColors.textPrimary,
      fontSize: header ? 11 : 13,
      fontWeight: header ? FontWeight.w700 : FontWeight.w500,
    );

    Widget cell(String text, {int flex = 2, TextAlign align = TextAlign.right}) =>
        Expanded(flex: flex, child: Text(text, textAlign: align, style: style));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          cell(day, flex: 3, align: TextAlign.left),
          cell(minutes),
          cell(sessions, flex: 3),
          cell(tasks),
          cell(xp),
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.title,
    required this.icon,
    required this.empty,
    required this.items,
    required this.trailing,
  });

  final String title;
  final IconData icon;
  final String empty;
  final List<SummaryItem> items;
  final String Function(SummaryItem) trailing;

  @override
  Widget build(BuildContext context) {
    return GalaxyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: GalaxyColors.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                '$title (${items.length})',
                style: const TextStyle(
                  color: GalaxyColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(empty, style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 12))
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: GalaxyColors.textPrimary, fontSize: 13),
                      ),
                    ),
                    if (item.at != null)
                      Text(
                        '${_shortDate(item.at!)}, ${_time(item.at!)}',
                        style: const TextStyle(color: GalaxyColors.textSecondary, fontSize: 11),
                      ),
                    if (trailing(item).isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text(
                        trailing(item),
                        style: const TextStyle(
                          color: GalaxyColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
