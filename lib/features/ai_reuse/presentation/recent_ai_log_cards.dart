import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/features/ai_reuse/domain/recent_ai_log.dart';
import 'package:opennutritracker/generated/l10n.dart';

class RecentAiSectionHeader extends StatelessWidget {
  final String title;

  const RecentAiSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Dimens.spacing4,
      Dimens.spacing8,
      Dimens.spacing4,
      Dimens.spacing8,
    ),
    child: Row(
      children: [
        Icon(
          Icons.history_rounded,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: Dimens.spacing8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class RecentAiMealCard extends StatelessWidget {
  final RecentAiMealLog log;
  final VoidCallback onTap;

  const RecentAiMealCard({super.key, required this.log, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final names = log.intakes
        .map((intake) => intake.meal.name?.trim())
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final title = names.isEmpty
        ? S.of(context).aiMealTitle
        : names.take(2).join(' + ');
    final moreCount = names.length - 2;
    final visibleTitle = moreCount > 0 ? '$title +$moreCount' : title;
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(log.loggedAt);

    return _RecentAiCard(
      icon: Icons.restaurant_rounded,
      title: visibleTitle,
      metadata:
          '${S.of(context).recentAiFoodCountLabel(log.intakes.length)} • '
          '${EnergyDisplay.formatWithUnit(context, log.totalKcal)} • $date',
      onTap: onTap,
    );
  }
}

class RecentAiWorkoutCard extends StatelessWidget {
  final RecentAiWorkoutLog log;
  final VoidCallback onTap;

  const RecentAiWorkoutCard({
    super.key,
    required this.log,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final exercises = log.details.exercises;
    final names = exercises
        .map((exercise) => exercise.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final title = names.isEmpty ? log.name : names.take(2).join(' + ');
    final moreCount = names.length - 2;
    final visibleTitle = moreCount > 0 ? '$title +$moreCount' : title;
    final minutes = log.durationMinutes;
    final duration = minutes == minutes.roundToDouble()
        ? minutes.toStringAsFixed(0)
        : minutes.toStringAsFixed(1);
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(log.loggedAt);

    return _RecentAiCard(
      icon: Icons.fitness_center_rounded,
      title: visibleTitle,
      metadata:
          '${S.of(context).recentAiExerciseCountLabel(exercises.length)} • '
          '$duration ${S.of(context).aiActivityMinutesUnit} • $date',
      onTap: onTap,
    );
  }
}

class _RecentAiCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String metadata;
  final VoidCallback onTap;

  const _RecentAiCard({
    required this.icon,
    required this.title,
    required this.metadata,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.spacing8),
      child: Semantics(
        button: true,
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.all(Dimens.spacing12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: Dimens.borderRadiusS,
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: Dimens.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Dimens.spacing4),
                    Text(
                      metadata,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.textMuted),
                    ),
                    const SizedBox(height: Dimens.spacing4),
                    Text(
                      S.of(context).recentAiReviewAndAddLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Dimens.spacing8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
