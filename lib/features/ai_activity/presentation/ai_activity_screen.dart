import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/ai_activity/data/dto/ai_activity_analysis_dto.dart';
import 'package:opennutritracker/features/ai_activity/presentation/bloc/ai_activity_bloc.dart';
import 'package:opennutritracker/features/ai_reuse/domain/recent_ai_log.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class AiActivityScreen extends StatefulWidget {
  const AiActivityScreen({super.key});

  @override
  State<AiActivityScreen> createState() => _AiActivityScreenState();
}

class _AiActivityScreenState extends State<AiActivityScreen> {
  final _descriptionController = TextEditingController();
  final _descriptionFormKey = GlobalKey<FormState>();
  late final AiActivityBloc _bloc;
  late DateTime _day;
  bool _initialRecentLogLoaded = false;

  @override
  void initState() {
    super.initState();
    _bloc = locator<AiActivityBloc>();
  }

  @override
  void didChangeDependencies() {
    final args =
        ModalRoute.of(context)?.settings.arguments as AiActivityScreenArguments;
    _day = args.day;
    if (!_initialRecentLogLoaded && args.recentLog != null) {
      _initialRecentLogLoaded = true;
      _bloc.add(UseRecentAiWorkoutRequested(args.recentLog!));
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<AiActivityBloc, AiActivityState>(
        listener: (context, state) {
          if (state.status == AiActivityStatus.saved) {
            locator<HomeBloc>().add(const LoadItemsEvent());
            locator<DiaryBloc>().add(const LoadDiaryYearEvent());
            locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
            final message = S.of(context).aiActivitySavedLabel;
            Navigator.of(
              context,
            ).popUntil(ModalRoute.withName(NavigationOptions.mainRoute));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: palette.canvas,
            appBar: AppBar(
              backgroundColor: palette.canvas,
              title: Text(S.of(context).aiActivityTitle),
              actions: [
                IconButton(
                  tooltip: S.of(context).aiMealAccessTokenTitle,
                  onPressed: () => _showAccessTokenDialog(context),
                  icon: const Icon(Icons.key_rounded),
                ),
              ],
            ),
            body: SafeArea(
              child: switch (state.status) {
                AiActivityStatus.analyzing => _AnalyzingView(
                  label: S.of(context).aiActivityAnalyzingLabel,
                ),
                AiActivityStatus.review ||
                AiActivityStatus.saving => _ReviewView(state: state),
                _ => _DescriptionView(
                  controller: _descriptionController,
                  formKey: _descriptionFormKey,
                  state: state,
                  onAnalyze: _analyze,
                  onSetToken: () => _showAccessTokenDialog(context),
                ),
              },
            ),
            bottomNavigationBar:
                state.status == AiActivityStatus.review ||
                    state.status == AiActivityStatus.saving
                ? _SaveBar(
                    state: state,
                    onSave: () => _bloc.add(
                      SaveAiActivityRequested(
                        _day,
                        S.of(context).aiActivityWorkoutName,
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  void _analyze() {
    if (!(_descriptionFormKey.currentState?.validate() ?? false)) return;
    _bloc.add(
      AnalyzeAiActivityRequested(
        _descriptionController.text,
        Localizations.localeOf(context).toLanguageTag(),
      ),
    );
  }

  Future<void> _showAccessTokenDialog(BuildContext context) async {
    final controller = TextEditingController();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final token = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.of(dialogContext).aiMealAccessTokenTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.of(dialogContext).aiMealAccessTokenBody),
            const SizedBox(height: Dimens.spacing16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: S.of(dialogContext).aiMealAccessTokenLabel,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(S.of(dialogContext).dialogCancelLabel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(S.of(dialogContext).aiMealAccessTokenSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (token == null || token.isEmpty || !mounted) return;
    _bloc.add(AiActivityAccessTokenSubmitted(token, locale));
  }
}

class _DescriptionView extends StatelessWidget {
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final AiActivityState state;
  final VoidCallback onAnalyze;
  final VoidCallback onSetToken;

  const _DescriptionView({
    required this.controller,
    required this.formKey,
    required this.state,
    required this.onAnalyze,
    required this.onSetToken,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListView(
      padding: const EdgeInsets.all(Dimens.spacing16),
      children: [
        Text(
          s.aiActivityIntroTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: Dimens.spacing8),
        Text(s.aiActivityIntroBody),
        const SizedBox(height: Dimens.spacing24),
        Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            minLines: 5,
            maxLines: 9,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: s.aiActivityDescriptionLabel,
              hintText: s.aiActivityDescriptionHint,
              alignLabelWithHint: true,
              filled: true,
            ),
            validator: (value) => (value?.trim().length ?? 0) < 2
                ? s.aiActivityDescriptionError
                : null,
          ),
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: Dimens.spacing8),
          Text(
            state.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (state.authenticationRequired) ...[
          const SizedBox(height: Dimens.spacing8),
          OutlinedButton.icon(
            onPressed: onSetToken,
            icon: const Icon(Icons.key_rounded),
            label: Text(s.aiMealSetAccessTokenButton),
          ),
        ],
        const SizedBox(height: Dimens.spacing16),
        FilledButton.icon(
          onPressed: onAnalyze,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(s.aiActivityAnalyzeButton),
        ),
      ],
    );
  }
}

class _AnalyzingView extends StatelessWidget {
  final String label;

  const _AnalyzingView({required this.label});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Dimens.spacing32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: Dimens.spacing16),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _ReviewView extends StatelessWidget {
  final AiActivityState state;

  const _ReviewView({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bloc = context.read<AiActivityBloc>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Dimens.spacing16,
        Dimens.spacing16,
        Dimens.spacing16,
        120,
      ),
      children: [
        Text(
          s.aiActivityReviewTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: Dimens.spacing8),
        Text(s.aiActivityReviewBody),
        const SizedBox(height: Dimens.spacing16),
        _EstimateSummary(state: state),
        if (state.notes.isNotEmpty) ...[
          const SizedBox(height: Dimens.spacing12),
          AppCard(
            padding: const EdgeInsets.all(Dimens.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.aiMealNotesTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: Dimens.spacing8),
                ...state.notes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: Dimens.spacing4),
                    child: Text(note),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Dimens.spacing16),
        ...List.generate(
          state.exercises.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: Dimens.spacing12),
            child: _ExerciseEditor(
              key: ValueKey('${state.exercises[index].originalText}-$index'),
              index: index,
              exercise: state.exercises[index],
              enabled: state.status == AiActivityStatus.review,
              onChanged: (exercise) =>
                  bloc.add(AiActivityExerciseChanged(index, exercise)),
              onRemove: () => bloc.add(AiActivityExerciseRemoved(index)),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: state.status == AiActivityStatus.review
              ? () => bloc.add(const AiActivityExerciseAdded())
              : null,
          icon: const Icon(Icons.add_rounded),
          label: Text(s.aiActivityAddExercise),
        ),
        if (state.exercises.isEmpty)
          Text(
            s.aiActivityEmptyExercises,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: Dimens.spacing8),
          Text(
            state.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _EstimateSummary extends StatelessWidget {
  final AiActivityState state;

  const _EstimateSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final calories = state.estimatedCalories ?? 0;
    return AppCard(
      padding: const EdgeInsets.all(Dimens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.aiActivityEstimateTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Dimens.spacing12),
          TextFormField(
            initialValue: state.durationMinutes?.toStringAsFixed(1),
            enabled: state.status == AiActivityStatus.review,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: s.aiActivityDurationLabel,
              suffixText: s.aiActivityMinutesUnit,
              helperText: state.durationWasEstimated
                  ? s.aiActivityDurationEstimateHelper
                  : s.aiActivityDurationConfirmedHelper,
              helperMaxLines: 3,
            ),
            onChanged: (value) => context.read<AiActivityBloc>().add(
              AiActivityDurationChanged(
                double.tryParse(value.replaceAll(',', '.')),
              ),
            ),
          ),
          const SizedBox(height: Dimens.spacing16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.aiActivityEnergyLabel,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      '~${EnergyDisplay.formatWithUnit(context, calories)}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.local_fire_department_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 34,
              ),
            ],
          ),
          const SizedBox(height: Dimens.spacing8),
          Text(
            '${state.profileWeightKg?.toStringAsFixed(1) ?? '—'} kg • '
            '${AiActivityState.resistanceTrainingMet.toStringAsFixed(1)} MET',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Dimens.spacing4),
          Text(
            s.aiActivityEstimateSource,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ExerciseEditor extends StatefulWidget {
  final int index;
  final AiExtractedExercise exercise;
  final bool enabled;
  final ValueChanged<AiExtractedExercise> onChanged;
  final VoidCallback onRemove;

  const _ExerciseEditor({
    super.key,
    required this.index,
    required this.exercise,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<_ExerciseEditor> {
  late final TextEditingController _name;
  late final TextEditingController _sets;
  late final TextEditingController _reps;
  late final TextEditingController _load;
  late String _loadUnit;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.exercise.canonicalName);
    _sets = TextEditingController(text: widget.exercise.sets?.toString());
    _reps = TextEditingController(text: widget.exercise.repsPerSet?.toString());
    _load = TextEditingController(text: widget.exercise.loadValue?.toString());
    _loadUnit = widget.exercise.loadUnit ?? 'kg';
  }

  @override
  void dispose() {
    _name.dispose();
    _sets.dispose();
    _reps.dispose();
    _load.dispose();
    super.dispose();
  }

  void _emit() {
    final load = double.tryParse(_load.text.replaceAll(',', '.'));
    final sets = int.tryParse(_sets.text);
    final reps = int.tryParse(_reps.text);
    final isBodyweight = _loadUnit == 'bodyweight';
    widget.onChanged(
      widget.exercise.copyWith(
        canonicalName: _name.text.trim(),
        sets: sets,
        clearSets: sets == null,
        repsPerSet: reps,
        clearReps: reps == null,
        loadValue: isBodyweight ? null : load,
        loadUnit: isBodyweight
            ? 'bodyweight'
            : (load == null ? null : _loadUnit),
        clearLoadValue: isBodyweight,
        clearLoad: !isBodyweight && load == null,
        requiresUserConfirmation: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AppCard(
      padding: const EdgeInsets.all(Dimens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${s.aiActivityExerciseLabel} ${widget.index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: s.aiActivityRemoveExercise,
                onPressed: widget.enabled ? widget.onRemove : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          TextField(
            controller: _name,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s.aiActivityExerciseName),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: Dimens.spacing8),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  controller: _sets,
                  label: s.aiActivitySetsLabel,
                ),
              ),
              const SizedBox(width: Dimens.spacing8),
              Expanded(
                child: _numberField(
                  controller: _reps,
                  label: s.aiActivityRepsLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimens.spacing8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _load,
                  enabled: widget.enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(labelText: s.aiActivityLoadLabel),
                  onChanged: (_) => _emit(),
                ),
              ),
              const SizedBox(width: Dimens.spacing8),
              SizedBox(
                width: 124,
                child: DropdownButtonFormField<String>(
                  initialValue: _loadUnit,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: 'kg', child: Text('kg')),
                    const DropdownMenuItem(value: 'lb', child: Text('lb')),
                    DropdownMenuItem(
                      value: 'bodyweight',
                      child: Text(s.aiActivityBodyweightUnitLabel),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: s.aiActivityLoadUnitLabel,
                  ),
                  onChanged: widget.enabled
                      ? (value) {
                          if (value == null) return;
                          setState(() {
                            _loadUnit = value;
                            if (value == 'bodyweight') _load.clear();
                          });
                          _emit();
                        }
                      : null,
                ),
              ),
            ],
          ),
          if (widget.exercise.requiresUserConfirmation) ...[
            const SizedBox(height: Dimens.spacing8),
            Text(
              s.aiMealNeedsReviewLabel,
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
  }) => TextField(
    controller: controller,
    enabled: widget.enabled,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label),
    onChanged: (_) => _emit(),
  );
}

class _SaveBar extends StatelessWidget {
  final AiActivityState state;
  final VoidCallback onSave;

  const _SaveBar({required this.state, required this.onSave});

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(Dimens.spacing16),
        child: FilledButton.icon(
          onPressed: state.canSave ? onSave : null,
          icon: state.status == AiActivityStatus.saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(
            state.status == AiActivityStatus.saving
                ? S.of(context).aiActivitySavingLabel
                : S.of(context).aiActivitySaveLabel,
          ),
        ),
      ),
    ),
  );
}

class AiActivityScreenArguments {
  final DateTime day;
  final RecentAiWorkoutLog? recentLog;

  const AiActivityScreenArguments({required this.day, this.recentLog});
}
