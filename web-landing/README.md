# ScrollIQ — `web-landing/`

Static landing site for **scrolliq.app**. Two jobs:

1. Bounce invited users into the app (`/invite?ref=CODE`) or to the right app store.
2. Serve the verification files Android & iOS need to treat the domain as an
   App Link / Universal Link target:
   - `/.well-known/assetlinks.json`
   - `/.well-known/apple-app-site-association`

## Layout

```
web-landing/
├── index.html                       # marketing home
├── invite/
│   └── index.html                   # referral landing (reads ?ref=CODE)
├── .well-known/
│   ├── assetlinks.json              # Android App Links
│   └── apple-app-site-association   # iOS Universal Links (no extension)
├── vercel.json                      # routing + content-type headers
└── README.md
```

## Before you deploy — fill in placeholders

### 1. `.well-known/assetlinks.json` — Android SHA-256 fingerprint(s)

Replace the `REPLACE_WITH_...` strings with the SHA-256 fingerprint of the
**Play App Signing key** (and optionally your upload key, which makes internal
testing tracks work too).

- **Play App Signing key**: Play Console → your app → **Setup → App integrity
  → App signing → App signing key certificate** → copy `SHA-256 certificate
  fingerprint`.
- **Upload key (local)**:
  ```bash
  keytool -list -v \
    -keystore scrolliq-upload-key.jks \
    -alias upload
  ```

You can list multiple fingerprints in `sha256_cert_fingerprints`. Keep the
file as a JSON **array** at the top level — that is what Google's verifier
expects.

### 2. `.well-known/apple-app-site-association` — iOS Team ID

Once iOS ships, replace `REPLACE_TEAMID` with your 10-character Apple Developer
Team ID (Apple Developer → Membership). Until then the file is harmless — it
just isn't verified by any Apple device because no app declares the
Associated Domain yet.

> Note: the file has **no extension** and must be served as
> `application/json`. `vercel.json` already sets that header.

### 3. `invite/index.html` — App Store ID (later)

Search for `IOS_APP_ID = 'XXXXXXXXX'` and replace with your numeric App Store
ID once the iOS app is live. You can also uncomment the
`<meta name="apple-itunes-app">` tag for the Safari smart banner.

### 4. (Optional) Open Graph image

Both pages reference `https://scrolliq.app/og.png`. Drop a 1200×630 PNG at
`web-landing/og.png` for nice link previews on WhatsApp, Telegram, iMessage,
Twitter/X.

## Deploy to Vercel

### Option A — CLI (fastest)

```bash
cd web-landing
npm i -g vercel       # one-time
vercel login
vercel                # preview deploy → unique URL
vercel --prod         # production deploy
```

### Option B — Git import

1. Push the repo to GitHub/GitLab.
2. vercel.com → **Add New → Project** → import the repo.
3. **Root Directory**: `web-landing`.
4. **Framework Preset**: *Other*.
5. **Build Command**: *(empty)*.
6. **Output Directory**: `.` (the project root).
7. Deploy.

## Attach the domain

1. Vercel → Project → **Settings → Domains → Add** → `scrolliq.app`
   (and `www.scrolliq.app`, with a redirect to apex).
2. Vercel shows the DNS records to add. At your registrar:
   - Apex `scrolliq.app` → `A 76.76.21.21` **or** point the nameservers to
     `ns1.vercel-dns.com` / `ns2.vercel-dns.com`.
   - `www.scrolliq.app` → `CNAME cname.vercel-dns.com`.
3. Wait for SSL to provision (usually < 1 minute).

## Verify the App Link works

```bash
# 1. File is reachable with the right content-type
curl -I https://scrolliq.app/.well-known/assetlinks.json
# expect: content-type: application/json

# 2. Google's hosted Digital Asset Links validator
# https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://scrolliq.app&relation=delegate_permission/common.handle_all_urls&prettyPrint=true
```

On a device that has ScrollIQ installed:

```bash
# Force re-verify (after publishing assetlinks.json or after install)
adb shell pm verify-app-links --re-verify com.scrolliq.app
adb shell pm get-app-links com.scrolliq.app
# Look for: scrolliq.app  ... verified

# Try a real invite link
adb shell am start -a android.intent.action.VIEW \
  -d "https://scrolliq.app/invite?ref=ABCD1234"
```

If verification succeeds, the HTTPS link opens the app directly (no browser
flash). If it fails, the link opens the web page, which then tries the
`scrolliq://invite?ref=...` custom scheme as a fallback.

## Hooking the Flutter app up

In your project root `.env`:

```
REFERRAL_BASE_URL=https://scrolliq.app
```

`lib/features/referral/referral_service.dart` already builds
`<base>/invite?ref=<code>` from this — nothing else to change once the site
is live.

## Local preview

Any static server works. Two zero-install options:

```bash
# Python
cd web-landing
python -m http.server 5173
# → http://localhost:5173/invite?ref=TEST1234
```

```bash
# Vercel CLI (matches production routing/headers)
vercel dev
```
