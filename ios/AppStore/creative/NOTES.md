# DailyVox: App Store creative assets (iOS/iPadOS 27)

Researched 2026-10-06. Each fact below is marked **VERIFIED** (read from an Apple page or file) or **INFERRED** (my reading, or a third-party source).

## Deliverables

| File | Canvas | Use in App Store Connect |
|---|---|---|
| `universal-5244x2950.png` | 5244 x 2950 (16:9), PNG, RGB, no alpha | Universal creative asset (one file for product page header + search results) |
| `header-3840x1646.png` | 3840 x 1646 (21:9), PNG, RGB | Product page header (dedicated) |
| `search-3840x2560.png` | 3840 x 2560 (3:2), PNG, RGB | Search results (dedicated) |

Sources: `creative.html` renders all three, selected with `?v=universal|header|search` (add `&guides=1` to outline the safe area). `render.sh` re-renders and flattens to RGB, and `make_contact_sheet.py` builds `preview/contact-sheet.png`. The `preview/*-guides.png` files are previews only. Do not upload them.

Real UI: `src/constellation.png` is a crop of the Twin tab (`screenshot-src/raw/twin.png`, copied 2026-10-06). `src/waveform.png` is the live waveform from the recording screen (`raw/recording.png`), keyed to alpha. Fonts are Nunito 800 and DM Mono from `android/app/src/main/res/font/`.

Concept: one idea, "Your voice becomes a star." The visual reads left to right: the recording waveform, then a dotted trail, then the Twin constellation, then the phrase. The waveform and trail are decorative and sit outside the safe area, so a crop can lose them. The constellation core (the centre star plus the four named stars) and the phrase sit inside Apple's art safe area on every canvas. `creative.html` checks this when it renders and writes the result into the page title. Last render: `text:IN core:IN` on all three canvases.

## Specs: VERIFIED

Source: https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications
- Product page header image: 21:9 at **3840 x 1646** (.jpeg/.jpg/.png), or 16:9 at **5244 x 2950** (**.png only**).
- Search results image: 3:2, **min 1920 x 1280, max 3840 x 2560** (.jpeg/.jpg/.png), or 16:9 at **5244 x 2950** (**.png only**).
- "Images can't include alpha channels or transparencies." All three deliverables are therefore saved as RGB.
- Video: header 21:9 at 3840 x 1646; search 3:2 from 1920 x 1280 to 3840 x 2560. 30 or 60 fps, 5 to 30 s, .mov/.m4v/.mp4. Videos are muted by default and loop. On product pages people can unmute; in search results they can't.

Source: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets/
- Creative assets are for iOS/iPadOS 27 and later. They are optional and separate from screenshots and app previews. A universal asset can serve both placements.

Source: https://developer.apple.com/app-store/asset-best-practices/
- One single clear idea, not dense or cluttered. Design for first-time visitors. Search: "state the obvious" and show the firsthand experience (interface or content).
- Text: short phrases that enhance the visual, localized, legible in every presentation.
- Prohibited: pricing, discounts, website URLs, copyright symbols, unverified claims or awards, **logos or references to other platforms or marketplaces**, Apple recognitions (Editor's Choice, App of the Day and similar), and anything that isn't suitable for a 4+ rating.
- Video: a strong poster frame, slow pacing, a seamless loop, audio as texture only.

Source: https://ads.apple.com/app-store/h/help/design-your-own-ads-with-creative-assets
- Assets can't include "cropped brand or promotional text". Stylistic cropping of imagery is allowed. The same assets can be used in Apple Ads (search results and Today tab).

Source: WWDC26 session 205, "Enhance your presence on the App Store" (https://developer.apple.com/videos/play/wwdc2026/205/)
- Covers creative assets only in general terms (images or video; header, search, Apple Ads, custom product pages). No crop or overlay numbers.

## Safe areas: VERIFIED from Apple's official templates

The templates are linked from the best-practices page through `/go/?id=...` redirects. Downloaded 2026-10-06 from:
- https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-universal_asset_template-static.psd
- https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-product_page_header_template-static.psd
- https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-search_results_template-static.psd
- https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-templates.sketch (the `.fig` and `.pxd` versions also exist)

I read the layer bounding boxes with psd-tools and cross-checked them against the Sketch JSON. Each PSD has exactly one guide layer, named "Art Safe Area". The PSDs contain no ruler guides.

| Template | Canvas | Art Safe Area (x, y, w, h) | Notes |
|---|---|---|---|
| Universal (16:9) | 5244 x 2950 | **1921, 660, 1402 x 962** | Horizontally centred (centre x 2622). **Sits ABOVE centre**: centre y 1141 vs 1475. Only 27% of the width and 33% of the height. |
| Header (21:9) | 3840 x 1646 | **1097, 493, 1646 x 661** | Exactly centred |
| Search (3:2) | 3840 x 2560 | **836, 765, 2168 x 1030** | Exactly centred |

## INFERRED or unknown (Apple does not publish these)

- **Where the system draws the app icon, name and Get button over the header or search asset is not published.** Not on the spec page, the best-practices page, the WWDC session or in the templates. Third-party write-ups say the same and recommend the App Store Connect product page preview tool, e.g. https://appscreens.com/blog/apple-creative-assets-app-store. **Action: before submitting, check every asset in App Store Connect's preview for iPhone and iPad.**
- The universal safe area sitting above centre suggests the lower part of the 16:9 frame may be covered by overlay chrome (name, icon, Get) or cropped away in at least one placement. That is my inference. The deliverables keep everything important inside that box anyway.
- The iPhone vs iPad crop isn't documented. I assume the visible window on any device always contains the art safe area, and that more of the surrounding bleed shows on wider or larger screens. So all three canvases carry a full-bleed starfield with no hard edges, and they still read correctly if everything outside the green box is lost. The red and blue boxes on the universal tile of the contact sheet are centred 21:9 and 3:2 crops for orientation only. They are not Apple data.
- Text size relative to the on-device display isn't specified. The phrase is around 118 to 146 px on the canvases, which makes it the dominant element inside the safe area.

## Compliance self-check

- One idea, a short phrase, no pricing, no URL, no ©, no awards, no Apple badges, no other platform mentioned (no Android or Google Play anywhere). Suitable for 4+.
- The UI comes from the real app. The names in the constellation (Mike, Sarah, Emma, James) are the app's demo data.
- No alpha channel (verified with PIL: mode RGB).
- Localization: the phrase is English only. Apple recommends localizing. Re-render per locale by editing `lines` in `creative.html`.
