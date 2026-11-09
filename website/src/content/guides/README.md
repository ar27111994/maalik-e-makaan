# Guides

Each guide is two files with the same name, one per language:

- `en/<slug>.md` (or `.mdx`), served at `/guides/<slug>/`;
- `ur/<slug>.md` (or `.mdx`), served at `/ur/guides/<slug>/`.

The slug is lower case, with hyphens, and stays in English in both languages. The build fails if
a published guide exists in one language only.

## Front matter

The schema is `guideSchema` in `src/lib/content/schemas.ts`:

```yaml
---
title: "Registering a tenant with the police" # 10–70 characters; the page's h1
description: "Who must report a tenant, by when, and what the law says in each province." # 50–165
lastReviewed: 2026-11-05 # shown as "Last reviewed"; also the Article's dateModified
published: 2026-11-05 # optional: the first publication date
sources: # at least one official source, listed under the guide
  - title: "Punjab Information of Temporary Residents Act 2015"
    publisher: "Government of the Punjab"
    url: "http://punjablaws.gov.pk/laws/2591.html"
    accessed: 2026-11-05
draft: false # optional: drafts are validated but not published
---
```

## Writing rules

- The guide page adds the review date and the notice that the guide is general information, not
  legal or tax advice. Do not repeat them in the body.
- Cite the official source inline, next to each claim, as a Markdown link.
- Use only facts from `.planning/research/website-facts.md` that are not marked **Low** or
  **UNVERIFIED**. Where sources disagree or are unclear, say so instead of choosing one.
- Never estimate anyone's final income tax (decision D-10 in `.planning/PROJECT.md`).
- English is British English. Urdu is in Urdu script only, never Roman Urdu. A Latin-script word
  in an Urdu guide goes in `<kbd lang="en" dir="ltr">…</kbd>` when it is text to type (the repository's markdownlint allows `kbd`, not `span`), or is written in Urdu script; the
  end-to-end suite fails otherwise.
