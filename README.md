# SKY · Skyline Exchange — native iPhone app (SwiftUI)

A native SwiftUI app for [sky.shinkaicc.com](https://sky.shinkaicc.com) whose screens follow
the website's phone layout: same pages, colours, fonts, Lucide icons, VIP cards and texts in
five languages. It talks to the same `/api/v1` backend (demo funds only).

## Download

Every push to the `swift` branch is built, tested and screenshotted on GitHub Actions; the
results are files of the **swift-ci** pre-release:

- `SKY-swift.ipa` — unsigned IPA, install with Sideloadly
- `screenshots.zip` — every screen in the iPhone simulator (demo data)
- `status.txt` — build errors and test results

When this branch is merged into `main`, the usual link serves this app:
https://github.com/Shinkai08/SKY/releases/latest/download/SKY.ipa

### Install (Windows, free Apple ID)

1. Install iTunes (from apple.com, not the Microsoft Store) and Sideloadly.
2. Connect the iPhone by cable, open Sideloadly, drop in the IPA, enter your Apple ID, Start.
3. iPhone: Settings → General → VPN & Device Management → trust your Apple ID.
   iOS 16+: Settings → Privacy & Security → Developer Mode → on.

Free Apple ID signatures expire after 7 days; re-sign with Sideloadly.

## Layout of the code

- `SKY/Core` — API client (session cookie, lenient JSON, demo mode), preferences and
  translations, login/account session, router, Binance feeds.
- `SKY/UI`, `SKY/Shell` — shared components (cards, buttons, tabs, avatar, VIP card), top bar,
  tab bar, full-screen pages.
- `SKY/Screens`, `SKY/Trade`, `SKY/Games` — the pages.
- `SKY/Generated` — Lucide icon paths and brand marks (do not edit).
- `SKY/Resources` — strings, privacy notice, images, fonts copied from the website; demo data.

## Keeping in step with the website

Run from this folder (the website lives in `D:\SKY\development\apps\web`):

```bash
node scripts/build-icons.mjs     # Lucide icons used by the site → SKY/Generated
node scripts/sync-web.mjs        # strings, privacy notice, images
python scripts/build-fonts.py    # Inter / Cinzel / Song font files
```

Demo data for the screenshots comes from a **local** test server:
`node scripts/record-demo.mjs http://127.0.0.1:8091 <email> <password>`.

On a Mac: `brew install xcodegen && xcodegen generate`, then open `SKY.xcodeproj`.
