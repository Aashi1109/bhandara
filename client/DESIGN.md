---
name: Foody Mobile Design System
version: 0.1.0
platform: Flutter (Android, iOS, Web)
description: >
  Light-only, black-on-white, high-contrast mobile design system for a
  food/event discovery app. Serif display type over a geometric sans body.
  Flat surfaces lifted by soft custom shadows rather than Material elevation.

colors:
  surface: "#FFFFFF"
  muted: "#F3F4F6"
  primary: "#000000"
  mutedForeground: "#6B7280"
  border: "#E5E7EB"
  accent: "#10B981"
  success: "#10B981"
  error: "#EF4444"
  warning: "#F59E0B"

fonts:
  display: Playfair Display   # serif, displayXL/displayLG only
  body: Plus Jakarta Sans     # everything else

iconSizes: { xs: 12, s: 14, m: 16, default: 20, l: 24, xl: 32, hero: 48, display: 64 }

componentSizes:
  buttonHeight: { sm: 40, md: 48, lg: 56, xl: 64 }
  buttonPaddingX: { sm: 16, md: 24, lg: 32, xl: 40 }
  cardPadding: { none: 0, sm: 16, md: 24, lg: 32, xl: 40 }

omitted:
  - spacing      # no scale exists yet — see §6
  - rounded      # no radius scale exists yet — see §8
  - motion       # no duration/curve tokens exist yet — see §10
  - darkMode     # not supported — see §4
---

# DESIGN.md — Foody Mobile

Source of truth for the visual and frontend-architecture contract of the Flutter
client. Describes **what is implemented today**. Gaps are labelled `❌ Not
implemented` — they are known debt, not aspiration.

Setup, env vars and Google Maps configuration live in [README.md](./README.md) and
are out of scope here.

---

## 1. Overview

Foody Mobile is a single-form-factor phone app (34.5k LOC Dart) for discovering
food events, chatting, and managing a profile. The visual language is
**editorial**: near-monochrome, generous whitespace, oversized serif headlines
against a dense sans body scale, colour reserved almost entirely for status.

Density is medium. Surfaces are flat white; hierarchy comes from type weight and
soft low-opacity black shadows, never from Material elevation (`elevation: 0`
globally, `app_theme.dart:41`).

## 2. Principles

1. **Semantic over literal.** Reference `AppColors.mutedForeground`, never
   `Color(0xFF6B7280)` and never `Colors.grey`. Same for type: use a named
   `AppTypography` role, never an inline `TextStyle(fontSize: …)`.
2. **Type carries hierarchy.** Weight and size do the work colour would do
   elsewhere. There are 44 named roles precisely so no screen invents one.
3. **Shared before local.** If `lib/shared/widgets/` has it, use it. A
   feature-local reimplementation is a bug, not a shortcut.
4. **Monochrome by default, colour means status.** `accent`/`success`/`error`/
   `warning` are the only chromatic tokens and they signal state — never
   decoration.
5. **The theme is enforced, not suggested.** Guard tests fail the build on
   inline `TextStyle` values in covered files (§18).

## 3. Non-Goals

Explicit exclusions. These are decisions, not oversights:

- **Dark mode.** No `darkTheme`, no `themeMode`, no dark counterparts for any
  colour token. Adding it requires converting `AppColors` statics into a
  `ThemeExtension` first.
- **Tablet / desktop layouts.** The app builds for web, but there is no
  wide-viewport design. Only width cap in the app is `AppBottomNav.maxWidth = 500`.
- **RTL and localisation.** No `intl` message catalogues; copy is hardcoded English.
- **Third-party theming / white-labelling.** Tokens are compile-time consts.
- **Offline-first.** All imagery and data are remote; fonts are runtime-fetched
  by `google_fonts` with no bundled fallback.
- **Material component defaults.** `ColorScheme` wires only 5 slots; anything
  reaching for `secondary`/`tertiary` is off-system.

## 4. Colour

`lib/shared/theme/app_colors.dart` — 9 flat static tokens. Semantic naming,
already at 1,041 call sites vs 17 raw `Color(0x…)`.

