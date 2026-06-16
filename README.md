# ScrollIQ

> **Reclaim your attention.** ScrollIQ converts your screen-time on Reels, Shorts, TikTok and other addictive apps into a simple **Brain Score** out of 100, then lets you compete with friends through leaderboards and challenges.

Built with **Flutter (Material 3)**, **Riverpod**, **Supabase**, **Firebase Cloud Messaging**, and **PostHog**.

---

## Table of contents

1. [Architecture](#architecture)
2. [Project layout](#project-layout)
3. [Prerequisites](#prerequisites)
4. [Local setup](#local-setup)
5. [Supabase setup](#supabase-setup)
6. [Google Sign-In setup](#google-sign-in-setup)
7. [Firebase / FCM setup](#firebase--fcm-setup)
8. [PostHog analytics](#posthog-analytics)
9. [Running the app](#running-the-app)
10. [Testing](#testing)
11. [Building a release APK / AAB](#building-a-release-apk--aab)
12. [Roadmap](#roadmap)

---

## Architecture

Clean architecture, organised by feature:

```
lib/
├── core/                       # cross-cutting: theme, routing, env, DI
│   ├── constants/
│   ├── di/
│   ├── env/
│   ├── errors/
│   ├── router/
│   └── theme/
├── features/
│   ├── auth/                   # email + Google sign-in, profile
│   ├── onboarding/             # 3 slides + UsageStats permission
│   ├── usage_tracking/         # Android UsageStatsManager, abstraction
│   ├── dashboard/              # Brain Score Engine + UI
│   ├── leaderboard/            # global daily leaderboard
│   ├── friends/                # search, requests, accept/decline
│   ├── challenges/             # 7-Day Scroll Detox + custom challenges
│   ├── profile/                # stats, sign-out, settings
│   └── notifications/          # FCM + flutter_local_notifications
├── shared/                     # widgets, formatters
└── main.dart
```

Each feature follows:

```
feature_name/
├── data/         # repository implementations (Supabase calls)
├── domain/       # plain Dart entities + use-case classes
├── presentation/
│   ├── screens/
│   └── widgets/
└── providers.dart
```

---

## Project layout

| Path                                            | Purpose                                         |
|-------------------------------------------------|-------------------------------------------------|
| `pubspec.yaml`                                  | Flutter & package dependencies                  |
| `.env.example`                                  | Env-variable template (copy to `.env`)          |
| `supabase/schema.sql`                           | Postgres tables, views, RLS policies            |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Native UsageStats bridge                      |
| `lib/main.dart`                                 | App entry-point (Supabase + Firebase init)      |
| `test/brain_score_calculator_test.dart`         | Unit tests for the score engine                 |

---

## Prerequisites

- **Flutter SDK** 3.22+ (`flutter --version`)
- **Android Studio** with Android SDK 34, JDK 17
- A **Supabase** project (free tier OK)
- A **Firebase** project for FCM
- Optional: a **PostHog** project for analytics

---

## Local setup

```bash
git clone <your-fork-url> scrolliq
cd scrolliq

# 1. Install dependencies
flutter pub get

# 2. Create your env file
cp .env.example .env
# then fill in SUPABASE_URL, SUPABASE_ANON_KEY, GOOGLE_WEB_CLIENT_ID, etc.

# 3. Sanity check
flutter analyze
flutter test
```

---

## Supabase setup

1. Create a new project on [supabase.com](https://supabase.com).
2. Go to **SQL Editor** → paste the contents of `supabase/schema.sql` → **Run**.
   This creates:
   - `users`, `daily_usage`, `friends`, `challenges`, `challenge_participants` tables
   - `leaderboard_today` and `user_stats` views
   - RLS policies for every table
   - A trigger that creates a `users` row whenever someone signs up via `auth.users`
   - The default **7-Day Scroll Detox** challenge
   - The `search_users(q text)` RPC used by the friend search screen
3. **Authentication → Providers**:
   - Enable **Email** (turn on or off "Confirm email" depending on your launch strategy).
   - Enable **Google**:
     - Authorized client ID: paste your **Web Client ID** from GCP.
     - You will need it again on the device for `GoogleSignIn`.
4. **Settings → API**: copy `URL` and `anon public` key into `.env`.

---

## Google Sign-In setup

ScrollIQ uses Google Sign-In with the **ID-token flow** (`signInWithIdToken`) so authentication happens directly against Supabase (no browser).

1. Open the [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials.
2. Create an **OAuth Client ID**:
   - **Web application** (this is the one Supabase uses) → copy its client ID into `GOOGLE_WEB_CLIENT_ID`.
   - **Android**: package = `com.scrolliq.app`, SHA-1 = output of `./gradlew signingReport`.
   - **iOS**: bundle id `com.scrolliq.app` → copy client ID into `GOOGLE_IOS_CLIENT_ID`.
3. In your Supabase project, go to **Authentication → Providers → Google** and add the **Web Client ID** to the *Authorized Client IDs* list.

---

## Firebase / FCM setup

1. Create a Firebase project and add Android + iOS apps.
2. Place the resulting config files:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
3. Enable the Google Services plugin:
   - In `android/app/build.gradle`, uncomment `id "com.google.gms.google-services"`.
   - In `android/settings.gradle`, uncomment the `com.google.gms.google-services` plugin entry.
4. Send notifications via the **Firebase Cloud Messaging API** (HTTP v1) from your backend or a Cloud Function. The user's FCM token is stored in `users.fcm_token` and refreshed on every app launch.

### Notification copy ideas

- "You spent 3h 42m on social apps today."
- "Your Brain Score dropped 12 points."
- "Your friend beat you on today's leaderboard."
- "Keep your streak alive."

---

## PostHog analytics

PostHog is configured via Android meta-data (`android/app/src/main/AndroidManifest.xml` + `res/values/strings.xml`).
For your real key, replace the `posthog_api_key` string in `strings.xml` (or override per-flavor with `resValue` in `build.gradle`).

The `Analytics` provider in `lib/core/di/providers.dart` exposes:

```dart
ref.read(analyticsProvider).capture('sign_up', props: {'method': 'email'});
ref.read(analyticsProvider).identify(user.id);
ref.read(analyticsProvider).reset();
```

---

## Running the app

```bash
# Plug in an Android device or boot an emulator
flutter run

# Hot-restart during development:
r          # hot reload
R          # hot restart
```

The first launch shows the splash → onboarding → permission request (UsageStats settings) → login.

> **Note:** `UsageStatsManager` access cannot be granted at runtime — Android opens the *Usage access* settings panel, where the user must enable ScrollIQ manually.  The app gracefully handles "not granted" by showing zero usage and a banner on the dashboard.

---

## Testing

```bash
flutter test
```

The default test suite includes `test/brain_score_calculator_test.dart`, which covers:

- Zero-usage → 100 score
- Sub-threshold usage → no penalty
- Each penalty (screen-time / social / late-night)
- Combined penalties clamped to 0
- Category mapping (Focus Master, Healthy, Distracted, Doomscroller, Brain Melt)

---

## Building a release APK / AAB

1. Generate a keystore (one-time):
   ```bash
   keytool -genkey -v -keystore scrolliq-upload-key.jks \
           -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties`:
   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/absolute/path/to/scrolliq-upload-key.jks
   ```
3. Build:
   ```bash
   flutter build apk --release         # standalone APK
   flutter build appbundle --release   # Play Store AAB
   ```
4. Upload `build/app/outputs/bundle/release/app-release.aab` to the Play Console.

### Play Store listing notes

- The `PACKAGE_USAGE_STATS` permission is *not* a runtime permission — Google Play does **not** require a Sensitive permissions declaration for it. However, your privacy policy must explain that ScrollIQ reads aggregate foreground usage to compute the Brain Score.

---

## Roadmap

- iOS implementation of `UsageTrackingService` (Screen Time API + Family Controls extension).
- Detailed reels/shorts detection via Accessibility Service (opt-in).
- Custom challenges with friends.
- Streak & weekly digest notifications via Supabase Edge Functions / Cron + FCM HTTP v1.
- In-app purchases for premium analytics.
