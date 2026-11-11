# The app's own icon and store artwork

Milestone **Launch and listen** (`launch`), due 28 February 2027. Issue `app-icon` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

## Why it matters

On a landlord's home screen the app shows Flutter's default blue logo, which says nothing about
whose app it is and looks like a test build. A recognisable icon of its own, and screenshots that
show the real screens in English and Urdu, are what a landlord sees first in Google Play and the App
Store, and both stores need them before a listing can go live.

## What is true now

Facts marked _(summary)_ or "secondary" were not read on the platform owner's own page; confirm them
in the consoles.

- **Every launcher icon is Flutter's default.** On 11 November 2026 the Android
  `mipmap-hdpi/ic_launcher.png` was byte-identical to Flutter's template, and the iOS 1,024 px icon
  and the web icons are the templates too. Android has only bitmap `mipmap-*dpi` folders and no
  `mipmap-anydpi-v26`, so there is no adaptive or monochrome icon
  ([res/](../../app/android/app/src/main/res/)). The web manifest still carries Flutter's colour
  `#0175C2` ([manifest.json](../../app/web/manifest.json)).
- **The website already has a mark:** a white house outline on `#1D3F8F`
  ([favicon.svg](../../website/public/favicon.svg)), the brand blue of the design tokens
  ([maalik.tokens.json](../../design/tokens/maalik.tokens.json)). `design/icons/icons.json` is the
  source of the in-app icon font, not of launcher icons ([design/icons/](../../design/icons/)).
