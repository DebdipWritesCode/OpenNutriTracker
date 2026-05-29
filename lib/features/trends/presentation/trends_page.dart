import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/trends/presentation/bloc/trends_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class TrendsPage extends StatelessWidget {
  const TrendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TrendsBloc>(
      create: (_) => locator<TrendsBloc>()..add(const LoadTrendsEvent()),
      child: const _TrendsView(),
    );
  }
}

class _TrendsView extends StatelessWidget {
  const _TrendsView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    return BlocBuilder<TrendsBloc, TrendsState>(
      builder: (context, state) {
        if (state is! TrendsLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
              Dimens.spacing16, Dimens.spacing8, Dimens.spacing16, Dimens.spacing32),
          children: [
            _StreakCard(week: state.week, palette: palette),
            const SizedBox(height: Dimens.spacing16),
            _WeeklyCaloriesCard(week: state.week, palette: palette),
            const SizedBox(height: Dimens.spacing16),
            _WeightCard(entries: state.weight, palette: palette),
          ],
        );
      },
    );
  }
}

class _StreakCard extends StatelessWidget {
  final List<TrackedDayEntity> week;
  final AppPalette palette;
  const _StreakCard({required this.week, required this.palette});

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final accent = Theme.of(context).colorScheme.primary;
    final onTrack = week.where((d) => d.getCalendarDayRatingColor(context) != errorColor).length;
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(Dimens.spacing20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Dimens.spacing12),
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(Icons.local_fire_department_rounded, color: accent, size: 28),
          ),
          const SizedBox(width: Dimens.spacing16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$onTrack / 7', style: text.titleLarge),
              Text(S.of(context).trendsDaysOnTrack, style: text.bodyMedium?.copyWith(color: palette.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyCaloriesCard extends StatelessWidget {
  final List<TrackedDayEntity> week;
  final AppPalette palette;
  const _WeeklyCaloriesCard({required this.week, required this.palette});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final byDay = {for (final d in week) DateTime(d.day.year, d.day.month, d.day.day): d};
    final days = [for (int i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final maxVal = days.fold<double>(1, (m, day) {
      final d = byDay[day];
      final v = (d?.caloriesTracked ?? 0) > (d?.calorieGoal ?? 0) ? d!.caloriesTracked : (d?.calorieGoal ?? 0);
      return v > m ? v : m;
    });
    return AppCard(
      padding: const EdgeInsets.all(Dimens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context).trendsCaloriesLabel, style: text.titleMedium),
          const SizedBox(height: Dimens.spacing20),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: _CalBar(
                      tracked: byDay[days[i]]?.caloriesTracked ?? 0,
                      goal: byDay[days[i]]?.calorieGoal ?? 0,
                      maxVal: maxVal,
                      label: weekdayInitials[days[i].weekday - 1],
                      palette: palette,
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

class _CalBar extends StatelessWidget {
  final double tracked;
  final double goal;
  final double maxVal;
  final String label;
  final AppPalette palette;
  const _CalBar({
    required this.tracked,
    required this.goal,
    required this.maxVal,
    required this.label,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    const maxBarHeight = 100.0;
    final h = (tracked / maxVal * maxBarHeight).clamp(2.0, maxBarHeight);
    final over = goal > 0 && tracked > goal;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 14,
          height: h,
          decoration: BoxDecoration(
            color: over ? palette.fatColor : Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        const SizedBox(height: Dimens.spacing8),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _WeightCard extends StatelessWidget {
  final List<WeightLogEntity> entries;
  final AppPalette palette;
  const _WeightCard({required this.entries, required this.palette});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(Dimens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context).weightHistoryWeightLabel, style: text.titleMedium),
          const SizedBox(height: Dimens.spacing20),
          SizedBox(height: 150, child: _buildChart(context)),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (entries.length < 2) {
      return Center(
        child: Text(
          S.of(context).weightHistoryChartEmptyState,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: palette.textMuted),
        ),
      );
    }
    final accent = Theme.of(context).colorScheme.primary;
    final start = entries.first.date;
    final spots = [
      for (final e in entries) FlSpot(e.date.difference(start).inDays.toDouble(), e.weightKg),
    ];
    final ys = spots.map((s) => s.y);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.2).clamp(0.5, 5.0);
    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: accent,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: accent.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }
}
