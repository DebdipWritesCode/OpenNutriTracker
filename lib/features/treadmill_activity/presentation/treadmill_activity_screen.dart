import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/domain/entity/activity_log_details.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/physical_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/save_estimated_activity_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/calc/treadmill_energy_calc.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class TreadmillActivityScreen extends StatefulWidget {
  const TreadmillActivityScreen({super.key});

  @override
  State<TreadmillActivityScreen> createState() =>
      _TreadmillActivityScreenState();
}

class _TreadmillActivityScreenState extends State<TreadmillActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _minutesController = TextEditingController(text: '30');
  final _secondsController = TextEditingController(text: '0');
  final _speedController = TextEditingController();
  final _inclineController = TextEditingController(text: '0');

  late TreadmillActivityScreenArguments _arguments;
  TreadmillMode _mode = TreadmillMode.running;
  TreadmillSpeedUnit _speedUnit = TreadmillSpeedUnit.kilometersPerHour;
  UserEntity? _user;
  bool _loading = true;
  bool _saving = false;
  bool _didReadArguments = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadArguments) return;
    _arguments =
        ModalRoute.of(context)!.settings.arguments
            as TreadmillActivityScreenArguments;
    _didReadArguments = true;
    _loadProfile();
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    _speedController.dispose();
    _inclineController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final values = await Future.wait<Object>([
        locator<GetUserUsecase>().getUserData(),
        locator<GetConfigUsecase>().getConfig(),
      ]);
      if (!mounted) return;
      final config = values[1] as ConfigEntity;
      final useMiles = config.usesImperialUnits;
      setState(() {
        _user = values[0] as UserEntity;
        _speedUnit = useMiles
            ? TreadmillSpeedUnit.milesPerHour
            : TreadmillSpeedUnit.kilometersPerHour;
        _speedController.text = useMiles ? '5.0' : '8.0';
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  double? get _durationMinutes {
    final minutes = int.tryParse(_minutesController.text);
    final seconds = int.tryParse(_secondsController.text);
    if (minutes == null ||
        seconds == null ||
        minutes < 0 ||
        seconds < 0 ||
        seconds > 59) {
      return null;
    }
    final total = minutes + seconds / 60;
    return total > 0 ? total : null;
  }

  double? get _speedKph {
    final entered = double.tryParse(_normalise(_speedController.text));
    if (entered == null || entered <= 0) return null;
    return TreadmillEnergyCalc.toKilometersPerHour(entered, _speedUnit);
  }

  double? get _inclinePercent {
    final value = double.tryParse(_normalise(_inclineController.text));
    if (value == null || value < 0 || value > 40) return null;
    return value;
  }

  double? get _estimatedCalories {
    final user = _user;
    final duration = _durationMinutes;
    final speedKph = _speedKph;
    final incline = _inclinePercent;
    if (user == null ||
        duration == null ||
        speedKph == null ||
        speedKph > 30 ||
        incline == null) {
      return null;
    }
    return TreadmillEnergyCalc.calories(
      mode: _mode,
      speedKph: speedKph,
      inclinePercent: incline,
      weightKg: user.weightKG,
      durationMinutes: duration,
    );
  }

  String _normalise(String value) => value.replaceAll(',', '.');

  void _refreshEstimate([Object? _]) {
    if (mounted) setState(() {});
  }

  void _changeSpeedUnit(TreadmillSpeedUnit unit) {
    if (unit == _speedUnit) return;
    final speedKph = _speedKph;
    setState(() {
      _speedUnit = unit;
      if (speedKph != null) {
        _speedController.text = TreadmillEnergyCalc.fromKilometersPerHour(
          speedKph,
          unit,
        ).toStringAsFixed(1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final s = S.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.canvas,
        title: Text(s.treadmillActivityTitle),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _user == null
            ? _ProfileError(message: s.treadmillProfileLoadError)
            : Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Dimens.spacing16,
                    Dimens.spacing16,
                    Dimens.spacing16,
                    120,
                  ),
                  children: [
                    Text(
                      _arguments.activity.getName(context),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: Dimens.spacing8),
                    Text(s.treadmillIntroBody),
                    const SizedBox(height: Dimens.spacing20),
                    _buildMovementCard(context),
                    const SizedBox(height: Dimens.spacing12),
                    _buildWorkoutCard(context),
                    const SizedBox(height: Dimens.spacing12),
                    _buildEstimateCard(context),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: !_loading && _user != null
          ? _buildSaveBar(context)
          : null,
    );
  }

  Widget _buildMovementCard(BuildContext context) {
    final s = S.of(context);
    return AppCard(
      padding: const EdgeInsets.all(Dimens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.treadmillModeLabel,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Dimens.spacing12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TreadmillMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: TreadmillMode.walking,
                  icon: const Icon(Icons.directions_walk_rounded),
                  label: Text(s.treadmillWalkingLabel),
                ),
                ButtonSegment(
                  value: TreadmillMode.running,
                  icon: const Icon(Icons.directions_run_rounded),
                  label: Text(s.treadmillRunningLabel),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() => _mode = selection.single);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(BuildContext context) {
    final s = S.of(context);
    return AppCard(
      padding: const EdgeInsets.all(Dimens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.treadmillDurationTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Dimens.spacing12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: s.treadmillMinutesLabel,
                  ),
                  onChanged: _refreshEstimate,
                  validator: (_) => _durationMinutes == null
                      ? s.treadmillDurationError
                      : null,
                ),
              ),
              const SizedBox(width: Dimens.spacing8),
              Expanded(
                child: TextFormField(
                  controller: _secondsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: s.treadmillSecondsLabel,
                  ),
                  onChanged: _refreshEstimate,
                  validator: (_) => null,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimens.spacing16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _speedController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(labelText: s.treadmillSpeedLabel),
                  onChanged: _refreshEstimate,
                  validator: (_) {
                    final speedKph = _speedKph;
                    return speedKph == null || speedKph > 30
                        ? s.treadmillSpeedError
                        : null;
                  },
                ),
              ),
              const SizedBox(width: Dimens.spacing8),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<TreadmillSpeedUnit>(
                  initialValue: _speedUnit,
                  decoration: InputDecoration(
                    labelText: s.treadmillSpeedUnitLabel,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: TreadmillSpeedUnit.kilometersPerHour,
                      child: Text(s.treadmillKilometersPerHour),
                    ),
                    DropdownMenuItem(
                      value: TreadmillSpeedUnit.milesPerHour,
                      child: Text(s.treadmillMilesPerHour),
                    ),
                  ],
                  onChanged: (unit) {
                    if (unit != null) _changeSpeedUnit(unit);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimens.spacing16),
          TextFormField(
            controller: _inclineController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: s.treadmillInclineLabel,
              suffixText: '%',
            ),
            onChanged: _refreshEstimate,
            validator: (_) =>
                _inclinePercent == null ? s.treadmillInclineError : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateCard(BuildContext context) {
    final s = S.of(context);
    final user = _user!;
    final calories = _estimatedCalories;
    return AppCard(
      padding: const EdgeInsets.all(Dimens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.treadmillEstimateTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Dimens.spacing8),
                    Text(
                      calories == null
                          ? '—'
                          : '~${EnergyDisplay.formatWithUnit(context, calories)}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.monitor_heart_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 34,
              ),
            ],
          ),
          const SizedBox(height: Dimens.spacing12),
          Text(
            '${s.treadmillProfileWeightLabel}: '
            '${user.weightKG.toStringAsFixed(1)} kg',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Dimens.spacing4),
          Text(
            s.treadmillHeightNotUsedLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Dimens.spacing8),
          Text(
            s.treadmillEstimateSource,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(Dimens.spacing16),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(
            _saving
                ? S.of(context).treadmillSavingLabel
                : S.of(context).treadmillSaveLabel,
          ),
        ),
      ),
    ),
  );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final duration = _durationMinutes;
    final speedKph = _speedKph;
    final incline = _inclinePercent;
    final calories = _estimatedCalories;
    final user = _user;
    if (duration == null ||
        speedKph == null ||
        incline == null ||
        calories == null ||
        user == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      final details = ActivityLogDetails(
        kind: ActivityLogKind.treadmill,
        durationSeconds: (duration * 60).round(),
        durationWasEstimated: false,
        profileWeightKg: user.weightKG,
        estimationMethod: 'acsm-treadmill-metabolic-equation',
        treadmillMode: _mode,
        speedKph: speedKph,
        inclinePercent: incline,
        enteredSpeedUnit: _speedUnit,
      );
      await locator<SaveEstimatedActivityUsecase>().save(
        day: _arguments.day,
        activity: _arguments.activity,
        durationMinutes: duration,
        burnedKcal: calories,
        detailsJson: details.encode(),
      );
      if (!mounted) return;
      locator<HomeBloc>().add(const LoadItemsEvent());
      locator<DiaryBloc>().add(const LoadDiaryYearEvent());
      locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
      final message = S.of(context).treadmillSavedLabel;
      Navigator.of(
        context,
      ).popUntil(ModalRoute.withName(NavigationOptions.mainRoute));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.of(context).treadmillSaveError)));
    }
  }
}

class _ProfileError extends StatelessWidget {
  final String message;

  const _ProfileError({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Dimens.spacing32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 40),
          const SizedBox(height: Dimens.spacing12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class TreadmillActivityScreenArguments {
  final PhysicalActivityEntity activity;
  final DateTime day;

  const TreadmillActivityScreenArguments({
    required this.activity,
    required this.day,
  });
}
