# ScrollIQ — Project Context

## What is ScrollIQ?

A digital wellbeing Android app that counts individual reels/shorts/TikToks the user scrolls through using an **AccessibilityService**, converts that into a **Brain Score (0–100)**, and lets users compete with friends via leaderboards and challenges. Think "BrainPal competitor" but with unique interventions (Reel Tax), predictive analytics, and transparent scoring.

## Tech Stack

- **Flutter 3.22+** (Material 3, Dart 3.4+)
- **Riverpod** (state management — providers, StateNotifier, StreamProvider)
- **Supabase** (Postgres, Auth, RLS, Edge Functions planned)
- **Firebase** (FCM push notifications only)
- **PostHog** (analytics via Android native meta-data)
- **Kotlin** (all native Android code — no Java)
- **Go Router** (navigation)
- **SharedPreferences** (local config: caps, reel tax, onboarding state)
- **google_fonts**: Space Grotesk (display), Inter (body), JetBrains Mono (numeric stats)
- **fl_chart** (trend chart), **shimmer** (loading), **lottie** (planned hero animations)

## Architecture

Clean architecture by feature. Each feature has `data/`, `domain/`, `presentation/` (screens + widgets), and a top-level `providers.dart`.

```
lib/
├── core/                     # theme, router, env, DI, constants, errors
├── features/
│   ├── auth/                 # Google + email sign-in (Supabase ID-token flow)
│   ├── onboarding/           # 9-slide story → permissions → challenge → demo
│   ├── usage_tracking/       # UsageStatsManager bridge (minutes per app)
│   ├── reel_counter/         # AccessibilityService bridge (individual reel counts)
│   ├── dashboard/            # Brain Score + ReelCountCard + ForecastCard + TrendChart
│   ├── leaderboard/          # Global daily leaderboard
│   ├── friends/              # Search, requests, accept/decline
│   ├── challenges/           # 7-Day Scroll Detox + custom challenges
│   ├── profile/              # Stats, settings, sign-out
│   └── notifications/        # FCM + flutter_local_notifications
├── shared/                   # Design system: AppCard, GradientBorder, SectionHeader,
│                             # StatPill, MainShell (floating pill nav), AppButtons,
│                             # UserAvatar, AppLoading/AppShimmer, AppError, formatters
└── main.dart
```

## Design System

ScrollIQ is intentionally styled to feel like a top-tier productivity app
(Linear / Things 3 / Opal), not a stock Material-3 template. All visual
tokens live in `lib/core/theme/`.

### Brand identity

- **Background**: warm ink `#0B0C10` (not the typical cool blue-violet)
- **Signature accent**: electric lime/chartreuse `#C5F75A` — pair with
  `AppColors.onPrimary` (`#0A0B0E`) for foreground on primary fills
- **Secondary**: coral `#FF7A59` (warmth, friendly emphasis)
- **Tertiary / accent**: amber `#FFC857` (streaks, awards, playful highlights)
- **Status**: `success #34D399`, `warning #F59E0B`, `danger #F87171`,
  `info #60A5FA`
- **Surfaces**: `surfaceDark` `#15171D`, `surfaceDark2` `#1B1E25`,
  `surfaceDark3` `#22262F` (floating nav, popovers)
- **Borders**: `borderDark` `#262A33` (hairline), `borderDarkStrong`
  `#3A3F4B` (focus / selected)
- **Text**: warm cream `#F2EFE6` (primary), `#9AA0AC` (secondary),
  `#60656F` (tertiary)
- **Brain score buckets**: `scoreFocusMaster` (lime) → `scoreHealthy`
  (mint `#7DE0BD`) → `scoreDistracted` (amber) → `scoreDoomscroller`
  (orange `#FF8A4C`) → `scoreBrainMelt` (danger)
- **Gradients**: `AppColors.brandGradient` (lime → mint), `warmGradient`
  (amber → coral), `cardBorderGradient` (1px premium stroke)

App currently runs `themeMode: ThemeMode.dark`. Light tokens are stubbed
in `app_colors.dart` for completeness.

### Typography (mixed on purpose)

| Role | Font | Where it's used |
|------|------|-----------------|
| Display / headline / title / app bar / buttons / tabs | **Space Grotesk** (geometric, distinctive) | Hero copy, screen titles, CTAs |
| Body / labels / inputs | **Inter** (highly readable) | Paragraphs, helper text, list items |
| Numerical stats | **JetBrains Mono** (Linear-style premium feel) | Brain Score, reel counts, ranks |