| Token | Value | Role |
|---|---|---|
| `surface` | `#FFFFFF` | Page and card background |
| `muted` | `#F3F4F6` | Recessed fills, chips, skeleton base |
| `primary` | `#000000` | Text, icons, primary button fill |
| `mutedForeground` | `#6B7280` | Secondary text, placeholders, inactive icons |
| `border` | `#E5E7EB` | Hairlines, input outlines, dividers |
| `accent` | `#10B981` | Positive emphasis |
| `success` | `#10B981` | Success state (⚠ identical to `accent`) |
| `error` | `#EF4444` | Error state, destructive actions |
| `warning` | `#F59E0B` | Warning state |

**Rules**
- Never `Colors.white` / `Colors.black` / `Colors.grey` — use `surface`,
  `primary`, `mutedForeground`. (Currently violated 19×/9×/3×.)
- No `on*` foreground tokens exist for status colours. Until they do, put
  `primary` or `surface` on status backgrounds explicitly and check contrast.
- `ColorScheme.light` (`app_theme.dart:15-21`) intentionally maps only
  `primary`, `surface`, `onPrimary`, `onSurface`, `outline`.

**Known drift** — `accent == success`, so "positive emphasis" and "operation
succeeded" are visually indistinguishable. Map factory code
(`shared/services/maps/map_marker_factory.dart`) holds 12 raw hex values.

## 5. Typography

`lib/shared/theme/app_typography.dart` — a `ThemeExtension<AppTypography>` with
**44 required named roles**. Accessed via `context.appTypography` (extension at
`theme_extensions.dart:6`, includes a hot-reload fallback for stale extension
instances).

- **Playfair Display** (serif) — `displayXL`, `displayLG` only.
- **Plus Jakarta Sans** — every other role.

| Group | Roles (size/weight) |
|---|---|
| **display** *(serif)* | `displayXL` 90/700 italic ls −5 · `displayLG` 48/700 ls −1.2 |
| **heading** | `headingXL` 44/900 · `heading1` 36/800 · `heading2` 32/800 · `heading3` 24/800 · `heading3Strong` 24/700 · `heading3Heavy` 24/900 |
| **title** | `titleXL` 28/800 · `titleLG` 20/700 · `titleLGStrong` 20/800 · `titleMD` 18/700 · `titleMDStrong` 18/800 · `titleSM` 16/700 · `titleXS` 15/600 · `titleXSRegular` 15/500 · `titleXSStrong` 15/700 |
| **body** | `bodyLG` 16/500\* · `bodyLGSemi` 16/600 · `bodyMD` 14/500 · `bodyMDSemi` 14/600 · `bodyMDStrong` 14/700 · `bodyBase` 13/500\* · `bodyBaseSemi` 13/600\* · `bodySM` 12/500\* · `bodySMSemi` 12/600 · `bodySMStrong` 12/700 · `bodySMExtraBold` 12/800 · `bodyXS` 11/500 · `bodyXSStrong` 11/800 |
| **label** | `labelLG` 16/700 · `labelMD` 14/700 · `labelMDSemi` 14/600 · `labelSM` 10/700 · `labelSMStrong` 10/800 · `labelSMRegular` 10/500 · `labelXS` 8/700 · `labelXSStrong` 8/900 ls 1.5 |
| **caption** | `captionMD` 13/700\* · `captionMDStrong` 13/800 · `captionSM` 11/700 · `captionSMStrong` 11/800 |
| **overline** | `overline` 10/700 ls 2\* · `overlineEmphasis` 10/800 ls 1.4 · `overlineStrong` 10/900 ls 2 |

`*` = defaults to `mutedForeground`; all others default to `primary`.

**Rules**
- Pick a role. Never write `TextStyle(fontSize: …)` in feature code — the guard
  test (§18) fails the build for covered files.
- Recolour with `.copyWith(color: …)`; do not override size, weight, height or
  letter-spacing.
- 13 Material `TextTheme` slots are mapped onto roles in `app_theme.dart:22-36`,
  so bare `Theme.of(context).textTheme` stays on-system.

**Known drift** — the scale has grown by weight-variant proliferation. 13px has 4
roles, 12px has 4, 24px has 3; `bodySMStrong` (12/700) and `captionSM` (11/700)
overlap in intent. Consolidate before adding any new role.

