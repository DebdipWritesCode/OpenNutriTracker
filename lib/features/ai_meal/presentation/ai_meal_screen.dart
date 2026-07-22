import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_draft_item.dart';
import 'package:opennutritracker/features/ai_meal/presentation/bloc/ai_meal_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class AiMealScreenArguments {
  final IntakeTypeEntity intakeType;
  final DateTime day;

  const AiMealScreenArguments({required this.intakeType, required this.day});
}

class AiMealScreen extends StatefulWidget {
  const AiMealScreen({super.key});

  @override
  State<AiMealScreen> createState() => _AiMealScreenState();
}

class _AiMealScreenState extends State<AiMealScreen> {
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final AiMealBloc _bloc;
  late AiMealScreenArguments _arguments;

  @override
  void initState() {
    super.initState();
    _bloc = locator<AiMealBloc>();
  }

  @override
  void didChangeDependencies() {
    _arguments =
        ModalRoute.of(context)!.settings.arguments as AiMealScreenArguments;
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
    return BlocConsumer<AiMealBloc, AiMealState>(
      bloc: _bloc,
      listener: _onStateChanged,
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(S.of(context).aiMealTitle),
            actions: [
              IconButton(
                tooltip: S.of(context).aiMealAccessTokenTitle,
                onPressed: () => _showAccessTokenDialog(state),
                icon: const Icon(Icons.key_rounded),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: AnimatedSwitcher(
              duration: AppMotion.durationShort,
              child: _buildBody(context, state),
            ),
          ),
          bottomNavigationBar:
              state.status == AiMealStatus.review ||
                  state.status == AiMealStatus.saving
              ? _buildSaveBar(context, state)
              : null,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AiMealState state) {
    if (state.status == AiMealStatus.analyzing) {
      return _AnalyzingView(key: const ValueKey('analyzing'));
    }
    if (state.status == AiMealStatus.review ||
        state.status == AiMealStatus.saving) {
      return _buildReview(context, state);
    }
    return _buildDescription(context, state);
  }

  Widget _buildDescription(BuildContext context, AiMealState state) {
    final palette = _palette(context);
    return SingleChildScrollView(
      key: const ValueKey('description'),
      padding: const EdgeInsets.all(Dimens.spacing16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Dimens.spacing8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: Dimens.borderRadiusM,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: Dimens.spacing20),
            Text(
              S.of(context).aiMealIntroTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: Dimens.spacing8),
            Text(
              S.of(context).aiMealIntroBody,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: palette.textMuted),
            ),
            const SizedBox(height: Dimens.spacing24),
            TextFormField(
              controller: _descriptionController,
              minLines: 5,
              maxLines: 9,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: S.of(context).aiMealDescriptionLabel,
                hintText: S.of(context).aiMealDescriptionHint,
                alignLabelWithHint: true,
              ),
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? S.of(context).aiMealDescriptionError
                  : null,
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: Dimens.spacing12),
              _ErrorPanel(
                message: state.errorMessage!,
                showTokenAction: state.authenticationRequired,
                onTokenPressed: () => _showAccessTokenDialog(state),
              ),
            ],
            const SizedBox(height: Dimens.spacing16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitDescription,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(S.of(context).aiMealAnalyzeButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context, AiMealState state) {
    final palette = _palette(context);
    return ListView(
      key: const ValueKey('review'),
      padding: const EdgeInsets.fromLTRB(
        Dimens.spacing16,
        Dimens.spacing8,
        Dimens.spacing16,
        120,
      ),
      children: [
        Text(
          S.of(context).aiMealReviewTitle,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: Dimens.spacing8),
        Text(
          S.of(context).aiMealReviewBody,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: palette.textMuted),
        ),
        if (state.notes.isNotEmpty) ...[
          const SizedBox(height: Dimens.spacing16),
          AppCard(
            padding: const EdgeInsets.all(Dimens.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).aiMealNotesTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Dimens.spacing4),
                for (final note in state.notes)
                  Padding(
                    padding: const EdgeInsets.only(top: Dimens.spacing4),
                    child: Text(note),
                  ),
              ],
            ),
          ),
        ],
        if (state.errorMessage != null) ...[
          const SizedBox(height: Dimens.spacing16),
          _ErrorPanel(message: state.errorMessage!),
        ],
        const SizedBox(height: Dimens.spacing8),
        for (var i = 0; i < state.items.length; i++) ...[
          _AiDraftCard(
            key: ValueKey(state.items[i].extractedFood.originalText),
            item: state.items[i],
            index: i,
            onAmountChanged: (amount) =>
                _bloc.add(AiMealAmountChanged(i, amount)),
            onCandidateSelected: (candidateIndex) =>
                _bloc.add(AiMealCandidateSelected(i, candidateIndex)),
            onMatchRequested: (query) =>
                _bloc.add(AiMealMatchRequested(i, query)),
            onRemove: () => _bloc.add(AiMealItemRemoved(i)),
          ),
          const SizedBox(height: Dimens.spacing12),
        ],
        if (state.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Dimens.spacing32),
            child: Center(child: Text(S.of(context).aiMealEmptyItems)),
          ),
      ],
    );
  }

  Widget _buildSaveBar(BuildContext context, AiMealState state) {
    final palette = _palette(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(Dimens.spacing16),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: FilledButton.icon(
          onPressed: state.canSave
              ? () => _bloc.add(
                  SaveAiMealRequested(
                    intakeType: _arguments.intakeType,
                    day: _arguments.day,
                  ),
                )
              : null,
          icon: state.status == AiMealStatus.saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(
            state.status == AiMealStatus.saving
                ? S.of(context).aiMealSavingLabel
                : S.of(context).aiMealSaveButton,
          ),
        ),
      ),
    );
  }

  void _submitDescription() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _bloc.add(
      AnalyzeAiMealRequested(
        text: _descriptionController.text,
        locale: Localizations.localeOf(context).toLanguageTag(),
      ),
    );
  }

  Future<void> _showAccessTokenDialog(AiMealState state) async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.of(context).aiMealAccessTokenTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.of(context).aiMealAccessTokenBody),
            const SizedBox(height: Dimens.spacing16),
            TextField(
              controller: controller,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: S.of(context).aiMealAccessTokenLabel,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(S.of(context).aiMealAccessTokenSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || token == null || token.trim().isEmpty) return;
    _bloc.add(
      AiAccessTokenSubmitted(
        token: token,
        locale: Localizations.localeOf(context).toLanguageTag(),
      ),
    );
  }

  void _onStateChanged(BuildContext context, AiMealState state) {
    if (state.status != AiMealStatus.saved) return;
    locator<HomeBloc>().add(const LoadItemsEvent());
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(const RefreshCalendarDayEvent());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(S.of(context).aiMealSavedLabel)));
    Navigator.of(
      context,
    ).popUntil(ModalRoute.withName(NavigationOptions.mainRoute));
  }

  AppPalette _palette(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
}

