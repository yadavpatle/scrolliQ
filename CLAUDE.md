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
│   ├── onboarding/           # 9-slide story → permissions → demo (pre-login)
│                             # + post-login welcome-invite (Challenge Friends w/ real ?ref=CODE)
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
| `ReelCounterAccessibilityService.kt` | Routes accessibility events to per-app detectors, 400ms debounce per package (`DEBOUNCE_MS`) |
| `ReelDetector.kt` | Interface: single `consume(event: AccessibilityEvent, root: AccessibilityNodeInfo?): Boolean` — returns true exactly once per new reel |
| `ReelNodeUtil.kt` | Tree traversal helpers (`anyIdContains`, `classContains`, `isVerticalAdvance`) |
| `ReelCounterStore.kt` | Process-wide singleton, SharedPrefs-backed, daily counter + 30-day history, observable via `Listener` |
| `ReelCounterPlugin.kt` | MethodChannel `com.scrolliq/reel_counter` + EventChannel `com.scrolliq/reel_counter/stream` |
| `OverlayService.kt` | Foreground service, `TYPE_APPLICATION_OVERLAY` draggable bubble HUD |
| `ReelTaxManager.kt` | Full-screen blocking overlay every N reels (configurable), 5-sec countdown |
| `detectors/YouTubeShortsDetector.kt` | YT Shorts: **content-description fingerprint** (channel handle) + engagement gate + ad skip + 600ms cooldown. **Verified on-device.** |
| `detectors/FacebookReelsDetector.kt` | FB Reels: **content-description fingerprint** (creator handle) + engagement gate + ad skip + 600ms cooldown (katana + lite). FB strips all resource IDs, so ID matching does not work. **Verified on-device.** |
| `detectors/InstagramReelDetector.kt` | IG Reels: **content-description fingerprint** (creator handle / audio attribution) + engagement gate + ad skip + 600ms cooldown. **Migrated; not yet verified on device.** |
| `detectors/TikTokReelDetector.kt` | TikTok: **content-description fingerprint** (creator handle / sound) + engagement gate + ad skip + 600ms cooldown. **Migrated; not yet verified on device. Currently UNREGISTERED in the service.** |
| `detectors/SnapchatSpotlightDetector.kt` | Snap Spotlight: **content + resource-id fingerprint**. Snap exposes almost no content-descs (no creator handle / engagement rail), so this detector is shaped differently: surface gate on the `ngs_spotlight` bottom-nav id, **realness gate on the `opera` content-viewer** (present on Spotlight playback, absent on Camera — this is what stops the Camera tab from counting), fingerprint = longest human-readable visible text (caption / "user · sound" / "Contains: …") filtered against UI labels, numeric counters, internal namespace strings, and identifier-shaped tokens, + 700ms cooldown. **Verified on-device (Realme RMX1921, Android 11).** |

### Detection Heuristic — two approaches

**1. Content-description fingerprint (current best — all five detectors).**
Modern apps either strip resource IDs (Facebook → `(name removed)`) or fire
`CONTENT_CHANGE_TYPE_SUBTREE` repeatedly during playback (YouTube), so the
legacy ID approach either counts nothing or massively over-counts. The robust
approach instead does a single bounded DFS over the node tree per event and:

- Detects the reel surface via content-desc markers (e.g. YT pager ids still
  work for *presence*; FB uses "create reel" / "tap to show video controls" /
  "view <creator>'s reels").
- Builds a **per-reel fingerprint** from the single highest-priority stable
  content-desc (creator/channel handle — appears atomically, stays stable
  during playback). Counting uses fingerprint *change*, not event type.
