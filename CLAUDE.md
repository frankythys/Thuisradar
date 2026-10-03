# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Thuisradar is a family-location app (a self-hosted Life360 alternative) built with Flutter + Supabase. Code comments and user-facing strings are in Dutch; keep new strings Dutch to match. See `README.md` and `docs/SETUP.md` for the product overview and full environment setup.

## Commands

```bash
flutter pub get                                   # install dependencies
flutter analyze                                   # lint / static analysis (strict-casts, strict-raw-types)
flutter test                                      # run all tests
flutter test test/features/location/location_tracker_test.dart   # run a single test file
flutter run --dart-define-from-file=env.json      # run on a connected device
flutter build apk --release --dart-define-from-file=env.json     # build Android APK
```

Supabase URL + key come in via `--dart-define-from-file=env.json` (copy `env.example.json` → `env.json`; `env.json` is gitignored). `Env.assertConfigured()` in `main.dart` throws if either is missing, so the define flag is required for every run/build.

**Database changes.** `supabase/schema.sql` is the v1 baseline (idempotent) and **must not be edited**. Every later change is a **numbered migration** in `supabase/migrations/NNN_name.sql` (001, 002, …). The owner runs each one **manually in the Supabase SQL Editor** — do **not** use `supabase db push` (the migrations have no timestamp names and earlier ones are already applied). When you add a migration, tell the user exactly when to run it.

## Architecture

**Feature-first + layered.** Each feature under `lib/features/<name>/` is split into four layers with a strict dependency direction:

- `domain/` — pure Dart models + logic. **Never imports Flutter or Supabase.** This is the testable core (e.g. `combineMembers`, `MemberLocation.fromJson`).
- `data/` — repositories and device sources that talk to Supabase or hardware. Repositories take a `SupabaseClient` in their constructor.
- `application/` — Riverpod providers and state notifiers. Wires `data` into the widget tree.
- `presentation/` — screens and widgets. **Widgets never touch Supabase directly** — only via providers/repositories.

`lib/core/` holds cross-cutting config (`Env`), the Supabase client provider, theme, and utils. `lib/shared/widgets/` holds reusable widgets. Keep files small — anything growing past ~200 lines gets split.

**State management is Riverpod.** The dependency chain is consistent across features: `supabaseClientProvider` → `<X>RepositoryProvider` → feature providers. To see a feature end-to-end, read its `application/*_providers.dart` first — it names every piece.

**Navigation is gate-based, not router-based.** `app.dart` → `PushGate` (registers FCM token) → `OnboardingGate` (first-run slides) → `AuthGate` (watches `sessionProvider`) → `FamilyGate` (watches `myFamilyProvider`) → either `FamilySetupScreen` or `HomeShell`. `HomeShell` holds the bottom navigation (Kaart / Plaatsen / Chat / Meldingen) in an `IndexedStack` and overlays the realtime SOS alert. Sub-screens (member detail, invite, welcome, permissions) are pushed with `MaterialPageRoute`; they use `BrandedAppBar`, which shows an automatic back arrow when the route can pop. Each gate `.when(...)`s an `AsyncValue` and swaps the whole screen; there is no named-route table.

**Map camera & markers are flutter_map-independent at the core.** Decision logic lives in pure domain classes so a later map swap stays cheap: `map/domain/auto_fit.dart` (`AutoFitController` — fit once, lock on user gesture, deliberate recenter) and `map/domain/marker_cluster.dart` (`clusterByScreenDistance` — group members by on-screen distance). The widgets only project coordinates and render. Current map is **flutter_map + OpenStreetMap** (free); Google Maps / satellite is a "Later" item, see `docs/ROADMAP.md`.

**Realtime location flow (the core feature):**
1. `LocationTracker` (a `Notifier<TrackingStatus>` in `location/application/`) subscribes to the device GPS stream, reads battery, and **upserts** one row per user into `member_locations` (`onConflict: 'user_id'`).
2. A Postgres trigger (`record_location_history`) copies every upsert into `location_history`.
3. Other members observe changes via `LocationRepository.watchFamily` — a Supabase realtime `.stream()` on `member_locations`, exposed as `familyLocationsProvider`.
4. `membersOnMapProvider` combines `familyMembersProvider` + `familyLocationsProvider` (pattern-matching both `AsyncValue`s) into the map markers.

**Supabase security model (in `schema.sql`):** every table has RLS enabled. Cross-member access goes through `security definer` helper functions `is_family_member()` / `shares_family_with()` (they exist specifically to avoid infinite RLS recursion on `family_members`). Family creation/joining go through the `create_family` / `join_family` RPCs rather than direct inserts — repositories call these via `client.rpc(...)`. Only ever use the publishable/anon key in the app, never the `service_role` key.

**Profiles are created lazily.** `signUp` stores `display_name` in auth metadata; `AuthRepository.ensureProfile()` later upserts the `profiles` row. `myFamilyProvider` calls `ensureProfile()` before fetching the family.

## Conventions

- Lint rules enforced (see `analysis_options.yaml`): single quotes, trailing commas, declared return types, no `print` (use `debugPrint`), `unawaited_futures`, super parameters.
- Errors surfaced to the UI via the shared `ErrorView` widget; background/stream errors are logged with `debugPrint` and reflected in `TrackingStatus`.
- Tests use `flutter_test` + `mocktail`, and target the `domain/` and `application/` layers (pure logic + notifiers), plus focused widget tests.

## Working rules (read before committing)

- **Feature-first, no god code.** Organise by feature/domain, not by type. Keep files small — **~200 lines typical, split beyond that**. Each file does one thing.
- **`domain/` is pure Dart** — no Flutter, no Supabase imports. Put testable decision logic there (see the map domain classes).
- **No hardcoded colours/sizes in widgets.** Use the `ColorScheme` + `AppTokens` `ThemeExtension` (`context.tokens`). Light theme only for now, but built so dark mode is a second scheme.
- **All UI text in Dutch (Vlaams).**
- **Before every commit:** `dart format -l 110 lib test`, `flutter analyze` must be **0 issues**, and `flutter test` must be **green**. Write tests for new `domain/` and `application/` logic.
- **Cross-platform first.** Don't write Android-only code when a cross-platform alternative exists (iPhone comes later — see below).
- **Commit per logical step** with a clear Dutch message; attribution is disabled (no co-author trailer). **Never push without asking.**

## Test devices

- **Samsung A52 "Papa"** — real phone over wireless adb (the id looks like `adb-XXXX._adb-tls-connect._tcp`; it changes and drops when wifi/debugging resets — re-check with `flutter devices`).
- **Emulator "Liam"** — `emulator-5554`, an Android image **with Google Play** (needed for FCM push).
- **Android only now.** iPhone (for Liam and mama) comes later via **Codemagic / TestFlight**; no Mac required locally.

## Secrets — never commit, never log

`env.json` (Supabase keys), `android/app/google-services.json` (Firebase), `android/local.properties`, and any service-account JSON are gitignored and must stay out of git and out of logs. Only the Supabase **publishable/anon** key ships in the app; the `service_role` key lives only in Supabase (Edge Function secrets). The FCM service account is set by the owner as the `FCM_SERVICE_ACCOUNT` secret — never read or store it in the project.

## Cost discipline

Only **free** services (Supabase free tier, FCM, OpenStreetMap tiles; later Google Maps **SDK for Android** free tier). **Do not** add paid APIs (Places, Geocoding, Directions). Any feature that would cost money goes **behind a feature flag**, off by default. See `docs/KOSTEN.md`. Roadmap and phase order live in `docs/ROADMAP.md`.
