# `web-landing/downloads/`

Hosts the direct-download Android build linked from the home page and invite
page (**Download for Android**).

The site links to **`/downloads/scrolliq.apk`**, so the release APK must live
here with that exact filename.

## Build & drop in the APK

From the project root:

```bash
# 1. Build the signed release APK (needs android/key.properties configured —
#    see the root README "Building a release APK / AAB").
flutter build apk --release

# 2. Copy it here with the name the site expects.
#    Windows (PowerShell / cmd):
copy build\app\outputs\flutter-apk\app-release.apk web-landing\downloads\scrolliq.apk

#    macOS / Linux:
cp build/app/outputs/flutter-apk/app-release.apk web-landing/downloads/scrolliq.apk
```

> No signing key yet? You can ship an **unsigned/debug** build for testing with
> `flutter build apk --debug` and copy `app-debug.apk` instead — but a release
> build signed with a stable key is required so users can update in place later
> without uninstalling.

## Deploy

```bash
cd web-landing
vercel --prod
```

Then verify the download serves correctly:

```bash
curl -I https://scroll-iq.vercel.app/downloads/scrolliq.apk
# expect: content-type: application/vnd.android.package-archive
#         content-disposition: attachment; filename="scrolliq-1.0.0.apk"
```

## Notes

- Bump the `filename` in `vercel.json` (`Content-Disposition`) and the version
  label in `index.html` whenever you ship a new version.
- APK downloads can't carry a Play install-referrer, so an invited user's
  `?ref=CODE` isn't auto-applied on first install. After installing they can
  re-tap the invite link (or the `scrolliq://invite?ref=…` deep link) to have
  the friend request created.
