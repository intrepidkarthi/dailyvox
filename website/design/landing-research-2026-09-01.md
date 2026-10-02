# What TwinMind's landing page is doing, and what we should take

Research 2026-09-01, prompted by "I love this design."

## What it is, mechanically

Built in **Framer** (11,043 framer references in the source, 966 KB of HTML, 116
images, no video). The tripled `h1`/`h2` in the DOM are Framer's responsive
variants, not a mistake.

Six moves, in order of how much they matter:

1. **A continuous gradient down the whole page.** Sky blue at the top, sage and
   olive through the middle, peach at the bottom. It is a **day cycle**, and it
   is the only structural idea on the page. Everything else sits on it.
2. **Soft white rounded cards floating on that gradient**, generous padding,
   barely-there shadow.
3. **Isolated UI fragments rather than screenshots.** Not "here is the app", but
   a single card lifted out of it, floated near a phone.
4. **The device flanked by input and output labels**, joined by hairlines.
   Inputs left (Meetings, Conversations, Your Entire Day), outputs right (Wiki of
   Your Life, Daily Insights, Drafts & Reports). The product explained in one
   glance, with no prose.
5. **High-contrast serif headings**, sans body, everything centred.
6. **Small pill annotations** on the imagery ("Offline / on-device mode").

## What to take

**The continuous gradient. That is the whole borrowable idea, and it suits us
better than it suits them.**

They run light to warm. We should run **dawn to night**: cream at the top,
through sage, into the deep indigo the Twin screen already uses, ending on the
constellation. DailyVox is an evening ritual whose payoff is a sky full of
stars. Scrolling the page should be the ritual. Their gradient is decoration
with a theme; ours would be the product's own metaphor.

**Isolated fragments over full screenshots.** We currently show whole phone
screens. Lifting out the pieces — one star, one entity chip, one "Twin noticed"
card, one mood dot — reads lighter and explains more per pixel.

**The input/output diagram, reframed.** Theirs is a fan-out: many sources in,
many artifacts out. Ours is a **transformation**: forty-two seconds of voice in,
a star and a pattern out. Same device, different claim, and ours is the simpler
picture.

## What to refuse, and why it matters

**The palette.** Sky blue and orange is their identity. Ours is sage, gold and
cream, and it is already shipped in the app, the launcher icon, the store icon,
eight Play screenshots and the feature graphic. Switching orphans all of it for
no gain.

**The serif.** They use a high-contrast editorial serif; it says premium
productivity tool. We are Nunito, rounded and humanist, which says diary. Nunito
is the more accurate face for what this is, and it is already the brand.

**Framer.** Their page is 966 KB. Ours is 137 KB of hand-written HTML with the
whole SEO programme built into it. Moving to Framer would cost weight, control
and every ranking page.

**And the obvious one.** We differentiate from TwinMind on being the honest,
unfunded, no-network alternative. A visitor who has seen both pages and finds
ours is a restyle of theirs draws exactly the wrong conclusion. The
differentiation has to be visible in the design, not only in the copy.

## What is already right and should not be touched

The July redesign's **pinned-device hero** (phone fixed, screen swapping on a
42-second timecode) is in place and works. It is a better hero than TwinMind's
static mockup because it moves through the actual ritual. Keep it. The gradient
goes behind it.

## The proposal

Keep the identity and the hero. Add the day-to-night gradient as the page's
spine, convert the feature rows to floating fragments, and land the scroll on
the constellation. Prototype at `website/design/landing-v2.html`.
