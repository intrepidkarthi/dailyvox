#!/usr/bin/env python3
"""Split the flat DailyVox brand icon into Icon Composer layers (1024x1024).

Reuses the keying from android/playstore/screenshot-src/make_icon.py:
  load_brand()  -> brand RGB + "inside the rounded square" mask (white margin
                   flood-filled from the corners, rim bevel eroded away)
  matte()       -> alpha for the mic, from the residual against a per-channel
                   plane fitted to the sage background

Outputs (overwritten):
  background.png          full-bleed sage gradient (the fitted plane), opaque,
                          no rounded corners -- the system applies the mask
  foreground-mic.png      the mic only, transparent, at the exact pixel position
                          and scale it has in the current 1024 icon
  foreground-mic-mono.png single-colour silhouette (white) for Clear/Tinted
  preview/*.png           composites for visual checking (not deliverables)

Differences from the Android script, both deliberate:
  * No 72/108 adaptive-icon inset. Icon Composer's canvas IS the iOS 1024
    square, so the mic stays exactly where it is in the shipped icon.
  * The baked cast shadow is removed from the mic layer. Liquid Glass renders
    its own shadow per layer; a baked one would double it and, on the Clear and
    Tinted appearances, show up as a dirty sage halo.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.dont_write_bytecode = True  # do not leave __pycache__ in the android tree
sys.path.insert(0, os.path.join(ROOT, "android/playstore/screenshot-src"))
import make_icon  # noqa: E402  (load_brand, matte)

SIZE = 1024
PREVIEW = os.path.join(HERE, "preview")


def plane_image(at, size=SIZE):
    """Evaluate the fitted background plane across the full square."""
    c00, c10, c01 = np.array(at(0, 0), float), np.array(at(size, 0), float), np.array(at(0, size), float)
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    gx, gy = (c10 - c00) / size, (c01 - c00) / size
    img = c00[None, None, :] + xs[..., None] * gx[None, None, :] + ys[..., None] * gy[None, None, :]
    return np.clip(img, 0, 255).astype(np.uint8), img


def main():
    rgb, inside = make_icon.load_brand()
    assert rgb.shape[:2] == (SIZE, SIZE), rgb.shape  # brand PNG is full-bleed 1024
    alpha, at = make_icon.matte(rgb, inside)
    bg8, bgf = plane_image(at)

    # --- Remove the baked cast shadow from the matte -------------------------
    # Shadow = darker than the predicted background AND not gold (r-b small).
    # The capsule's specular highlight is pale but BRIGHTER than the plane, and
    # all gold, including its darkest rim, has r-b well above 60, so neither is
    # touched.
    luma = rgb @ np.array([0.299, 0.587, 0.114])
    bl = bgf @ np.array([0.299, 0.587, 0.114])
    rb = rgb[:, :, 0] - rgb[:, :, 2]
    shadow = (luma < bl) & (rb < 60)
    alpha = np.where(shadow, 0.0, alpha)
    # Close tiny gaps then drop specks, so the silhouette is one clean shape.
    a8 = Image.fromarray((alpha * 255).astype(np.uint8), "L")
    hard = a8.point(lambda v: 255 if v > 127 else 0)
    # Keep only the large connected components (capsule, yoke, stem, base --
    # the capsule and the yoke do not touch, so a single flood fill would drop
    # the whole stand). Shadow remnants and specks are far smaller.
    from scipy import ndimage
    hard = hard.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    lab, n = ndimage.label(np.asarray(hard) > 0)
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 2000])
    print("components kept:", sorted(int(s) for s in sizes if s > 2000), "dropped:", int(sum(s for s in sizes if s <= 2000)), "px")
    keep_soft = np.asarray(Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
    alpha = alpha * keep_soft

    # Un-premultiply the edge colour against the plane, so partial-alpha rim
    # pixels hold gold rather than a gold/sage blend (they will now sit on glass
    # and on other backgrounds, not only on this sage).
    a3 = np.clip(alpha, 1e-3, 1)[..., None]
    fg = np.clip((rgb - (1 - a3) * bgf) / a3, 0, 255)
    fg = np.where(alpha[..., None] > 0.02, fg, 0)

    Image.fromarray(bg8, "RGB").save(os.path.join(HERE, "background.png"))
    mic = Image.fromarray(np.dstack([fg, alpha * 255]).astype(np.uint8), "RGBA")
    mic.save(os.path.join(HERE, "foreground-mic.png"))

    # Mono: hard-thresholded matte rendered at 4x, downsampled for clean AA.
    big = Image.fromarray(((alpha > 0.5) * 255).astype(np.uint8), "L").resize((SIZE * 4, SIZE * 4), Image.NEAREST)
    big = big.filter(ImageFilter.GaussianBlur(4)).point(lambda v: 255 if v > 127 else 0)
    small = big.resize((SIZE, SIZE), Image.LANCZOS)
    mono = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    mono.putalpha(small)
    mono.save(os.path.join(HERE, "foreground-mic-mono.png"))

    # --- Previews --------------------------------------------------------------
    os.makedirs(PREVIEW, exist_ok=True)
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=225, fill=255)

    def tile(base_rgb, layer):
        t = Image.new("RGBA", (SIZE, SIZE), base_rgb + (255,)) if isinstance(base_rgb, tuple) else base_rgb.convert("RGBA")
        t = t.copy()
        t.alpha_composite(layer)
        return t

    orig = Image.open(make_icon.BRAND).convert("RGBA")
    rebuilt = tile(Image.fromarray(bg8), mic)
    diff = np.abs(np.asarray(orig.convert("RGB"), int) - np.asarray(rebuilt.convert("RGB"), int)).max(axis=2)
    tinted_mono = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    tinted_mono.paste((255, 201, 77, 255), (0, 0), mono)
    panels = [
        ("original", orig),
        ("rebuilt bg+mic", rebuilt),
        ("mic on dark", tile((16, 27, 45), mic)),
        ("mic on light", tile((247, 243, 234), mic)),
        ("mono on dark", tile((28, 28, 30), mono)),
        ("mono tinted", tile((40, 40, 44), tinted_mono)),
    ]
    S = 400
    sheet = Image.new("RGB", (S * 3 + 80, (S + 60) * 2 + 40), (60, 60, 64))
    d = ImageDraw.Draw(sheet)
    for i, (name, im) in enumerate(panels):
        x, y = 20 + (i % 3) * (S + 20), 20 + (i // 3) * (S + 60)
        m = mask.resize((S, S), Image.LANCZOS)
        sheet.paste(im.convert("RGB").resize((S, S), Image.LANCZOS), (x, y), m)
        d.text((x, y + S + 10), name, fill=(240, 240, 240))
    sheet.save(os.path.join(PREVIEW, "icon-layers-preview.png"))
    # Checkerboard view of the transparent mic, to inspect the matte edge.
    cb = Image.new("RGBA", (SIZE, SIZE))
    cbd = ImageDraw.Draw(cb)
    for yy in range(0, SIZE, 32):
        for xx in range(0, SIZE, 32):
            cbd.rectangle((xx, yy, xx + 31, yy + 31), fill=(200, 200, 200, 255) if (xx // 32 + yy // 32) % 2 else (150, 150, 150, 255))
    cb.alpha_composite(mic)
    cb.convert("RGB").save(os.path.join(PREVIEW, "mic-on-checker.png"))
    print("rebuild vs original: max diff inside mic/bg, 95th pct =", np.percentile(diff[inside], 95))


if __name__ == "__main__":
    main()
