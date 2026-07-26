import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/ai_meal/data/ai_meal_photo_picker.dart';
import 'package:opennutritracker/features/ai_meal/data/dto/ai_meal_analysis_dto.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_draft_item.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_photo.dart';
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

enum _AiMealInputMode { text, photo }

class AiMealScreen extends StatefulWidget {
  final AiMealPhotoPicker? photoPicker;

  const AiMealScreen({super.key, this.photoPicker});

  @override
  State<AiMealScreen> createState() => _AiMealScreenState();
}

class _AiMealScreenState extends State<AiMealScreen> {
  final _descriptionController = TextEditingController();
  final _correctionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _correctionFormKey = GlobalKey<FormState>();
  late final AiMealBloc _bloc;
  late final AiMealPhotoPicker _photoPicker;
  late AiMealScreenArguments _arguments;
  _AiMealInputMode _inputMode = _AiMealInputMode.text;
  AiMealPhoto? _selectedPhoto;
  String? _photoPickerError;

  @override
  void initState() {
    super.initState();
    _bloc = locator<AiMealBloc>();
    _photoPicker = widget.photoPicker ?? locator<AiMealPhotoPicker>();
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
    _correctionController.dispose();
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
                  state.status == AiMealStatus.refining ||
                  state.status == AiMealStatus.saving
              ? _buildSaveBar(context, state)
              : null,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AiMealState state) {
    if (state.status == AiMealStatus.analyzing) {
      return _AnalyzingView(
        key: const ValueKey('analyzing'),
        photo: state.photo,
      );
    }
    if (state.status == AiMealStatus.review ||
        state.status == AiMealStatus.refining ||
        state.status == AiMealStatus.saving) {
      return _buildReview(context, state);
    }
    return _buildDescription(context, state);
  }

