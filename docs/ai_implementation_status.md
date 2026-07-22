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
- The OpenAI key should also remain in platform secure storage and only be sent in the BYOK request header. It
  must never be placed in Hive, application logs, crash metadata, query parameters, or request bodies.
- Meal descriptions and images should not be persisted by the AI backend before the user confirms a meal.

### Existing food logging flow

1. The caller opens `AddMealScreen` with a day and meal type.
2. `ProductsBloc`, `FoodBloc`, and `RecentMealBloc` search remote products/reference foods or local history.
3. Selecting a result opens the meal-detail/edit flow, where the serving amount is reviewed.
4. `AddIntakeUsecase` and `IntakeRepository` persist an `IntakeDBO` in the active profile's encrypted Hive box.
5. Home, diary, and tracked-day totals refresh from the saved intake.

The AI preview should join this flow before step 3: each extracted food must be resolved against nutrition data,
shown as an editable candidate, then converted into the same domain entities and use cases already used by manual
logging. The AI layer should not create a second meal persistence path.

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
- Backend Pytest suite: 10 passing tests.
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
- Flutter test suite: 730 passing tests.
- Android build: passing; the develop debug APK was generated at
  `build/app/outputs/flutter-apk/app-develop-debug.apk`.
- Android device run: pending because this execution environment has no connected device or configured emulator.

## Next slice

1. Add a Flutter API client, typed DTOs, timeouts, retry policy, and secure BYOK key storage.
2. Add the AI text-entry screen and an editable multi-food preview using the existing app design system.
3. Implement nutrition candidate resolution and require a database match before any calories/macros are shown.
4. Map confirmed candidates into the existing intake save path and refresh diary/home BLoCs.
5. Add image upload only after the text flow and nutrition resolution are end-to-end tested.