## 6. Layout & Spacing

❌ **Not implemented.** There is no `AppSpacing` class and no base unit. Spacing is
inline `SizedBox` / `EdgeInsets` literals throughout.

Until a scale exists: **use multiples of 4**, and prefer 8/16/24 for gaps between
distinct blocks. Component-level padding is already tokenised inside the widgets
that own it — `AppButtonSize` (padding-X 16/24/32/40) and `AppCardPadding`
(0/16/24/32/40) — mirror those steps.

## 7. Elevation & Depth

Material elevation is off (`elevation: 0` on `AppBarTheme`). Depth is hand-rolled
`BoxShadow`, all black at low alpha.

| Tier | Shadow | Where |
|---|---|---|
| Resting card | `primary @ 4%`, blur 8, offset (0,2) | `AppCard` default |
| Raised / glass | `primary @ 8%`, blur 24, offset (0,8) | `AppCard` elevated & glass |
| Floating nav | `primary @ 12%`, blur 24, offset (0,8) | `AppBottomNav` (declared inline) |

Only the first two are reusable — they live in `AppCard._shadow`
(`card.dart:41-61`). **Known drift**: 47 `BoxShadow` literals across 29 files
because most surfaces hand-roll a `Container(decoration:)` instead of using
`AppCard`.

## 8. Shape

❌ **No radius scale.** 151 raw `BorderRadius.circular(n)` calls across 17
distinct values.

Observed intent, in the absence of tokens:

| Meaning | Value | Uses |
|---|---|---|
| Pill / fully round | `50` or `999` | 23 + 16 |
| Large surface (sheets, hero cards) | `24`, `20` | 18 + 18 |
| Standard card | `16` | 23 |
| Small control, chip | `12` | 11 |

**Pick one pill idiom.** `circular(50)` and `circular(999)` are two spellings of
the same thing; `999` is the clearer intent. New code: `16` for cards, `12` for
controls, `999` for pills.

## 9. Iconography & Imagery

- **Icons**: `lucide_icons` (stroke), sized only from `AppIconSizes`
  (`xs 12 · s 14 · m 16 · default 20 · l 24 · xl 32 · hero 48 · display 64`).
  `cupertino_icons` is a dependency but effectively unused.
- **Imagery is 100% remote.** Zero `Image.asset` / `AssetImage` in `lib/`. Load
  network images through `cached_network_image` (already in 10 files) so caching
  and placeholders stay consistent — never bare `Image.network`.
- **Bundled assets**: `assets/svg/` only, currently one file
  (`google_logo.svg`). `assets/images/` and `assets/fonts/` exist but are empty.
- **Fonts are not bundled** — `google_fonts` fetches at runtime and the
  `pubspec.yaml` `fonts:` block is commented out. First launch on a cold network
  falls back to the platform default.

## 10. Motion

❌ **No motion tokens.** 18 distinct raw durations in use; the only grouped block
is `_TooltipDefaults` (`tooltip.dart:44`).

De-facto convention worth standardising on:

| Intent | Duration | Curve |
|---|---|---|
| Micro (tap, toggle, colour) | 150–180 ms | `easeOut` |
| Standard (expand, slide, sheet) | 200–250 ms | `easeOutCubic` |
| Entrance with overshoot | 250–300 ms | `easeOutBack` |
| Ambient loop (shimmer) | 1200 ms | linear |

`easeOutCubic` is the house curve (15 uses). Prefer implicit animation widgets
(`AnimatedContainer`, `AnimatedSwitcher`) over an `AnimationController`; only 5
files justify a controller.

❌ Reduced-motion (`MediaQuery.disableAnimations`) is not respected anywhere.

## 11. Components

Shared library: `lib/shared/widgets/` (20 files, ~3.1k LOC). Import via the
relative path convention used throughout `lib/`. Class prefix is `App`.

**Actions**
- `AppButton` — variants `primary · secondary · ghost · outline`, sizes
  `sm · md · lg · xl`. Handles its own async `isLoading` state; pass `loadable`
  and an async `onPressed` rather than managing a spinner yourself.
