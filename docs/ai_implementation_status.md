# AI layer implementation status

Last updated: 2026-07-22

## First implementation slice

The first slice establishes the self-hosted backend and a usable text-meal extraction boundary:

```text
meal text
   ↓
POST /api/v1/analyze/text
   ↓
OpenAI structured output (BYOK, store=false)
   ↓
food names + amounts + estimated grams + confidence
   ↓
future nutrition-engine lookup and editable Flutter preview
```

The model is not allowed to calculate nutrition. Calories and macros remain outside the extraction schema and
will be resolved from USDA, Open Food Facts, and Indian food composition data.

Implemented in [`../backend`](../backend):

- FastAPI application factory and versioned API routing.
- SQLite connection lifecycle and readiness checks.
- `GET /health`, Swagger UI at `/docs`, ReDoc at `/redoc`, and OpenAPI JSON.
- Environment configuration, restricted CORS, JSON logs, and request IDs.
- Non-root Docker image and Docker Compose with a persistent SQLite volume.
- Privacy-first per-request `X-OpenAI-API-Key`, with an optional server-side key for single-user installs.
- Structured Responses API parsing with `gpt-5.4-mini`, then `gpt-5.4` on a transient/model-availability failure.
- Indian serving vocabulary in the extraction prompt and explicit confirmation flags for uncertain portions.
- Backend lint and API tests, including health, CORS, validation, BYOK, privacy flags, and model fallback.

## Existing Flutter architecture audit

### Startup and navigation

- `main()` initializes logging and the GetIt locator, opens encrypted Hive storage, initializes Supabase, then
  chooses onboarding or the main shell based on local user data.
- Named routes are registered in `lib/main.dart`. `MainScreen` owns the persistent bottom navigation; feature
  screens are pushed with `NavigationOptions` route names.
- The existing AI entry point should be added as a new feature route rather than coupled to the main shell.

### State management and dependency injection

- Features use `flutter_bloc`, with events/states colocated under each feature's `presentation/bloc` directory.
- GetIt registrations in `lib/core/utils/locator.dart` distinguish persistent BLoCs (`registerLazySingleton`) from
  navigation-scoped BLoCs and services (`registerFactory`).
- The AI logging flow should follow the same three-layer feature structure and use a navigation-scoped BLoC.

### Local storage and privacy

- User data is stored in AES-encrypted `hive_ce` boxes. Logs and nutrition goals are per profile, while reusable
  custom meals and recipes are shared across profiles.
- The Hive encryption key comes from `flutter_secure_storage`.
- The mobile app stores only the separate backend access token in platform secure storage. The server-side
  OpenAI key remains exclusively in deployment secrets and is never shipped in the APK.
- Meal descriptions and images should not be persisted by the AI backend before the user confirms a meal.

### Existing food logging flow

1. The caller opens `AddMealScreen` with a day and meal type.
2. `ProductsBloc`, `FoodBloc`, and `RecentMealBloc` search remote products/reference foods or local history.
3. Selecting a result opens the meal-detail/edit flow, where the serving amount is reviewed.
4. `AddIntakeUsecase` and `IntakeRepository` persist an `IntakeDBO` in the active profile's encrypted Hive box.
5. Home, diary, and tracked-day totals refresh from the saved intake.

The AI preview now joins this flow before step 3: each extracted food is resolved against nutrition data, shown
as an editable candidate, then converted into the same domain entities and use cases used by manual logging. The
AI layer does not create a second meal persistence path.

### Nutrition and recipe calculations

- `MealEntity` carries per-100 g nutrition from Open Food Facts or the reference-food backend.
- Serving calculations scale database values by the user-entered amount; calorie targets and TDEE are separate
  core calculations.
- Recipes snapshot ingredient nutrition and `ComputeRecipeNutritionUsecase` totals each nutrient by converted
  ingredient weight, preserving unknown nutrients as unknown rather than zero.
- AI-identified composite dishes will therefore need either a direct reference-food match or a transparent recipe
  decomposition that the user can review. The extraction model must not manufacture macro totals.

## Validation performed

- Backend Ruff lint: passing.
- Backend Pytest suite: 16 passing tests.
- Docker image build and containerized health check: passing.
- OpenAPI/Swagger UI browser smoke check with Playwright: passing; `/docs` exposes the health and text-analysis
  operations, and `GET /health` returned database readiness.
- Live server-side OpenAI key smoke test: passing. A mixed Indian meal description was parsed into chapati, dal,
  and curd candidates by `gpt-5.4-mini` without exposing or returning the configured key.
- Flutter toolchain: Flutter 3.41.7, Dart 3.11.5, FVM 4.1.2, Temurin JDK 17, and Android SDK 36 are installed and
  configured; `flutter doctor` reports the Flutter and Android toolchains as ready.
- Flutter dependency resolution and Envied/build-runner generation: passing.
- Dart static analysis: no issues. It was run in an isolated container because the shared host had exhausted its
  inotify instance limit.
- Flutter test suite: 738 passing tests.
- Android build: passing; the develop debug APK was generated at
  `build/app/outputs/flutter-apk/app-develop-debug.apk`.
- Android device run: pending because this execution environment has no connected device or configured emulator.

## Second implementation slice

The text-meal flow is now implemented end to end:

- The deployed HTTPS backend URL is part of the Flutter environment configuration.
- The Flutter client uses typed response models, a 65-second timeout, bounded retries, server error mapping, and
  `Retry-After` support.
- A separate backend application token is stored in Android/iOS secure storage and sent with the Bearer scheme.
- Production backend requests fail closed when `ONT_AI_ACCESS_TOKEN` is missing, compare credentials in constant
  time, and apply a per-client fixed-window limit. Multi-instance deployments still need a Vercel Firewall or
  shared Redis limit at the edge.
- Add Meal now exposes an AI action that opens a description form with explicit loading, validation,
  authentication, network-error, review, and saving states.
- Every extracted food is resolved against the app's existing USDA/FoodData Central and Open Food Facts search
  path. Calories and macros appear only after a trusted database record is selected.
- The preview supports editing the lookup query, selecting another database candidate, correcting grams/ml, and
  removing foods. Unresolved foods or missing amounts block saving.
- Confirmed foods are written through `AddIntakeUsecase`, update the existing tracked-day totals, and refresh the
  Home and Diary BLoCs.
- New strings are available in every supported locale catalog, currently using reviewed English fallback copy
  pending native translations.

Additional validation performed:

- Backend Ruff lint: passing.
- Backend Pytest suite: 16 passing tests, including production fail-closed auth and rate limiting.
- Dart static analysis: no issues.
- Flutter test suite: 738 passing tests, including API-client, retry, BLoC, and editable-preview widget tests.
- Android develop debug APK: built successfully at
  `build/app/outputs/flutter-apk/app-develop-debug.apk`.

## Next slice

1. Configure the generated `ONT_AI_ACCESS_TOKEN` in Vercel and enter the same token once on the device.
2. Add a shared edge/Redis rate limiter before horizontally scaling the backend.
3. Add image upload only after the text flow has been exercised on a physical Android device.
4. Add native translations for the new AI meal strings.
