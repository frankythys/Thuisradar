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

The Supabase backend is defined entirely in `supabase/schema.sql` (idempotent). Apply it by pasting into the Supabase SQL Editor — there is no migration tooling.

## Architecture

**Feature-first + layered.** Each feature under `lib/features/<name>/` is split into four layers with a strict dependency direction:

- `domain/` — pure Dart models + logic. **Never imports Flutter or Supabase.** This is the testable core (e.g. `combineMembers`, `MemberLocation.fromJson`).
- `data/` — repositories and device sources that talk to Supabase or hardware. Repositories take a `SupabaseClient` in their constructor.
- `application/` — Riverpod providers and state notifiers. Wires `data` into the widget tree.
- `presentation/` — screens and widgets. **Widgets never touch Supabase directly** — only via providers/repositories.

`lib/core/` holds cross-cutting config (`Env`), the Supabase client provider, theme, and utils. `lib/shared/widgets/` holds reusable widgets. Keep files small — anything growing past ~200 lines gets split.

**State management is Riverpod.** The dependency chain is consistent across features: `supabaseClientProvider` → `<X>RepositoryProvider` → feature providers. To see a feature end-to-end, read its `application/*_providers.dart` first — it names every piece.

**Navigation is gate-based, not router-based.** `app.dart` → `AuthGate` (watches `sessionProvider`) → `FamilyGate` (watches `myFamilyProvider`) → either `FamilySetupScreen` or `MapScreen`. Each gate `.when(...)`s an `AsyncValue` and swaps the whole screen; there is no named-route table.

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
- Tests use `flutter_test` + `mocktail`, and target the `domain/` and `application/` layers (pure logic + notifiers), not widgets.
