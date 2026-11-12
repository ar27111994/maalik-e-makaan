# mm_ui gallery

Every component of the Maalik-e-Makaan design system (`packages/mm_ui`) in
realistic use, for designers, testers and user acceptance testing. One page
per component family: actions, inputs, choices, display, records, feedback,
layout and charts. The names, CNICs and phone numbers in it are made up.

The settings button on every page switches light and dark, high contrast,
English and Urdu, text at 100%, 150% or 200%, and lakh/crore grouping.

## Run it

From the repository root, after `flutter pub get`:

```sh
cd packages/mm_ui/example
flutter run -d chrome        # or: flutter run -d linux
```

A release build for testers:

```sh
cd packages/mm_ui/example
flutter build web --release
python3 -m http.server 8080 --directory build/web
```

Then open <http://localhost:8080/>. The address can choose the page and the
settings: `?page=charts&lang=ur&theme=dark&contrast=high&text=200&grouping=western`.

## Check it

```sh
cd packages/mm_ui/example
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
flutter test --no-pub
```

The tests open every page in light, dark, both high-contrast modes, Urdu,
200% text and Urdu at 200% text on a phone, and in English and Urdu on a
desktop window, and fail on any exception, overflow, small tap target,
unlabelled control or text under WCAG AA contrast.

`screenshots/` holds the user acceptance record: every page in English light
and Urdu dark, on a 390 x 844 phone and a 1280 x 800 desktop window, plus the
settings sheet, a confirmation dialog, a pushed page, a select sheet and the
phone's "More" list. It was taken before Urdu interface text moved from
Nastaliq to Noto Sans Arabic (D-19), so its Urdu pages still show Nastaliq;
the design system's Urdu goldens (`../test/components/*/goldens/*_urdu.png`)
show the current face.
