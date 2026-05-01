# Captchala iOS / macOS Demo

A SwiftUI app demonstrating end-to-end Captchala SDK integration. Runs on
iOS simulator/device, **Mac Catalyst** (My Mac as a Catalyst app), and
native macOS — all from the same target.

## Links

- Website: <https://captcha.la>
- Dashboard: <https://dash.captcha.la>
- iOS SDK docs: <https://captcha.la/docs/sdk/ios>
- All SDK docs: <https://captcha.la/docs>
- Support: <support@captcha.la>

## Requirements

- macOS 13+ with Xcode 15+
- iOS 15+ (device or simulator)
- macOS 11+ for Mac Catalyst target

## Setup

1. Sign in to <https://dash.captcha.la> and download the latest iOS
   release archive. It contains two artifacts:
   - `Captchala.xcframework`
   - `Captchala.bundle`
2. Drop both into the **repo root** (next to `Example.xcodeproj`):
   ```
   .
   ├── Example.xcodeproj
   ├── Example/
   ├── Captchala.xcframework   ← drop here
   ├── Captchala.bundle        ← drop here
   ├── README.md
   └── LICENSE
   ```
3. The Xcode project already references both by file name — no manual
   linking needed.

## Run

```bash
open Example.xcodeproj
```

In Xcode pick a destination (iPhone simulator / Mac Catalyst / connected
device) and press **Cmd+R**.

## App key

The demo hard-codes a public demo `appKey` in `ContentView.swift`. Replace
with your own from <https://dash.captcha.la> for real testing.

## Updating the SDK

Replace the `Captchala.xcframework/` and `Captchala.bundle/` folders with
the new versions from the dashboard. Rebuild — no project changes needed.

## License

MIT — see [LICENSE](./LICENSE).