- `SettingsActionFooter` — sticky save/cancel pair for settings screens.

**Inputs**
- `AppInput` — types `text · email`, with a `ValidationRule<T>` system and
  ready-made `InputValidations`.
- `AppTextArea`, `PasswordRequirements`, `FloatingMessageBar` (chat composer:
  emoji picker + media attach).

**Surfaces**
- `AppCard` — variants `defaultCard · elevated · glass`, padding scale
  `none · sm · md · lg · xl`. **Use this instead of `Container(decoration:)`.**
- `AppHeader` (implements `PreferredSizeWidget`), `AttachmentPill`.

**Overlays**
- `showAppDialog()` — the only sanctioned dialog entry point.
- `AppActionSheet` + `AppActionSheetItem` — the only sanctioned bottom sheet.
- `AppSnackBar` — top-anchored custom overlay (not Material `SnackBar`), types
  `info · error · warning · success`. Single-entry: a new toast replaces the
  current one. `AppSnackBar.showGlobal` works without a `BuildContext`.
- `AnimatedTooltip` — positioned tooltip with grouped timing defaults.

**Feedback**
- `AppSkeleton` / `AppSkeletonLine` — shimmer placeholders. The default loading
  affordance (16 files). Compose `AppSkeletonLine`; do not write per-feature
  skeleton classes.
- `AppPullToRefresh`.

**Navigation**
- `AppBottomNav` — floating pill, capped at 500 px, derives the active tab from
  the current route path.
- `AppTabs<T>` / `AppTabItem<T>`.

**Media / infrastructure**
- `Avatar`, `AppMapView`, `AppSessionCoordinator` (non-visual; wires auth ↔
  socket ↔ providers).

❌ **Missing from the library**: a shared empty-state component (two ad-hoc
`_buildEmptyState()` copies exist) and a shared spinner (11 files use raw
`CircularProgressIndicator`).

### Naming
- Files `snake_case`, **noun only** — `button.dart`, `event_detail.dart`. No
  `_widget` / `_screen` suffix.
- Shared widgets prefixed `App`. Legacy unprefixed exceptions: `Avatar`,
  `AttachmentPill`, `PasswordRequirements`, `AnimatedTooltip`,
  `FloatingMessageBar`, `SettingsActionFooter`. Do not add more.
- Variant enums are `<Widget><Axis>` — `AppButtonVariant`, `AppCardPadding`.
- Screens are `<Name>Screen` and own a `static const String routePath`.
- Imports inside `lib/` are **relative**; tests use `package:` imports.

## 12. Patterns

**Loading** — `AppSkeleton` matching the shape of the incoming content. Reserve
`CircularProgressIndicator` for in-button spinners (which `AppButton` already
does for you).

**Error surfacing** — `BaseService.throwError` auto-toasts every service failure
globally via `AppSnackBar.showGlobal`, *then* throws. **Do not add a second
`AppSnackBar` call in the catch block** — that double-toasts. Catch only to
recover state or show inline field errors. (Currently violated: 39 screen-level
snackbar calls, some of them duplicates.)

**Session expiry** — handled centrally by the Dio interceptor
(`shared/services/api.dart:116`): clears the token and routes to auth. Screens
must not implement their own 401 handling.

**Optimistic update** — snapshot previous state → `AsyncLoading` →
`AsyncValue.guard` → restore on error. Reference implementation:
`shared/providers/user.dart:34-53`.

**Pagination** — cursor-based. `PaginatedResponse<T>` carries
`Pagination{total, limit, hasNext, next}`; pass `next` back as the cursor.

**Empty state** — no shared component yet; copy the shape from
`features/saved/screens/saved.dart:464` until one exists.

## 13. Content & Voice

Largely undefined. Observed and worth holding to:

- Button labels are **sentence case**, verb-first ("Save changes", not "SAVE").
- `overline` roles carry `letterSpacing: 2` and are used for small ALL-CAPS
  eyebrow labels.
- Error copy comes from the server (`response.data['error']`), so client-side
  strings should only cover network/parse failures.
- Dates and numbers format through `intl`; do not hand-roll.

