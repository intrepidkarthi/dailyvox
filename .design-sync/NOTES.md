# design-sync notes

## This repo is outside the skill's envelope

`/design-sync` converts a **JavaScript/TypeScript component library** into the
format claude.ai/design consumes: React components compiled to a bundle the
design agent renders from `window.<globalName>.*`.

This repo has none of that, and it is not an oversight:

- no `package.json`, no `dist/`, no Storybook, no `.tsx`/`.jsx`
- `website/` is Python-generated static HTML (`generate_pages.py` → `public/`)
- the design system lives in two NATIVE codebases —
  `ios/solyn/{DesignSystem,DVFont,ThemeManager}.swift` and
  `android/.../ui/theme/{Color,Type,Theme}.kt`

There is no path from SwiftUI or Compose to a renderable React bundle, and the
skill's core rule is to ship what was already built rather than reimplement it.
**Do not re-run the converter here.** If Claude Design support is wanted, the
options are a tokens-only foundations bundle, or building a real React package
for Evergreen & Gold Hour and syncing that.

## The Claude Design project is not a sync target

`f431d6c3-44cf-4598-9d78-bbd84fc0ebb3` ("Daily Vox Android Design") is
`PROJECT_TYPE_PROJECT`, not `PROJECT_TYPE_DESIGN_SYSTEM`. That type is immutable
at creation, so it can never receive a design-system sync. It is the design
PACKAGE — canvases, specs and rendered screenshots — and it is the reference,
not a destination.

## The project holds design assets this repo does not

Found while verifying. The repo's `research/design/` is missing:

- `package/screenshots/final/{A-tokens,B-day-screens,C-night-screens,D-system-surfaces,E-dynamic-island,F-marketing}.png`
  — the RENDERED final designs, i.e. the actual visual source of truth
- `DailyVox Store Images.dc.html`, `DailyVox Website Redesign.dc.html`
- `package/WEBSITE-SEO-AEO.md`

`DesignSync(get_file)` caps at 256 KiB and these PNGs exceed it — the fetch comes
back truncated with no IEND chunk, so they cannot be pulled through the tool.
They need downloading from claude.ai/design by hand.

Consequence worth knowing: every verification done before 2026-08-21 was against
the prose spec and the canvas markup, never against the rendered designs.

## Fixed while verifying

- `research/design/final/support.js` was missing — the final canvas references
  `./support.js` and it only existed in `package/prototype/`, so the local copy
  of the Final System canvas rendered broken. Copied in.

## Verifying the canvas locally

    cd research/design/final && python3 -m http.server 8787
    # then open http://localhost:8787/DailyVox-Final-System.dc.html
    # sections: #tokens #day #night #surfaces #island #marketing

A `file://` URL will not work with the Chrome tooling; serve it over HTTP.
