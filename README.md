# SKY iOS shell

A minimal iOS app that opens https://sky.shinkaicc.com full screen (WKWebView).
No exchange code lives here: the app always shows the live site, so web updates
reach the app without a rebuild.

## Build

GitHub Actions builds an **unsigned** `SKY.ipa` on every push to `main`
(or run it by hand: Actions → Build IPA → Run workflow). Download it from the
run's **Artifacts** section.

Locally on a Mac: `brew install xcodegen && xcodegen generate`, then open
`SKY.xcodeproj`.

## Install (Windows, free Apple ID)

1. Install iTunes (from apple.com, not the Microsoft Store) and Sideloadly.
2. Connect the iPhone by cable, open Sideloadly, drop in `SKY.ipa`, enter your
   Apple ID, Start.
3. On the iPhone: Settings → General → VPN & Device Management → trust your
   Apple ID. On iOS 16+ also turn on Settings → Privacy & Security → Developer Mode.

Free Apple ID signatures expire after 7 days; re-sign with Sideloadly.