**Known drift** — the two password-requirement implementations disagree on copy
("Minimum 8 characters" vs "At least 8 characters"). Fix by deleting the
duplicate (§19).

## 14. Accessibility

❌ **Effectively unimplemented, and the largest gap in this system.** Nine total
semantics references exist across `lib/`, confined to two feature screens.
**No widget in `lib/shared/widgets/` carries a semantic label** — buttons,
inputs, cards, tabs and nav items are all invisible to screen readers.

Requirements for new work:

- Every icon-only tappable needs a `Semantics(label:)` or a `tooltip:`.
- Touch targets ≥ 48 dp (Android) / 44 pt (iOS). `AppButtonSize.sm` at 40 px is
  **below** both — do not use it for a standalone tap target.
- Text contrast ≥ 4.5:1. `mutedForeground` on `surface` is ≈5.0:1 and passes.
  **`mutedForeground` at `alpha: 0.4` fails AA** — currently used for unmet
  password rules in `reset_password.dart:277`.
- Typography uses fixed `fontSize` with fixed `height`, so OS text scaling is
  ignored. Do not add layouts that would break if that is fixed.

## 15. Responsive & Platform

Phone-first, no breakpoints, no `isTablet` helper. `LayoutBuilder` appears in 7
files and always for intrinsic sizing, never breakpoints.

**Safe area is per-screen opt-in** and coverage is uneven — `saved`, `updates`,
`profile`, `settings` and `chat` have no `SafeArea` despite carrying the floating
bottom nav. Wrap new screens explicitly.

Web/platform divergence is handled by conditional import
(`dio_platform_adapter.dart` / `_web.dart` / `_stub.dart`), not by runtime
branching. Status bar style is set once globally in `main.dart:30`.

## 16. Do's and Don'ts

| ✅ Do | ❌ Don't |
|---|---|
| `AppColors.mutedForeground` | `Colors.grey`, `Color(0xFF6B7280)` |
| `context.appTypography.bodyMD` | `TextStyle(fontSize: 14, fontWeight: …)` |
| `.copyWith(color: …)` on a role | `.copyWith(fontSize: …)` on a role |
| `AppCard(variant: …)` | `Container(decoration: BoxDecoration(boxShadow: …))` |
| `AppButton(variant: …)` | `ElevatedButton` / `TextButton` |
| `showAppDialog()`, `AppActionSheet` | bare `showModalBottomSheet` / `showDialog` |
| `AppSkeleton` sized to the content | full-screen `CircularProgressIndicator` |
| Let `BaseService` toast the failure | a second `AppSnackBar` in the same catch |
| `AppIconSizes.m` | `size: 16` |
| `circular(999)` for pills | `circular(50)` |
| Compose `AppSkeletonLine` | a new `_FooSkeleton` class per feature |

## 17. Architecture Notes

**Layout** — feature-first with a shared layer:

```
lib/
├── main.dart          ProviderScope + MaterialApp.router
├── router.dart        the entire GoRouter table (flat, 34 routes)
├── config.dart        AppConfig — all String.fromEnvironment
├── features/<name>/   screens/ widgets/ services/ models/ providers/ utils/
└── shared/            theme/ widgets/ services/ providers/ models/
                       constants/ utils/
```

Features: `auth · chat · events · explore · onboarding · profile · saved ·
search · settings · updates`.

> ⚠️ `lib/theme/`, `lib/widgets/`, `lib/screens/`, `lib/models/`,
> `lib/providers/`, `lib/services/`, `lib/constants/` are **empty leftovers** from
> a pre-`shared/` layout. `CLAUDE.md` and `AGENTS.md` still point at them and are
> wrong. Real code lives in `lib/shared/*` and `lib/features/*`.

**Theming** — `AppTheme.theme` (`shared/theme/app_theme.dart`) is a single static
`ThemeData`, Material 3, light only. `AppTypography` rides along as a
`ThemeExtension`. Import the barrel `shared/theme/theme.dart`.

**Adding a token**: edit `app_colors.dart` / `app_typography.dart`, register in
`AppTypographyTokens.typography`, extend `copyWith` and `lerp`, then pin the value
in `test/theme/theme_test.dart`.