- **Generated files already follow one pattern:** `make tokens` and `make icons` rebuild outputs,
  and their `-check` targets fail CI on stale ones ([Makefile](../../Makefile),
  [conventions](../agents/conventions.md#generated-files)).
- **Android** wants 108 dp foreground, background and monochrome layers, with the logo between 48 dp
  and 66 dp; adaptive icons start at API 26, and the app's minimum is API 24. From Android 16 QPR 2
  the system themes apps that ship no monochrome layer itself
  ([Android adaptive icons](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive)).
- **Google Play** wants a full-square 512 px 32-bit PNG in sRGB of at most 1,024 KB; Play rounds the
  corners and adds the shadow
  ([Play icon specification](https://developer.android.com/google-play/resources/icon-design-specifications)).
  A 1,024 × 500 feature graphic and 2 to 8 screenshots per device type are required _(secondary;
  sources disagree on the minimum)_
  ([AppRadar](https://appradar.com/blog/android-app-screenshot-sizes-and-guidelines-for-google-play)).
- **iOS 26** wants a layered 1,024 px Icon Composer file with default, dark, clear and tinted
  appearances, and avoids text. Since 28 October 2026 Apple's guidance says a supplied bitmap is
  split into two layers, with Liquid Glass applied only to large simple shapes
  ([Apple HIG, app icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)).
- **Sources disagree on older iOS.** Apple's WWDC26 session says to remove the asset-catalogue icon
  once an `.icon` file is added
  ([session 8012](https://developer.apple.com/videos/play/wwdc2026/8012/)); a third-party guide
  keeps it so older iOS still finds an icon
  ([AppCherish](https://appcherish.com/blog/how-to-create-a-liquid-glass-app-icon-with-icon-composer-a-step-by-step-guide/)).
  The app supports iOS 15 and later
  ([project.pbxproj](../../app/ios/Runner.xcodeproj/project.pbxproj)).
- **Tooling.** `flutter_launcher_icons` does not generate Icon Composer files
  ([issue 657](https://github.com/fluttercommunity/flutter_launcher_icons/issues/657)).
- **Web maskable icons** keep the logo inside a centred circle of 40% radius
  ([web.dev](https://web.dev/articles/maskable-icon)).
- **Screenshots.** The browser UAT already drives 14 journeys on a seeded local stack with
  Playwright ([uat.md](../../docs/uat.md)); there are no Flutter integration tests on Android or iOS
  (NFR-07, [REQUIREMENTS.md](../../.planning/REQUIREMENTS.md)), and nothing captures store
  screenshots.

## Design

- **One master, no text.** One SVG master in `design/app-icon/` (to be created): a simple filled
  shape that reads at 24 px, with a one-colour version for Android's monochrome layer and iOS's
  tinted appearance. Text would vanish under Liquid Glass and could not serve both scripts. The
  website's house on brand blue is the natural starting point, so the site and the app match; the
  owner decides.
- **A generator, not hand-made files.** `tool/design/build_app_icons.py` with `make app-icons` and
  `make app-icons-check`, run in CI beside `tokens-check`. It writes:
  - Android: `mipmap-anydpi-v26/ic_launcher.xml` with foreground, background and monochrome layers,
    and legacy PNG mipmaps for API 24 and 25;
  - web: `favicon.png`, the 192 and 512 px icons, the maskable icons with the logo inside the 40%
    circle, and the manifest's colours from the tokens;
  - the website's favicon and touch icon, if the mark changes;
  - the Play 512 px icon.
- **iOS by hand, once.** An `AppIcon.icon` made in Icon Composer and committed as source; this needs
  a Mac. Keep a generated asset-catalogue icon for iOS 15 to 18 unless a simulator test shows Xcode
  produces one from the `.icon` file.
- **Screenshots from code.** A fictional portfolio seeded by script (fictional names, no real phone
  numbers or CNICs), captured in English and in right-to-left Urdu by integration tests on an
  Android emulator and, in the macOS release job, an iOS simulator. The sets can then be redone for
  every release. Captions, if any, go through the Urdu review.

### Residence (decision 1)

The screenshot set tells both stories: a resident landlord recording rent and sending a receipt, and
an owner abroad confirming the cash their caretaker collected, with the two times ("in Lahore", "in
London") once residence ships.

### Letterheads (decision 2)

One screenshot shows a receipt on a fictional business's letterhead, made with the builder. If
letterheads are not ready at the first submission, the set is updated when they ship.

## Work

1. **Owner:** choose the mark and its colours, including the one-colour version.
2. **M:** SVG master, the generator, `make app-icons` and its CI check; Android adaptive, monochrome
   and legacy icons; web icons and manifest colours.
3. **M:** iOS `AppIcon.icon` and the decision on the older-iOS fallback, tested on iOS 15 and iOS 26
   simulators.
4. **S:** Play 512 px icon and the 1,024 × 500 feature graphic, with an Urdu variant.
5. **M:** screenshot harness and fictional seed; the Android phone set in English and Urdu (first
   half of the former L item).
6. **M:** the iPhone set in English and Urdu from the macOS job, and the iPad set if iPad stays
   (second half).

## Depends on / Unblocks

- **Depends on:** the owner's choice of mark, a Mac for the iOS icon, [urdu-review](urdu-review.md)
  for Urdu captions and the feature graphic's Urdu text.
- **Unblocks:** [play-store](play-store.md) and [app-store](app-store.md), which cannot submit
  without the icon, the feature graphic and the screenshots.

## Risks

- **Thin strokes disappear at small sizes or under Liquid Glass.** Use filled shapes and check the
  icon at 24 px and in every appearance before committing.
- **Poor automatic theming** if the monochrome layer is missing. The generator always writes one,
  and the check fails without it.
- **A blank icon on older iOS** if the fallback is removed untested. Test on an iOS 15 simulator
  before release.
- **Stale screenshots.** Generate them from code, and regenerate when a captured screen's goldens
  change.
- **Real data in a screenshot.** Only the fictional seed is ever captured, and the reviewer checks
  every image, as with goldens.

## Done when

- [ ] No Flutter default icon or colour remains on Android, iOS or the web app.
- [ ] `make app-icons-check` passes in CI and fails when an output is stale.
- [ ] The Android icon looks right under the circle and squircle masks and as a themed icon.
- [ ] The iOS icon renders in default, dark, clear and tinted appearances, and shows on the oldest
      supported iOS.
- [ ] The maskable web icons pass the 40% safe-zone preview.
- [ ] Both stores have the icon, the feature graphic and screenshot sets in English and Urdu, made
      from fictional data.

## Questions for the owner

- What is the mark: the website's house, a key, a door, a ledger?
- Should an Urdu letterform appear in it at all?
- Screenshot style: plain screens, or framed with captions?
- Which flows come first: the overdue list, a receipt, the caretaker handover?