- **Ad skip**: explicit ad signals ("Sponsored", "Visit advertiser", "Paid
  partnership", …).
- **Engagement gate**: requires a genuine engagement marker (like / comment /
  reaction / remix / share / sound). Ads lack this rail, so they never count —
  far more robust than enumerating ad CTA strings.
- **600ms cooldown**: absorbs transient fingerprint flips while fields load in
  during the swipe transition (prevents double-counting one swipe).

**2. Legacy resource-ID approach (deprecated — kept here for historical context only).**
Tracks in-feed via `anyIdContains(pagerIds)`; counts on subtree-change of a
pager source OR a vertical scroll advance. Known failure modes: zero-count if
the app strips IDs, over-count + counts ads if IDs match (no fingerprint /
cooldown / ad gate). All five detectors have been migrated off this approach.
Do not introduce new detectors that use it.

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

Two-phase flow split across the auth boundary so the post-login share carries
a real referral code rather than a generic homepage URL.

### Pre-login (`OnboardingScreen`, route `/onboarding`)

1. **Story slides** (9 pages): Hook → 0 reels → 21 reels → 100 reels → 500+ reels (red) → goals chips → empowerment → privacy → promise
2. **Permissions screen**: 4 rows (Accessibility, Overlay, Battery, Usage Stats) — each with Allow/✓
3. **Demo**: "Open YouTube to see ScrollIQ in action" → launches YouTube Shorts so the user sees the HUD bubble counting live (requires Accessibility + Overlay → that's why permissions come *before* the demo)

On finish: persists `onboarding_done`, auto-starts the overlay bubble if the
permission was granted, then `context.go('/login')`.

### Post-login (`PostLoginInviteScreen`, route `/welcome-invite`)

A one-time "Challenge Friends" prompt shown the first time a user is
authenticated on the device. Wraps `ChallengeFriendsScreen` so the visual
design is unchanged.

- **Why post-login:** the `referral_code` column is populated by the
  `handle_new_user` Postgres trigger when Supabase auth creates the row, so
  `ReferralService.shareInvite()` can only build a real
  `https://.../invite?ref=<CODE>` link *after* sign-in. Sharing during
  onboarding produced a useless link with no referral attribution — see
  commit history.
- **Gate:** the GoRouter's `redirect` checks `PostLoginInviteController.shown`
  and forces `/welcome-invite` for any authenticated user who hasn't seen it,
  before letting them reach `/home` or any shell route.
- **Migration:** users who finished onboarding before this screen existed
  (`prefOnboardingDone=true`, no invite flag) are auto-marked as already shown
  on first launch — no jarring screen on update.
- Both *Challenge Your Friend* and *I'll Do It Later* persist
  `post_login_invite_shown=true` and the router refresh redirects on to
  `/home`.

### State

- `AppConstants.prefOnboardingDone` — gates the pre-login flow.
- `AppConstants.prefPostLoginInviteShown` — gates the post-login flow.
- `PostLoginInviteController` (`features/onboarding/providers.dart`) is a
  `ChangeNotifier` exposed via `postLoginInviteControllerProvider` and wired
  into the router's `refreshListenable` (merged with `_AuthRefreshNotifier`)
  so the redirect re-runs as soon as the flag flips.

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

// Onboarding / Referral
postLoginInviteControllerProvider  // PostLoginInviteController (ChangeNotifier)
                                   // — gates the /welcome-invite redirect
referralServiceProvider            // ReferralService (deep links + share + redeem)
referralRepositoryProvider         // ReferralRepository
myReferralLinkProvider             // FutureProvider<String> — current user's link

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
flutter test               # 33 tests (brain score + mascot + user avatar + referral links)
flutter run                # debug on device

# Faster iterate on native detector changes (flutter run loses USB debug on
# some older devices, e.g. Mi A1, after install — build+install+launch instead):
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell monkey -p com.scrolliq.app.debug -c android.intent.category.LAUNCHER 1

# Release:
flutter build apk --release
```

## Environment

- `.env` file (not committed): SUPABASE_URL, SUPABASE_ANON_KEY, GOOGLE_WEB_CLIENT_ID
- `android/app/google-services.json` (Firebase, not committed)
- `android/app/src/main/res/values/strings.xml`: posthog_api_key, posthog_host

## Reel-Detector Debugging Playbook

How to fix/verify a per-app reel detector on a connected device (the process
used for YouTube and Facebook):

1. **Get on the reel surface** in the target app, screen unlocked.
2. **Dump the live accessibility tree:**
   ```bash
   adb shell dumpsys window | findstr mCurrentFocus      # confirm app is foreground
   adb shell uiautomator dump /sdcard/ui.xml
   adb pull /sdcard/ui.xml .\ui_dump.xml
   ```
3. **Extract signals** (resource-ids, content-descs, text, scrollable nodes)
   with a small PowerShell `[regex]::Matches(...)` script. Look for:
   - Whether resource-ids are real or stripped (`(name removed)` → ID approach
     is useless, must use content-descs).
   - A stable per-reel identifier for the fingerprint (channel/creator handle).
   - Engagement markers (like / comment / reaction / share / remix / sound).
   - Ad markers (Sponsored / Visit advertiser / Paid partnership / CTA text).
4. **Rewrite the detector** following the content-description fingerprint
   pattern (see `YouTubeShortsDetector.kt` / `FacebookReelsDetector.kt`):
   single bounded DFS → ad gate → engagement gate → fingerprint-change +
   600ms cooldown.
5. **Build, install, launch, verify** (see Build & Run). After a fresh
   *uninstall*, the Accessibility + Usage permissions reset and must be
   re-granted. `adb install -r` preserves them.
6. Clean up temp `*_dump.xml` / `*.ps1` files afterwards.

> Tip: `BrainPal` (`com.brainrot.android`) is installed on the test device as
> the accuracy reference. Both its and ScrollIQ's accessibility services can be
> enabled simultaneously for side-by-side comparison.

## Session Work Log (detector accuracy + bug fixes)

Chronological record of fixes made while tuning count accuracy against BrainPal:

1. **YouTube Shorts — ads counted as shorts.** Added ad detection (ad view-ids
   + ad text) so ads are skipped.
2. **YouTube Shorts — count incremented without scrolling.** Root cause: YT
   fires `CONTENT_CHANGE_TYPE_SUBTREE` continuously during playback. Fixed with
   a per-reel content-desc fingerprint (channel handle); count only on change.
3. **YouTube Shorts — zero counts.** Root cause: modern YT Shorts exposes **no
   scrollable nodes / no `TYPE_VIEW_SCROLLED`**, so the scroll-gated version
   never fired. Fixed by switching to fingerprint-on-content-desc (no scroll
   dependency).
4. **YouTube Shorts — one swipe counted twice.** Root cause: progressive field
   loading changed the fingerprint twice. Fixed by using a single
   highest-priority fingerprint field + 600ms cooldown.
5. **YouTube Shorts — ads still slipped through.** Replaced fragile ad-CTA
   enumeration with an **engagement-rail requirement** (organic shorts always
   expose like/comment/remix/sound; ads don't). Verified working.
6. **Facebook Reels — not counting at all.** Root cause: FB strips all
   resource-ids to `(name removed)`, so the hardcoded pager-id match never set
   `inReels`. Rewrote to the content-description fingerprint pattern (creator
   handle + engagement gate + ad skip + cooldown). Verified working.
7. **`challenges_repository.recompute` — counted out-of-window days.** It
   computed `endLimit` but never bounded the query, so days/score from *after*
   the challenge window were counted (a user could "complete" a 7-day challenge
   with good days weeks later; `score` accumulated unbounded). Fixed by adding
   `.lt('date', toStr)` so the query covers exactly `[start, endLimit)`.
8. **Invite link in onboarding was malformed and unattributed.** Two issues:
   (a) `.env.example` shipped `REFERRAL_BASE_URL=https://scroll-iq.vercel.app/`
   with a trailing slash, so `ReferralRepository.buildLink` produced
   `https://scroll-iq.vercel.app//invite?ref=CODE` (double slash) for
   signed-in users. (b) During onboarding the user had no `referral_code`
   yet (it's minted by the `handle_new_user` trigger at sign-up), so
   `shareInvite()` fell into its catch branch and shared the bare base URL —
   a homepage link with no `?ref=`, killing referral attribution. Fixed by
   stripping trailing slashes in `Env.referralBaseUrl`, switching the
   not-signed-in fallback to `${baseUrl}/invite`, and adding
   `test/referral_link_test.dart` to lock in the behavior.
9. **Restructured onboarding to make the invite actually work.** Moved
   `ChallengeFriendsScreen` out of the pre-login `OnboardingScreen` (Story →
   Permissions → Demo only) and into a new post-login `PostLoginInviteScreen`
   gated behind route `/welcome-invite`. New `PostLoginInviteController`
   (`features/onboarding/providers.dart`) is a `ChangeNotifier` merged into
   the GoRouter `refreshListenable` alongside `_AuthRefreshNotifier`; the
   `redirect` callback now forces freshly authenticated first-time users
   through `/welcome-invite` before `/home`. Existing users (who have
   `prefOnboardingDone=true` but no invite flag) are auto-migrated to
   "already shown" so they don't see an unexpected screen on update. With
   the screen running post-auth, `shareInvite()` always hits the success
   branch and builds a proper `${baseUrl}/invite?ref=<CODE>` link — the
   viral loop now works end-to-end.

### Detector status snapshot

| App | Approach | Migrated | Verified on device | Registered in service |
|-----|----------|----------|--------------------|-----------------------|
| YouTube Shorts | content-desc fingerprint | ✅ | ✅ | ✅ |
| Facebook Reels | content-desc fingerprint | ✅ | ✅ | ✅ (katana + lite) |
| Instagram Reels | content-desc fingerprint | ✅ | ❌ not yet | ✅ |
| TikTok | content-desc fingerprint | ✅ | ❌ not yet | ❌ unregistered |
| Snapchat Spotlight | content + resource-id fingerprint | ✅ | ✅ | ✅ |

> **Next:** verify the two migrated-but-unverified detectors on a device
> using the Debugging Playbook above. After verification:
>
> 1. **Instagram** — already registered; no service changes needed, just
>    confirm counts match BrainPal on a side-by-side scroll.
> 2. **TikTok** — re-enable by adding entries to the `detectors` map in
>    `ReelCounterAccessibilityService.kt` *and* to `trackedApps` in
>    `lib/core/constants/app_constants.dart`. The accessibility service config
>    XML doesn't whitelist packages so no manifest change is needed.
>
> Tighten the per-app `creatorSignals` / `soundSignals` / `engagementSignals`
> / `adSignals` / `surfaceMarkers` lists in each detector based on what the
> on-device UI dump actually emits — the values committed are best-effort
> ports of the proven pattern, not field-confirmed.
>
> **Snapchat lesson (applies to any future detector):** always confirm signal
> strings against the *live* `getRootInActiveWindow()` tree, not just the
> static `uiautomator dump`. Snap's `opera_viewer` / `spotlight_container`
> resource-ids appear in the dump but are **absent** from the live tree; only
> the `ngs_spotlight` bottom-nav id and `opera*` content-descs survive. Snap
> also exposes no creator/engagement content-descs at all, so the standard
> engagement-gate pattern doesn't apply there.

## Roadmap (Not Yet Implemented)

- iOS Screen Time API implementation
- Bring TikTok reel counting online (detector migrated to the content-desc
  fingerprint pattern, currently unregistered pending on-device verification)
- Detailed Accessibility Service → view content hashing for exact reel identification
- Custom friend challenges (not just default 7-day detox)
- Streak & weekly digest via Supabase Edge Functions + Cron
- In-app purchases for premium analytics
- Weekly leagues (Bronze → Diamond, Duolingo-style)
- OEM auto-start deeplinks (Xiaomi/OPPO/Vivo specific intents)
