# The app's own icon and store artwork

Milestone **Launch and listen** (`launch`), due 28 February 2027. Issue `app-icon` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

Until 12 November 2026 the app showed Flutter's default blue logo on a landlord's home screen,
which said nothing about whose app it was and looked like a test build. A recognisable icon of its
own, and screenshots that show the real screens in English and Urdu, are what a landlord sees first
in Google Play and the App Store, and both stores need them before a listing can go live.

## What is true now

Facts marked _(summary)_ or "secondary" were not read on the platform owner's own page; confirm them
in the consoles.

- **The mark is chosen: the twin gables** (the owner, 23 November 2026, D-26): a filled white
  house on the brand's cobalt, `#1D3F8F` ([The mark](#the-mark), below). It replaced the website's
  white house outline, a 2-unit stroke, which the icons had used as a starting point. It is defined
  once, in [`brand.ts`](../../website/src/lib/brand.ts), in the colours of the design tokens
  ([maalik.tokens.json](../../design/tokens/maalik.tokens.json)). `design/icons/icons.json` is the
  source of the in-app icon font, not of launcher icons ([design/icons/](../../design/icons/)).
- **The launcher icons are the app's own** (since 12 November 2026, #51). `make app-icons`
  ([`build_app_icons.py`](../../tool/design/build_app_icons.py)) draws them all from the mark and
  the tokens: Android's adaptive icon, with the same layer as its monochrome one, and PNGs for
  Android 7 ([res/](../../app/android/app/src/main/res/)); the iOS asset catalogue's 1,024 px icon
  in its default, dark and tinted appearances; the web app's favicon, icons, maskable icons and iOS
  home-screen icon, and the manifest's name and colours
  ([manifest.json](../../app/web/manifest.json)); and the Play listing's 512 px icon.
  `make app-icons-check` runs in CI's hygiene job beside `tokens-check`, like the repository's other
  generated files ([conventions](../agents/conventions.md#generated-files)). The website draws its
  own favicons, touch icon, logo and Open Graph cards from the same definition (`npm run og`).
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
- **Screenshots.** The browser UAT already drives the landlord's journeys on a seeded local stack
  with Playwright ([uat.md](../../docs/uat.md)); there are no Flutter integration tests on Android
  or iOS (NFR-07, [REQUIREMENTS.md](../../.planning/REQUIREMENTS.md)), and nothing captures store
  screenshots.

## Design

- **One master, no text.** The master is the glyph's outline, `MARK_GLYPH_PATH` in
  [`brand.ts`](../../website/src/lib/brand.ts): a simple filled shape that reads at 16 px. Its
  outline alone is the one-colour version, for Android's monochrome layer and iOS's tinted
  appearance. Text would vanish under Liquid Glass and could not serve both scripts. The website
  and the app draw the same mark.
- **A generator, not hand-made files.** `tool/design/build_app_icons.py` with `make app-icons` and
  `make app-icons-check`, run in CI beside `tokens-check`. It writes:
  - Android: `mipmap-anydpi-v26/ic_launcher.xml` with foreground, background and monochrome layers
    (the foreground a filled vector), and legacy PNG mipmaps for API 24 and 25;
  - iOS: the asset catalogue's 1,024 px icon, plain, dark and tinted;
  - web: `favicon.png`, the 192 and 512 px icons, the maskable icons with the house at 15/16 of its
    size, inside the 40% circle, a 180 px full square for iOS's home screen (the `apple-touch-icon`,
    the house at the tile's scale as on the iOS icon), and the manifest's colours from the tokens;
  - the Play 512 px icon.

  The website's favicons, touch icon and Open Graph cards come from the same definition through
  `npm run og` in `website/`.

- **iOS by hand, once.** An `AppIcon.icon` made in Icon Composer and committed as source; this needs
  a Mac. Keep a generated asset-catalogue icon for iOS 15 to 18 unless a simulator test shows Xcode
  produces one from the `.icon` file.
- **Screenshots from code.** A fictional portfolio seeded by script (fictional names, no real phone
  numbers or CNICs), captured in English and in right-to-left Urdu by integration tests on an
  Android emulator and, in the macOS release job, an iOS simulator. The sets can then be redone for
  every release. Captions, if any, go through the Urdu review.

### The mark

Chosen by the owner on 23 November 2026 (D-26), from two finalists shown beside today's outline
house at 16 to 96 px, under Android's circle mask and in one colour (five concepts were scored by
three judges: twin gables 25 of 30, the runner-up, an M cut into a solid house, 20). The brief was
to keep the house and make it more distinct and memorable, perhaps with the two Ms of
Maalik-e-Makaan.

- **What it is.** A filled white house on the cobalt tile (`primary`, with `onPrimary` on it; in
  the dark appearance, the dark theme's `primary` on its `onPrimary`). Two steep gables make the
  roofline a capital M; the eaves reach 2 units past the walls; two arched doorways cut the walls
  into a small m. It is one closed outline on the 32-unit tile, of 15 straight edges and 2 half
  circles of radius 2 (the doorways' heads, springing at y 16.5). Walls, pier and doorways are 4
  units wide, and every level and upright edge lies on an even unit, so all 11 of them land on whole
  pixels at 16, 32, 48 and 64 px.
- **Why.** A filled shape stays legible at 16 px and in a monochrome, themed or tinted icon, where
  the earlier 2-unit stroke faded; it carries the name's two Ms in the house itself, with no letter
  of either script; and it keeps the website's house and colours, so the site and the app match.
- **Measured.** Area 215.43 square units (228 less two half circles of radius 2), centroid (16,
  15.84), box 4 to 28 across and 6 to 24 down, reach 12.81 units from the tile's centre (the bottom
  corners; the eave tips reach 12.17). In Android's adaptive icon, at 2.25 dp a unit, it reaches
  28.81 dp from the centre (the safe circle allows 33) and is 54 by 40.5 dp (a logo should be at
  least 48 across). At the tile's own scale it would reach 40.02% of a maskable icon's width from
  its centre, just past the 40% circle, so the maskable icons draw it at 15/16 of that scale about
  the centre: 37.5%, and at 512 px 15 px a unit, every edge on a whole unit still on a whole pixel.
- **How it is kept.** The generator reads the outline from `brand.ts` (lines and circular arcs, with
  SVG's rules for arcs), fills it with the exact area of each pixel it covers, and refuses an
  outline that crosses or touches itself or whose holes do not turn the other way (where that
  exactness would fail; judged within 1/1024 of a unit of its arcs); path data that browsers may
  read otherwise (a comma anywhere but between two numbers, a number that ends in a dot such as
  `18.`) or Android's vector parser may (arc flags together, a plus sign or a tab between
  numbers); a number more than 1e9 from 0, a point more than 1,024 from 0, an arc whose ends lie
  under 1/1024 of its radius apart, or a number Chrome reads as none (40 or more digits before
  the dot, an exponent over 38), on which Android, browsers and the generator part ways; a `MARK_VIEWBOX` other than `0 0 N N`, the square `markSvg`'s tile fills; a tile corner
  radius over half its side; a house that reaches past the adaptive or maskable safe circle
  (counting each arc's farthest point); and one under 48 dp across. Its tests compare every icon's
  pixels with an exact render made from the designer's description and pass only if each is that
  render rounded up or down. The website's header draws the same path, and in forced colours draws
  the house alone in the text colour.

### Residence (decision 1)

The screenshot set tells both stories: a resident landlord recording rent and sending a receipt, and
an owner abroad confirming the cash their caretaker collected, with the two times ("in Lahore", "in
London") once residence ships.

### Letterheads (decision 2)

One screenshot shows a receipt on a fictional business's letterhead, made with the builder. If
letterheads are not ready at the first submission, the set is updated when they ship.

## Work

1. **Owner:** choose the mark and its colours, including the one-colour version. Done 23 November
   2026: the twin gables in the brand's colours, its outline alone the one-colour version (D-26,
   [The mark](#the-mark)).
2. **M:** SVG master, the generator, `make app-icons` and its CI check; Android adaptive, monochrome
   and legacy icons; web icons and manifest colours. Done 12 November 2026 (#51); on 23 November
   2026 the generator learned to fill outlines with arcs exactly, for the chosen mark.
3. **M:** iOS `AppIcon.icon` and the decision on the older-iOS fallback, tested on iOS 15 and iOS 26
   simulators.
4. **S:** Play 512 px icon and the 1,024 × 500 feature graphic, with an Urdu variant. The icon is
   generated (`app/android/store/play-icon-512.png`); the feature graphic is still to make.
5. **M:** screenshot harness and fictional seed; the Android phone set in English and Urdu (first
   half of the former L item).
6. **M:** the iPhone set in English and Urdu from the macOS job, and the iPad set if iPad stays
   (second half).

## Depends on / Unblocks

- **Depends on:** a Mac for the iOS icon, [urdu-review](urdu-review.md) for Urdu captions and the
  feature graphic's Urdu text. (The owner's choice of mark came on 23 November 2026.)
- **Unblocks:** [play-store](play-store.md) and [app-store](app-store.md), which cannot submit
  without the icon, the feature graphic and the screenshots.

## Risks

- **Thin strokes disappear at small sizes or under Liquid Glass.** The chosen mark is filled: walls,
  pier and doorways are 4 units and the roof over each doorway 3.8; only the eaves are thinner, 2 by
  3 unit points (at most 1.66 units thick) that soften at 16 px. Check them again in every
  appearance when the Icon Composer file is made.
- **A look-alike or a registered mark.** A roof that makes an M is a known property-logo idea, and
  some people read the mark as a letter before a house. No look-alike or trade mark search has been
  done (the agent cannot reach the sites); the owner's check is in [owner
  actions](../owner-actions.md#check-the-mark-against-look-alikes-by-30-november).
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
- [x] `make app-icons-check` passes in CI and fails when an output is stale.
- [x] The Android icon looks right under the circle and squircle masks and as a themed icon.
- [ ] The iOS icon renders in default, dark, clear and tinted appearances, and shows on the oldest
      supported iOS.
- [x] The maskable web icons pass the 40% safe-zone preview.
- [ ] Both stores have the icon, the feature graphic and screenshot sets in English and Urdu, made
      from fictional data.

The masks and the safe zone ticked on 23 November 2026, for the twin gables: the generated Android
vector, rendered on its own by librsvg, under circle and squircle masks with the 66 dp circle
drawn, and its monochrome layer themed light and dark; and both maskable icons with the 40% circle
drawn, under circle, squircle and 80%-circle masks. Not yet seen on a device or an emulator. And
`make app-icons-check`, in CI's hygiene job since #51; the generator's tests show it fails on a
stale, damaged or stray output.

## Questions for the owner

Answered on 23 November 2026: the mark is the twin gables, a house with no letter of either script
in it (D-26). Still open:

- Screenshot style: plain screens, or framed with captions?
- Which flows come first: the overdue list, a receipt, the caretaker handover?