class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: Dimens.spacing20),
            Text(
              S.of(context).aiMealAnalyzingLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final bool showTokenAction;
  final VoidCallback? onTokenPressed;

  const _ErrorPanel({
    required this.message,
    this.showTokenAction = false,
    this.onTokenPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Dimens.spacing16),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.1),
          borderRadius: Dimens.borderRadiusM,
          border: Border.all(color: colors.error.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(color: colors.error)),
            if (showTokenAction) ...[
              const SizedBox(height: Dimens.spacing8),
              TextButton.icon(
                onPressed: onTokenPressed,
                icon: const Icon(Icons.key_rounded),
                label: Text(S.of(context).aiMealSetAccessTokenButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiDraftCard extends StatefulWidget {
  final AiMealDraftItem item;
  final int index;
  final ValueChanged<double?> onAmountChanged;
  final ValueChanged<int> onCandidateSelected;
  final ValueChanged<String> onMatchRequested;
  final VoidCallback onRemove;

  const _AiDraftCard({
    super.key,
    required this.item,
    required this.index,
    required this.onAmountChanged,
    required this.onCandidateSelected,
    required this.onMatchRequested,
    required this.onRemove,
  });

  @override
  State<_AiDraftCard> createState() => _AiDraftCardState();
}

class _AiDraftCardState extends State<_AiDraftCard> {
  late final TextEditingController _queryController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.item.searchQuery);
    _amountController = TextEditingController(
      text: _format(widget.item.amount),
    );
  }

  @override
  void didUpdateWidget(covariant _AiDraftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.searchQuery != widget.item.searchQuery &&
        _queryController.text != widget.item.searchQuery) {
      _queryController.text = widget.item.searchQuery;
    }
    if (oldWidget.item.amount != widget.item.amount &&
        _amountController.text != _format(widget.item.amount)) {
      _amountController.text = _format(widget.item.amount);
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    final statusColor = item.needsAttention
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.primary;

    return Semantics(
      identifier: 'ai-meal-item-${widget.index}',
      child: AppCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(Dimens.radiusL),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
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
                                  item.extractedFood.originalText,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: Dimens.spacing4),
                                Text(
                                  _portionText(item),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: palette.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: S.of(context).aiMealRemoveTooltip,
                            onPressed: widget.onRemove,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: Dimens.spacing8),
                      _statusChip(context, item, statusColor),
                      const SizedBox(height: Dimens.spacing16),
                      TextField(
                        controller: _queryController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: widget.onMatchRequested,
                        decoration: InputDecoration(
                          labelText: S.of(context).aiMealFoodSearchLabel,
                          suffixIcon: IconButton(
                            tooltip: S.of(context).aiMealSearchMatchTooltip,
                            onPressed: item.isResolving
                                ? null
                                : () => widget.onMatchRequested(
                                    _queryController.text,
                                  ),
                            icon: item.isResolving
                                ? const Padding(
                                    padding: EdgeInsets.all(Dimens.spacing12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: Dimens.spacing12),
                      if (item.candidates.isNotEmpty)
                        DropdownButtonFormField<int>(
                          initialValue: item.selectedCandidateIndex,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: S.of(context).aiMealTrustedMatchLabel,
                          ),
                          items: [
                            for (var i = 0; i < item.candidates.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  item.candidates[i].name ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              widget.onCandidateSelected(value);
                            }
                          },
                        )
                      else
                        Text(
                          S.of(context).aiMealNoMatchLabel,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      const SizedBox(height: Dimens.spacing12),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: S.of(context).aiMealAmountLabel,
                          suffixText: item.amountUnit,
                          errorText: item.amount == null || item.amount! <= 0
                              ? S.of(context).aiMealAmountError
                              : null,
                        ),
                        onChanged: (value) => widget.onAmountChanged(
                          double.tryParse(value.replaceAll(',', '.')),
                        ),
                      ),
                      if (item.selectedMeal != null && item.amount != null) ...[
                        const SizedBox(height: Dimens.spacing16),
                        Wrap(
                          spacing: Dimens.spacing8,
                          runSpacing: Dimens.spacing8,
                          children: [
                            _metric(context, '${item.calories.round()} kcal'),
                            _metric(
                              context,
                              '${item.carbohydrates.toStringAsFixed(1)} g ${S.of(context).carbsLabel}',
                            ),
                            _metric(
                              context,
                              '${item.protein.toStringAsFixed(1)} g ${S.of(context).proteinLabel}',
                            ),
                            _metric(
                              context,
                              '${item.fat.toStringAsFixed(1)} g ${S.of(context).fatLabel}',
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(
    BuildContext context,
    AiMealDraftItem item,
    Color statusColor,
  ) {
    final label = item.needsAttention
        ? S.of(context).aiMealNeedsReviewLabel
        : S.of(context).aiMealMatchedLabel;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.spacing12,
        vertical: Dimens.spacing4,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.14),
        borderRadius: Dimens.borderRadiusS,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: statusColor),
      ),
    );
  }

  Widget _metric(BuildContext context, String value) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Dimens.spacing12,
      vertical: Dimens.spacing8,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: Dimens.borderRadiusS,
    ),
    child: Text(value, style: Theme.of(context).textTheme.labelMedium),
  );

  String _portionText(AiMealDraftItem item) {
    final quantity = item.extractedFood.quantity;
    final unit = item.extractedFood.unit;
    if (quantity == null && unit == null) {
      return item.extractedFood.canonicalName;
    }
    return '${quantity == null ? '' : _format(quantity)} ${unit ?? ''}'.trim();
  }

  String _format(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}
