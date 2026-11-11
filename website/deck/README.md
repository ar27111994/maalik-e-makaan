# The pitch deck

The slides of Maalik-e-Makaan's pitch deck, in English. `npm run deck` (in `website/`) renders
them to `public/pitch/maalik-e-makaan-pitch-deck.pdf`, which the company page links to; CI and the
Deploy workflow render it before every build, so the PDF is not committed.

- `deck.json` lists the slides in order; `slides/<id>.html` is one slide each.
- A slide is one `<section>` on a 1920 × 1080 canvas with inline styles only, as in the deck
  artifact it was first written in. `<aside>` holds speaker notes, which the PDF leaves out.
- `<x-icon name="…">` draws an icon from `icons/` (Lucide, ISC licence; the names the renderer
  knows are in `scripts/render-deck.ts`). `<x-connector>` draws a horizontal arrow.
- `<img src="screens/<golden>.png">` shows a screen cropped from the app's golden test image of
  that name (`app/test/src/goldens/goldens/`), so the deck always shows the current app with its
  sample data. The crop of each screen is in `scripts/render-deck.ts`.
- `{{version}}` and `{{releaseDate}}` are replaced with the current release, from
  `.release-please-manifest.json` and `CHANGELOG.md`.

Market figures on the slides name their sources in the footer. Check a figure against its
primary source before changing it, and keep the speaker notes in step with the slide.