Helpers in `lib/core/theme/app_theme.dart`:

```dart
AppText.statHero({Color? color})   // 72pt mono — brain-score hero
AppText.statLarge({Color? color})  // 32pt mono — card stats
AppText.statSmall({Color? color})  // 18pt mono — inline metrics
AppText.mono({size, color, weight}) // generic monospace
AppText.eyebrow({Color? color})    // 11pt uppercase tracked label
```

Radius scale (use these — don't hand-pick):

```dart
AppTheme.radiusXl = 28   // hero cards, dialogs, splash badge
AppTheme.radiusLg = 20   // default AppCard
AppTheme.radiusMd = 16   // buttons, inputs
AppTheme.radiusSm = 12   // chips, small surfaces
AppTheme.radiusXs = 8    // pills, dense
```

### Shared widgets (use these, don't build new ones)

| Widget | File | Purpose |
|--------|------|---------|
| `AppCard` | `shared/widgets/app_card.dart` | Default surface. Hairline-bordered by default; pass `gradient:` for hero variant; `shadow:` for accent glow; `onTap:` for ink ripple. Radius defaults to `radiusLg`. |
| `GradientBorder` | same file | 1-px gradient stroke wrapper for premium CTAs / score gauge containers. |
| `SectionHeader` | `shared/widgets/section_header.dart` | Uppercase eyebrow + title + optional trailing CTA ("See all →"). Used between content blocks on Dashboard / Profile / Leaderboard. |
| `StatPill` | `shared/widgets/stat_pill.dart` | Rounded pill — `filled: true` for solid, default soft tint of `color`. Used for category badges, leaderboard scores, status tags. |
| `MainShell` | `shared/widgets/main_shell.dart` | Floating frosted pill bottom nav (BackdropFilter blur, animated icon → icon+label on selection). Tabs: Home / Ranks / Goals / You. |
| `PrimaryButton` / `SecondaryButton` | `shared/widgets/app_buttons.dart` | Pre-themed; lime fill + dark text for primary, outlined surface for secondary. |
| `UserAvatar` | `shared/widgets/user_avatar.dart` | Cached network image with initials fallback. |
| `AppLoading` / `AppShimmer` | `shared/widgets/app_loading.dart` | Loaders, sized via `height`. |
| `AppError` | `shared/widgets/app_error.dart` | Error state with optional retry. |

### Hero brain-score card

`features/dashboard/presentation/widgets/brain_score_card.dart` is a
reference for the visual language:

- Eyebrow + filled category `StatPill` (top row)
- `AppText.statHero` number on the left, "/100" mono suffix
- Custom 270° radial gauge (`CustomPainter` with `SweepGradient` + animated
  `TweenAnimationBuilder`, 0.9s `Curves.easeOutCubic`)
- Card uses `radiusXl` + colored shadow keyed off the category color
- Subtitle copy is **contextual to the bucket**, not generic

### Layout conventions

- Screens that sit inside `MainShell` use `padding: EdgeInsets.fromLTRB(20, ..., 20, 110)` so content clears the floating nav.
- `RefreshIndicator` always uses `color: AppColors.primary, backgroundColor: AppColors.surfaceDark2`.
- Section structure: `SectionHeader(eyebrow, title)` → 12px gap → content card(s).
- Permission/warning banners use a tinted variant of `AppCard` (`color: AppColors.warning.withValues(alpha: 0.06)`, `borderColor: AppColors.warning.withValues(alpha: 0.3)`).

### When designing a new screen

1. Background = `Scaffold` default (theme handles `bgDark`).
2. Wrap content in `SafeArea` + `ListView` with the standard padding above.
3. Use `SectionHeader` between blocks. Don't invent new title styles.
4. Numbers ≥ 14pt → use one of the `AppText.statXxx` helpers.
5. Categorical color → pull from `AppColors.scoreXxx` / status tokens, not raw hex.
6. New decorative gradient → check `AppColors.brandGradient` / `warmGradient` first.
7. Reach for an existing `AppCard` / `StatPill` / `SectionHeader` before adding bespoke widgets.

## Native Android Architecture (`android/app/src/main/kotlin/com/scrolliq/app/`)

### Reel Counting Engine (`reelcounter/`)

| File | Purpose |
|------|---------|
| `ReelCounterAccessibilityService.kt` | Routes accessibility events to per-app detectors, 350ms debounce per package |
| `ReelDetector.kt` | Interface: `onWindowStateChanged()` + `isReelScroll()` |
| `ReelNodeUtil.kt` | Tree traversal helpers (`anyIdContains`, `classContains`) |
| `ReelCounterStore.kt` | Process-wide singleton, SharedPrefs-backed, daily counter + 30-day history, observable via `Listener` |
| `ReelCounterPlugin.kt` | MethodChannel `com.scrolliq/reel_counter` + EventChannel `com.scrolliq/reel_counter/stream` |
| `OverlayService.kt` | Foreground service, `TYPE_APPLICATION_OVERLAY` draggable bubble HUD |
| `ReelTaxManager.kt` | Full-screen blocking overlay every N reels (configurable), 5-sec countdown |
| `detectors/InstagramReelDetector.kt` | IG Reels: clips_viewer / reels_viewer node IDs |
| `detectors/YouTubeShortsDetector.kt` | YT Shorts: reel_recycler / shorts_player IDs |
| `detectors/TikTokReelDetector.kt` | TikTok: feed_recycler_view / video_pager IDs (both musically + trill packages) |
| `detectors/SnapchatSpotlightDetector.kt` | Snap Spotlight: spotlight / ngs_spotlight_recycler_view IDs |
| `detectors/FacebookReelsDetector.kt` | FB Reels: reels_viewer / reels_swipeable_view_pager (katana + lite) |

### Detection Heuristic

Each detector tracks whether the user is in the reel feed via `onWindowStateChanged` (checks view-id-resource-name subtree). On `TYPE_VIEW_SCROLLED`, if in-feed AND `abs(scrollDeltaY) >= 200` OR `fromIndex != toIndex`, it's one reel. Debounced 350ms per package.

### Permissions Required

| Permission | Manifest | How Granted |
|------------|----------|-------------|
| `BIND_ACCESSIBILITY_SERVICE` | Service declaration | Settings → Accessibility |
| `SYSTEM_ALERT_WINDOW` | `<uses-permission>` | Settings → Display over other apps |
| `PACKAGE_USAGE_STATS` | `<uses-permission>` | Settings → Usage access |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE` | `<uses-permission>` | Auto (declared) |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | `<uses-permission>` | Settings prompt |
| `POST_NOTIFICATIONS` | `<uses-permission>` | Runtime (Android 13+) |
| `RECEIVE_BOOT_COMPLETED` | `<uses-permission>` | Auto |

### MethodChannel API (`com.scrolliq/reel_counter`)

| Method | Returns |
|--------|---------|
| `isAccessibilityEnabled` | `bool` |
| `openAccessibilitySettings` | `null` |
| `canDrawOverlays` | `bool` |
| `openOverlaySettings` | `null` |
| `isOverlayRunning` | `bool` |
| `startOverlay` | `bool` (false if no perm) |
| `stopOverlay` | `null` |
| `isBatteryOptimizationIgnored` | `bool` |
| `openBatterySettings` | `null` |
| `getSnapshot` | `Map {date, total, perApp, ts}` |
| `getHistory(days)` | `List<Map {date, total, perApp}>` |
| `reset` | `null` |
| `getReelTaxConfig` | `Map {enabled, interval, durationSec}` |
| `setReelTaxConfig(enabled?, interval?, durationSec?)` | `null` |

### MethodChannel API (`com.scrolliq/usage_stats`)

| Method | Returns |
|--------|---------|
| `hasPermission` | `bool` |
| `requestPermission` | `null` (opens Settings) |
| `queryUsage(start, end)` | `List<Map {packageName, appName, totalTimeMs}>` |
| `queryRangeMinutes(start, end)` | `int` (total foreground minutes) |

### EventChannel (`com.scrolliq/reel_counter/stream`)

Emits `Map {date, total, perApp, ts}` on every store mutation. Pushes current snapshot immediately on subscribe.

## Brain Score Formula

```
score = 100
  - screenTimePenalty  (8pts per hour over 2h)
  - socialMediaPenalty (12pts per hour over 1h)
  - lateNightPenalty   (15pts per hour between 00:00–05:00)
  - reelCountPenalty   (3pts per 10 reels over 30)
clamped to [0, 100]
```

Categories: Focus Master (90+), Healthy (70+), Distracted (50+), Doomscroller (30+), Brain Melt (<30).

## Supabase Schema (key tables)

- `users` — id (FK auth.users), name, email, avatar_url, fcm_token
- `daily_usage` — user_id, date, *_time (minutes per app), instagram_reels, youtube_shorts, tiktok_reels, snapchat_spotlight, facebook_reels, `total_reels` (GENERATED), brain_score
- `friends` — sender_id, receiver_id, status (pending/accepted/declined/blocked)
- `challenges` + `challenge_participants`
- Views: `leaderboard_today`, `user_stats` (includes `weekly_reels`)
- RPC: `search_users(q text)`
- RLS on all tables

Project ref: `xnqswsdmkbbunomaizks` (ScrolliQ HQ, Seoul region)

## Onboarding Flow (Phase C)

1. **Story slides** (9 pages): Hook → 0 reels → 21 reels → 100 reels → 500+ reels (red) → goals chips → empowerment → privacy → promise
2. **Permissions screen**: 4 rows (Accessibility, Overlay, Battery, Usage Stats) — each with Allow/✓
3. **Challenge Friends**: VS illustration, CTA + skip
4. **Demo**: "Open YouTube to see ScrollIQ in action" → launches YouTube Shorts

On finish: saves `onboarding_done` pref, auto-starts overlay bubble.

## Unique Features (vs BrainPal)

| Feature | Description |
|---------|-------------|
| **Brain Score** | Composite score, not just raw reel count |
| **Reel Tax** | Full-screen 5-sec blocking overlay every 30 reels with breathing prompt |
| **Per-platform caps** | User sets per-app daily reel limits (SharedPrefs) |
| **Predictive forecast** | Linear regression on 7 days → "next week ~X reels" |
| **Leaderboards + Leagues** | Daily global leaderboard (planned: weekly leagues) |
| **Transparent formula** | Score formula is open, not a black box |

## Key Providers (Riverpod)

```dart
// Reel Counter
reelCounterServiceProvider         // ReelCounterService singleton
reelCountStreamProvider            // StreamProvider<ReelCountSnapshot>
reelCountTodayProvider             // FutureProvider<ReelCountSnapshot>
reelCountHistoryProvider(days)     // FutureProvider.family<List<ReelCountDay>, int>
reelCounterAccessibilityEnabledProvider  // FutureProvider<bool>
overlayControllerProvider          // StateNotifierProvider<OverlayController, OverlayState>
overlayPermissionProvider          // FutureProvider<bool>
batteryExemptProvider              // FutureProvider<bool>
platformCapsRepoProvider           // Provider<PlatformCapsRepository>
platformCapsProvider               // FutureProvider<List<PlatformCap>>

// Usage Tracking
usageTrackingServiceProvider       // Provider<UsageTrackingService>
usageRepositoryProvider            // Provider<UsageRepository>
todayUsageProvider                 // FutureProvider<DailyUsage>
recentUsageProvider                // FutureProvider<List<DailyUsage>>
usagePermissionProvider            // FutureProvider<bool>

// Auth
currentUserProvider                // provider for current user
routerProvider                     // GoRouter

// Core
supabaseClientProvider             // Provider<SupabaseClient>
analyticsProvider                  // PostHog
```

## File Naming Conventions

- Kotlin: PascalCase (`ReelCounterStore.kt`)
- Dart: snake_case (`reel_counter_service.dart`)
- Tests: `test/<feature>_test.dart`
- Migrations: `supabase/migrations/NNNN_description.sql`

## Build & Run

```bash
flutter pub get
flutter analyze            # must be 0 issues
flutter test               # 12 tests
flutter run                # debug on device

# Kotlin-only verify:
cd android && .\gradlew.bat :app:compileDebugKotlin

# Release:
flutter build apk --release
```

## Environment

- `.env` file (not committed): SUPABASE_URL, SUPABASE_ANON_KEY, GOOGLE_WEB_CLIENT_ID
- `android/app/google-services.json` (Firebase, not committed)
- `android/app/src/main/res/values/strings.xml`: posthog_api_key, posthog_host

## Roadmap (Not Yet Implemented)

- iOS Screen Time API implementation
- Detailed Accessibility Service → view content hashing for exact reel identification
- Custom friend challenges (not just default 7-day detox)
- Streak & weekly digest via Supabase Edge Functions + Cron
- In-app purchases for premium analytics
- Weekly leagues (Bronze → Diamond, Duolingo-style)
- OEM auto-start deeplinks (Xiaomi/OPPO/Vivo specific intents)
