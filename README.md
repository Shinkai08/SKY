# SKY · Skyline Exchange — iPhone app

Native iOS app for [sky.shinkaicc.com](https://sky.shinkaicc.com), built with
React Native + Expo (SDK 58, TypeScript). It talks to the same `/api/v1`
backend as the website, with demo (simulated) funds only.

## Download

Every push to `main` builds an **unsigned** IPA on GitHub Actions:

**https://github.com/Shinkai08/SKY/releases/latest/download/SKY.ipa**

Install on Windows with a free Apple ID:

1. Install iTunes (from apple.com, not the Microsoft Store) and Sideloadly.
2. Connect the iPhone by cable, open Sideloadly, drop in `SKY.ipa`, enter your Apple ID, Start.
3. iPhone: Settings → General → VPN & Device Management → trust your Apple ID.
   iOS 16+: Settings → Privacy & Security → Developer Mode → on.

Free Apple ID signatures expire after 7 days; re-sign with Sideloadly.

## What's inside

- Native tab bar (Home · Markets · Trade · Games · Assets), stacks with large titles and swipe-back, SF Symbols, haptics, Face ID lock.
- Markets, perpetual and spot trading (grouped order book, candles, positions with TP/SL, margin and leverage tools), assets and deposits,
  VIP, community, profiles, predictions, Crash and 7-seat Blackjack with in-app fairness checks.
- `src/web/` is copied from the website (strings, fee tables, market hooks) by `node scripts/sync-web.mjs`.

## Develop

```bash
npm install
npx expo start          # scan the QR code with Expo Go on the iPhone
npx tsc --noEmit && npx jest
```

Point the app at another server with `EXPO_PUBLIC_SKY_URL=https://… npx expo start`.