  Widget _buildDescription(BuildContext context, AiMealState state) {
    final palette = _palette(context);
    final isPhoto = _inputMode == _AiMealInputMode.photo;
    final stateErrorMatchesMode = isPhoto == (state.photo != null);
    return SingleChildScrollView(
      key: const ValueKey('description'),
      padding: const EdgeInsets.all(Dimens.spacing16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Dimens.spacing8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_AiMealInputMode>(
                segments: [
                  ButtonSegment(
                    value: _AiMealInputMode.text,
                    icon: const Icon(Icons.notes_rounded),
                    label: Text(S.of(context).aiMealInputTextLabel),
                  ),
                  ButtonSegment(
                    value: _AiMealInputMode.photo,
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: Text(S.of(context).aiMealInputPhotoLabel),
                  ),
                ],
                selected: {_inputMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() {
                    _inputMode = selection.first;
                    _photoPickerError = null;
                  });
                },
              ),
            ),
            const SizedBox(height: Dimens.spacing24),
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
                isPhoto
                    ? Icons.add_a_photo_rounded
                    : Icons.auto_awesome_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: Dimens.spacing20),
            Text(
              isPhoto
                  ? S.of(context).aiMealPhotoIntroTitle
                  : S.of(context).aiMealIntroTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: Dimens.spacing8),
            Text(
              isPhoto
                  ? S.of(context).aiMealPhotoIntroBody
                  : S.of(context).aiMealIntroBody,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: palette.textMuted),
            ),
            const SizedBox(height: Dimens.spacing24),
            if (isPhoto)
              _buildPhotoInput(context)
            else
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
            if (_photoPickerError != null && isPhoto) ...[
              const SizedBox(height: Dimens.spacing12),
              _ErrorPanel(message: _photoPickerError!),
            ],
            if (state.errorMessage != null && stateErrorMatchesMode) ...[
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
                onPressed: isPhoto ? _submitPhoto : _submitDescription,
                icon: Icon(
                  isPhoto
                      ? Icons.center_focus_strong_rounded
                      : Icons.auto_awesome_rounded,
                ),
                label: Text(
                  isPhoto
                      ? S.of(context).aiMealAnalyzePhotoButton
                      : S.of(context).aiMealAnalyzeButton,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoInput(BuildContext context) {
    final photo = _selectedPhoto;
    if (photo == null) {
      return AppCard(
        padding: const EdgeInsets.all(Dimens.spacing20),
        child: Column(
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: Dimens.spacing12),
            Text(
              S.of(context).aiMealPhotoEmptyLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Dimens.spacing16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded),
                label: Text(S.of(context).aiMealTakePhotoButton),
              ),
            ),
            const SizedBox(height: Dimens.spacing8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(S.of(context).aiMealChoosePhotoButton),
              ),
            ),
            const SizedBox(height: Dimens.spacing12),
            Text(
              S.of(context).aiMealPhotoPrivacyLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          image: true,
          label: S.of(context).aiMealPhotoPreviewLabel,
          child: ClipRRect(
            borderRadius: Dimens.borderRadiusM,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.file(
                File(photo.path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, size: 48),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Dimens.spacing12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(S.of(context).aiMealRetakePhotoButton),
              ),
            ),
            const SizedBox(width: Dimens.spacing8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(S.of(context).aiMealChooseAnotherPhotoButton),
              ),
            ),
          ],
        ),
        const SizedBox(height: Dimens.spacing8),
        Text(
          S.of(context).aiMealPhotoPrivacyLabel,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
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
        if (state.photo != null) ...[
          const SizedBox(height: Dimens.spacing16),
          _PhotoReviewBanner(photo: state.photo!),
          const SizedBox(height: Dimens.spacing16),
          _AiMealCorrectionCard(
            formKey: _correctionFormKey,
            controller: _correctionController,
            history: state.correctionHistory,
            pendingCorrection: state.pendingCorrection,
            isLoading: state.status == AiMealStatus.refining,
            onSend: _submitCorrection,
          ),
        ],
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
          _ErrorPanel(
            message: state.errorMessage!,
            showTokenAction: state.authenticationRequired,
            onTokenPressed: () => _showAccessTokenDialog(state),
          ),
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
            enabled: !state.isReviewBusy,
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
          icon:
              state.status == AiMealStatus.saving ||
                  state.status == AiMealStatus.refining
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(switch (state.status) {
            AiMealStatus.saving => S.of(context).aiMealSavingLabel,
            AiMealStatus.refining => S.of(context).aiMealRefiningSaveLabel,
            _ => S.of(context).aiMealSaveButton,
          }),
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

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _photoPickerError = null);
    try {
      final photo = await _photoPicker.pick(source);
      if (!mounted || photo == null) return;
      setState(() {
        _selectedPhoto = photo;
        _photoPickerError = null;
      });
    } on AiMealPhotoPickerException catch (error) {
      if (!mounted) return;
      setState(() => _photoPickerError = error.message);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _photoPickerError = S.of(context).aiMealPhotoPickerError);
    }
  }

  void _submitPhoto() {
    final photo = _selectedPhoto;
    if (photo == null) {
      setState(
        () => _photoPickerError = S.of(context).aiMealPhotoRequiredError,
      );
      return;
    }
    setState(() => _photoPickerError = null);
    _bloc.add(
      AnalyzeAiMealPhotoRequested(
        photo: photo,
        locale: Localizations.localeOf(context).toLanguageTag(),
      ),
    );
  }

  void _submitCorrection() {
    if (!(_correctionFormKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _bloc.add(
      RefineAiMealPhotoRequested(
        correction: _correctionController.text,
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
    if (state.status == AiMealStatus.review &&
        state.correctionHistory.isNotEmpty &&
        _correctionController.text.trim() ==
            state.correctionHistory.last.instruction) {
      _correctionController.clear();
    }
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
  final AiMealPhoto? photo;

  const _AnalyzingView({super.key, this.photo});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (photo == null)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: 240,
                child: ClipRRect(
                  borderRadius: Dimens.borderRadiusL,
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(photo!.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                          ),
                        ),
                        ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.scrim.withValues(alpha: 0.38),
                        ),
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: Dimens.spacing20),
            Text(
              photo == null
                  ? S.of(context).aiMealAnalyzingLabel
                  : S.of(context).aiMealPhotoAnalyzingLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoReviewBanner extends StatelessWidget {
  final AiMealPhoto photo;

  const _PhotoReviewBanner({required this.photo});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          Widget photoPreview(BorderRadius borderRadius) => Semantics(
            image: true,
            label: S.of(context).aiMealPhotoPreviewLabel,
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Image.file(
                File(photo.path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          );
          final reviewCopy = Padding(
            padding: const EdgeInsets.all(Dimens.spacing16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: Dimens.spacing8),
                Text(
                  S.of(context).aiMealPhotoReviewNotice,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );

          if (constraints.maxWidth < 330) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 7,
                  child: photoPreview(
                    const BorderRadius.vertical(
                      top: Radius.circular(Dimens.radiusL),
                    ),
                  ),
                ),
                reviewCopy,
              ],
            );
          }

          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 144),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 112,
                    child: photoPreview(
                      const BorderRadius.horizontal(
                        left: Radius.circular(Dimens.radiusL),
                      ),
                    ),
                  ),
                  Expanded(child: reviewCopy),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AiMealCorrectionCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final List<AiMealCorrectionTurn> history;
  final String? pendingCorrection;
  final bool isLoading;
  final VoidCallback onSend;

  const _AiMealCorrectionCard({
    required this.formKey,
    required this.controller,
    required this.history,
    required this.pendingCorrection,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(Dimens.spacing16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.14),
                    borderRadius: Dimens.borderRadiusS,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: Dimens.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).aiMealRefineTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: Dimens.spacing4),
                      Text(
                        S.of(context).aiMealRefineBody,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimens.spacing16),
            if (history.isEmpty)
              Text(
                S.of(context).aiMealRefineExample,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              )
            else
              for (final turn in history) ...[
                _AiCorrectionBubble(
                  label: S.of(context).aiMealRefineUserLabel,
                  message: turn.instruction,
                  isUser: true,
                ),
                const SizedBox(height: Dimens.spacing8),
                _AiCorrectionBubble(
                  label: S.of(context).aiMealRefineAssistantLabel,
                  message: turn.assistantMessage,
                  isUser: false,
                ),
                const SizedBox(height: Dimens.spacing12),
              ],
            if (isLoading && pendingCorrection != null) ...[
              _AiCorrectionBubble(
                label: S.of(context).aiMealRefineUserLabel,
                message: pendingCorrection!,
                isUser: true,
              ),
              const SizedBox(height: Dimens.spacing12),
            ],
            const SizedBox(height: Dimens.spacing12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    enabled: !isLoading,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: S.of(context).aiMealRefineInputLabel,
                      hintText: S.of(context).aiMealRefineInputHint,
                      counterText: '',
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? S.of(context).aiMealRefineRequiredError
                        : null,
                  ),
                ),
                const SizedBox(width: Dimens.spacing8),
                IconButton.filled(
                  tooltip: S.of(context).aiMealRefineSendTooltip,
                  onPressed: isLoading ? null : onSend,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
            if (isLoading) ...[
              const SizedBox(height: Dimens.spacing12),
              Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: Dimens.spacing8),
                    Text(
                      S.of(context).aiMealRefineLoadingLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiCorrectionBubble extends StatelessWidget {
  final String label;
  final String message;
  final bool isUser;

  const _AiCorrectionBubble({
    required this.label,
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: $message',
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.spacing12,
            vertical: Dimens.spacing8,
          ),
          decoration: BoxDecoration(
            color: isUser
                ? colors.primaryContainer
                : colors.surfaceContainerHighest,
            borderRadius: Dimens.borderRadiusM,
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: Dimens.spacing4),
                Text(message),
              ],
            ),
          ),
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
  final bool enabled;

  const _AiDraftCard({
    super.key,
    required this.item,
    required this.index,
    required this.onAmountChanged,
    required this.onCandidateSelected,
    required this.onMatchRequested,
    required this.onRemove,
    required this.enabled,
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
                            onPressed: widget.enabled ? widget.onRemove : null,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: Dimens.spacing8),
                      _statusChip(context, item, statusColor),
                      const SizedBox(height: Dimens.spacing16),
                      TextField(
                        controller: _queryController,
                        enabled: widget.enabled,
                        textInputAction: TextInputAction.search,
                        onSubmitted: widget.onMatchRequested,
                        decoration: InputDecoration(
                          labelText: S.of(context).aiMealFoodSearchLabel,
                          suffixIcon: IconButton(
                            tooltip: S.of(context).aiMealSearchMatchTooltip,
                            onPressed: item.isResolving || !widget.enabled
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
                          onChanged: widget.enabled
                              ? (value) {
                                  if (value != null) {
                                    widget.onCandidateSelected(value);
                                  }
                                }
                              : null,
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
                        enabled: widget.enabled,
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