**Adding a shared widget**: one file in `lib/shared/widgets/`, `App`-prefixed
class, variants as a `<Widget>Variant` enum, sizes as a `<Widget>Size` enum with
its dimensions as static maps inside the file.

**State** — Riverpod 3 with `riverpod_annotation` codegen (`part '*.g.dart'`,
committed). Six providers; five live in `shared/providers/`. Session-scoped ones
use `@Riverpod(keepAlive: true)`.

> Note the split: **services are module-level singletons, not providers**
> (`final eventService = EventService();`). Most screens call services directly
> from `initState` and hold results in `setState`, so only 5 files use
> `AsyncValue.when`. New feature state should go through a Riverpod notifier;
> the singleton pattern is legacy.

**Networking** — one Dio instance (`shared/services/api.dart`), session-cookie
auth (`Cookie: bh_session=…`) from `flutter_secure_storage`, two interceptors
(auth + logging). Nine services `extend BaseService`; endpoints are centralised in
`shared/constants/api.dart`. There is no repository layer and no typed failure
class — errors are `String`s.

**Routing** — flat `GoRouter`, path-based (no `name:`), args via
`state.pathParameters` and untyped `state.extra` maps. No `ShellRoute`, so each
bottom-nav tab switch is a full route push and per-tab state is not preserved.
Auth redirect is split between `shared/utils/auth_redirect.dart` and the Dio 401
handler.

Per-change engineering RFCs do not belong in this file; put them in
`docs/rfcs/NNNN-*.md` and link them here.

## 18. Governance

**The design system is test-enforced.** Three tests in `test/theme/` and
`test/widgets/`:

- `design_system_guard_test.dart` — reads 9 source files as text and **fails if a
  `TextStyle(...)` contains `fontSize`, `fontWeight`, `letterSpacing` or
  `height`**. It is an allowlist; ~90 other Dart files are unguarded. **Add your
  file to that list when you touch it.**
- `theme_test.dart` — pins `heading1: 36`, `heading2: 32`, `bodyMD: 14`,
  `overline` letter-spacing 2.
- `typography_usage_test.dart` — asserts `AppButton` uses `labelMD`, `AppInput`
  uses `overline` + `bodyMD`, and pins 10 further token values.

Changing a pinned token is therefore a deliberate, test-breaking act. That is the
intent.

Before merging UI work: `flutter analyze` · `flutter test` ·
`dart run build_runner build --delete-conflicting-outputs` if providers changed.

No golden/screenshot tests, no integration tests, no mocking library — widget
tests build real widgets against real singletons.

## 19. Known Debt

Ordered by cost of leaving it:

| # | Issue | Evidence |
|---|---|---|
| 1 | Accessibility absent from the entire shared widget layer | 9 semantics refs app-wide, 0 in `shared/widgets/` |
| 2 | No spacing / radius / motion token classes | 151 raw radii (17 values), 47 raw shadows, 18 durations |
| 3 | `AppCard` adopted by only 4 files; every other surface hand-rolls decoration | source of #2 |
| 4 | `PasswordRequirements` duplicated with divergent copy, icons and type | `shared/widgets/password_requirements.dart` vs `reset_password.dart:217` |
| 5 | 7 raw `showModalBottomSheet` call sites bypass `AppActionSheet` | only 3 pass an `AppActionSheet` builder |
| 6 | Double-toasting — services toast globally *and* screens toast locally | 39 screen-level `AppSnackBar` calls |
| 7 | Typography scale bloat: 44 roles, several overlapping in intent | 4 roles at 13px, 4 at 12px, 3 at 24px |
| 8 | No shared empty-state or spinner component | 2 ad-hoc empty states, 11 raw `CircularProgressIndicator` |
| 9 | Screens mix layout + state + API calls | `explore_screen.dart` 2,487 LOC; `event_detail.dart` 2,010 |
| 10 | Router: no shell, no named routes, untyped `state.extra` | `router.dart` |
| 11 | `accent` and `success` are the same hex | `app_colors.dart:9,11` |
| 12 | `CLAUDE.md` / `AGENTS.md` point at empty legacy directories | §17 |
| 13 | `LogInterceptor` always on, not gated on `kDebugMode` | `api.dart:54` |
