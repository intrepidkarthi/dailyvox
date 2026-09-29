#!/usr/bin/env python3
"""Generate every Android icon asset FROM THE BRAND ICON.

The mark had drifted. `ic_launcher_{background,foreground}.xml` were a
hand-drawn flat microphone -- thin amber strokes on #101B2D navy -- and the
brand mark is a three-dimensional gold microphone on sage green. Different
mark, different palette, and it shipped on the phone and, because the previous
version of this script rendered the store icon from those same two drawables,
onto the Play listing as well. Faithfully propagating the wrong icon is worse
than not having one, because nothing looks broken.

So the source of truth is now the actual brand asset, the same 1024 PNG the iOS
app and the website press kit ship:

    ios/solyn/Assets.xcassets/AppIcon.appiconset/icon-ios-1024x1024.png

Raster, not vector, and deliberately. The mark has gradients, a specular
highlight and a cast shadow; any vector redraw is an approximation, and an
approximation is exactly the drift this is fixing. Five densities of PNG cost
about 150KB, which is the price of the icon being the icon.

### Keying the mic off the background

The two layers of an adaptive icon have to be separated, and the mark separates
cleanly on red-minus-blue: the gold is (228,173,61), r-b = 167; the sage is
(113,139,108), r-b = 5. A soft ramp across that gap gives an antialiased alpha
without a hand-drawn matte.

The background is then fitted as a linear plane per channel over the pixels the
mic does NOT cover -- the sage is a smooth diagonal gradient, so a plane fits it
almost exactly and, unlike sampling, extrapolates correctly into the 18dp of
bleed that the source square does not cover.

### The crop, which is the only real decision

An adaptive icon is a 108dp canvas of which only the middle ~72dp is guaranteed
visible; launchers crop the rest for their own mask. The iOS square is fully
visible at 1024. So for the two to look like the same icon, the iOS square has
to map onto Android's 72dp visible region, not onto the whole 108dp canvas --
the mic is scaled to 72/108 of full-canvas size and the fitted background bleeds
out to the edges behind it.

Outputs (all overwritten):
    app/src/main/res/mipmap-*/ic_launcher_foreground.png    5 densities
    app/src/main/res/mipmap-*/ic_launcher_monochrome.png    5 densities
    app/src/main/res/drawable/ic_launcher_background.xml    fitted gradient
    playstore/assets/icon-512.png                           Play listing
"""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
BRAND = os.path.join(ROOT, "ios/solyn/Assets.xcassets/AppIcon.appiconset/icon-ios-1024x1024.png")
RES = os.path.join(ROOT, "android/app/src/main/res")
STORE = os.path.join(ROOT, "android/playstore/assets/icon-512.png")

# Adaptive-icon geometry: 108dp canvas, middle 72dp guaranteed visible.
CANVAS, VISIBLE = 108.0, 72.0
# Foreground/monochrome layers are 108dp square at each density bucket.
DENSITIES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def load_brand():
    """The brand icon as float RGB, cropped to the mark itself.

    The PNG is a rounded square sitting on white with a few percent of margin.
    Those corners are not part of the mark: left in, they poison the background
    fit, and -- because the square is what gets mapped onto Android's visible
    72dp -- they also shrink the mic relative to the iOS icon it is supposed to
    match. Nothing in the mark is near-white, so a brightness test finds them.

    Cropping to the bounding box of what survives makes the Android and iOS
    marks the same size on screen rather than merely the same drawing.
    """
    im = Image.open(BRAND).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    inside = ~(a.min(axis=2) > 235)
    ys, xs = np.where(inside)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    # Erode the mask before it reaches the matte. The rounded square's rim is
    # antialiased from white into sage, so those pixels sit far from the fitted
    # background and keyed as MIC: a faint rounded-square outline rode along in
    # the foreground layer, visible just inside the launcher's mask on device.
    # The art also has a soft inner bevel along the rim, so the margin grows by
    # 60px; nothing of the microphone, its stand or its shadow is within ~95px.
    #
    # Only white CONNECTED TO THE EDGE is margin: the capsule's specular
    # highlight is near-white too, and treating it as outside punched holes
    # through the mic.
    from PIL import ImageDraw, ImageFilter
    # .copy(): fromarray can hand back a read-only view, and floodfill then
    # silently changes nothing.
    white = Image.fromarray(((~inside) * 255).astype(np.uint8)).copy()
    for seed in [(0, 0), (white.width - 1, 0), (0, white.height - 1), (white.width - 1, white.height - 1)]:
        ImageDraw.floodfill(white, seed, 128)
    margin = Image.fromarray(((np.asarray(white) == 128) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(121))
    inside = np.asarray(margin) < 127
    # The straight sides run to the image edge with the same bevel line on
    # them, and white flood-fill never reaches those. Band every edge too.
    band = 70
    inside[:band, :] = inside[-band:, :] = False
    inside[:, :band] = inside[:, -band:] = False
    return a[y0:y1, x0:x1], inside[y0:y1, x0:x1]


def matte(rgb, inside):
    """Alpha for the mic, from how far each pixel is from the BACKGROUND.

    The first version keyed on red-minus-blue, on the reasoning that gold is
    (228,173,61) and sage is (113,139,108), so r-b separates them 167 to 5. It
    does -- for the flat gold. It fails for the specular highlight on the
    capsule, which is a pale blue-white: **47% of that highlight measured r-b
    below the key's threshold**, so nearly half of it was classified as
    background and punched straight through the mic.

    That hole was then papered over by flooding the background inwards from the
    border and forcing everything unreachable to alpha 1. It closed the hole and
    produced a worse artifact: a cloudy, desaturated blob with a hard rim where
    the fill met the key, sitting on the most visible part of the mark.

    The fix is to stop asking "is this gold?" and ask "is this the background?",
    which is the question that has a reliable answer. The sage is a smooth
    linear gradient, so it fits as a plane per channel and every pixel can be
    compared against the background predicted for its own position. Measured on
    the source art, that separates cleanly with no special case for the
    highlight:

        background   99th percentile residual    16
        mic          median residual            121
        highlight    median residual            123   <- reads as mic, correctly

    The fit is iterative because fitting needs a background mask and the mask
    needs the fit. Bootstrapped from "greenish" (G >= R), which no part of a
    gold microphone ever is, then refined twice.

    Edge pixels come out as genuine partial alpha holding a gold-to-sage blend.
    That is not a compromise here: the adaptive icon's background layer is this
    same fitted gradient, so a blended edge composites back to the source pixel.
    """
    h, w, _ = rgb.shape
    ys, xs = np.mgrid[0:h, 0:w]

    def fit(mask):
        A = np.stack([xs[mask], ys[mask], np.ones(mask.sum())], axis=1).astype(np.float64)
        return [np.linalg.lstsq(A, rgb[:, :, c][mask], rcond=None)[0] for c in range(3)]

    def predict(coef):
        return np.dstack([c[0] * xs + c[1] * ys + c[2] for c in coef])

    mask = inside & (rgb[:, :, 1] >= rgb[:, :, 0])
    for _ in range(3):
        coef = fit(mask)
        mask = inside & (np.linalg.norm(rgb - predict(coef), axis=2) < 18)

    resid = np.linalg.norm(rgb - predict(coef), axis=2)
    # A ramp, not a threshold, so the rim of the mark keeps its antialiasing.
    # 12 sits above the background's own noise; 40 is well under the mic.
    alpha = np.clip((resid - 12.0) / 28.0, 0.0, 1.0) * inside

    def at(x, y):
        return tuple(int(round(np.clip(c[0] * x + c[1] * y + c[2], 0, 255))) for c in coef)
    return alpha, at


def foreground(rgb, alpha, size):
    """The mic alone, on transparency, scaled into the 72dp visible region."""
    src = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)
    mic = Image.fromarray(src, "RGBA")
    inner = max(1, int(round(size * VISIBLE / CANVAS)))
    mic = mic.resize((inner, inner), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    off = (size - inner) // 2
    out.paste(mic, (off, off))
    return out


def monochrome(alpha, size):
    """The themed-icon layer: a crisp silhouette, built from the full-res matte.

    Android tints this layer to the wallpaper palette using its ALPHA alone, so
    it has to read as a shape. Deriving it from the colour layer's alpha did not:
    that alpha carries a soft antialiasing ramp everywhere, and once every pixel
    is flattened to one ink the ramp stops looking like an edge and starts
    looking like a smudge. The grille slots vanished too, because they are a
    difference in colour, not in coverage -- so the result was a fuzzy blob.

    So this thresholds the matte hard and gets its smooth edge the honest way,
    by rendering the crisp mask large and letting the downsample do the
    antialiasing. Losing the grille detail is correct rather than a compromise:
    a themed icon is meant to be a simplified single-colour mark, not a
    desaturated photograph of one.

    Still derived from the same matte as everything else, so the silhouette
    cannot drift from the mark the way a hand-drawn one would.
    """
    hard = (alpha > 0.5).astype(np.uint8) * 255
    big = Image.fromarray(hard, "L")
    inner = max(1, int(round(size * VISIBLE / CANVAS)))
    small = big.resize((inner, inner), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layer = Image.new("RGBA", (inner, inner), (0, 0, 0, 255))
    layer.putalpha(small)
    off = (size - inner) // 2
    out.paste(layer, (off, off))
    return out


def gradient_xml(at, size):
    """The fitted plane as a VectorDrawable linear gradient.

    A plane IS a linear gradient, so the visible region is reproduced exactly
    rather than approximated. The endpoints are the plane at the corners of the
    SOURCE square, mapped to where that square sits on the 108dp canvas -- the
    inner 72dp, i.e. (18,18) to (90,90).

    Not the corners of the bled canvas, which is what this did first: the plane
    extrapolated a further 25% in each direction and the bleed came out at
    #1B3423, far darker than anything in the brand icon. Android clamps a
    gradient outside its endpoints, so anchoring to the square instead lets the
    18dp of bleed hold the true corner colour, which is what a launcher mask
    that crops wide should reveal.
    """
    inset = (CANVAS - VISIBLE) / 2  # 18dp
    start = "#%02X%02X%02X" % at(0, 0)
    end = "#%02X%02X%02X" % at(size, size)
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- GENERATED by playstore/screenshot-src/make_icon.py. Do not hand-edit.
     The sage of the brand icon, fitted as a linear plane over the source PNG.
     Anchored to the inner 72dp, where the source square maps, so the 18dp of
     adaptive bleed clamps to the true corner colour rather than extrapolating
     past it. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:pathData="M0,0h108v108h-108z">
        <aapt:attr xmlns:aapt="http://schemas.android.com/aapt" name="android:fillColor">
            <gradient android:type="linear"
                android:startX="{inset:g}" android:startY="{inset:g}"
                android:endX="{CANVAS - inset:g}" android:endY="{CANVAS - inset:g}">
                <item android:offset="0" android:color="{start}" />
                <item android:offset="1" android:color="{end}" />
            </gradient>
        </aapt:attr>
    </path>
</vector>
'''


def store_icon(rgb, alpha, at, size=512):
    """Play's 512x512 listing icon: full-bleed sage, mic at the iOS proportion.

    Full bleed, not the adaptive crop. Play rounds whatever it is given, and the
    iOS square is the canonical framing of the mark -- the 72dp inset exists to
    survive launcher masks, and there is no launcher mask here.
    """
    h, w, _ = rgb.shape
    ys, xs = np.mgrid[0:size, 0:size]
    sx, sy = xs * (w / size), ys * (h / size)
    # Evaluate the fitted plane directly at store resolution.
    plane = np.zeros((size, size, 3), np.float32)
    for c in range(3):
        corners = np.array([at(0, 0)[c], at(w, 0)[c], at(0, h)[c]], np.float64)
        gx = (corners[1] - corners[0]) / w
        gy = (corners[2] - corners[0]) / h
        plane[:, :, c] = corners[0] + gx * sx + gy * sy
    mic = Image.fromarray(np.dstack([rgb, alpha * 255.0]).astype(np.uint8), "RGBA")
    mic = mic.resize((size, size), Image.LANCZOS)
    out = Image.fromarray(np.clip(plane, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    out.alpha_composite(mic)
    # RGBA to satisfy Play's "32-bit PNG"; the alpha is fully opaque, because
    # Play renders a genuinely transparent icon badly.
    return out


def main():
    rgb, inside = load_brand()
    alpha, at = matte(rgb, inside)

    for bucket, size in DENSITIES.items():
        d = os.path.join(RES, f"mipmap-{bucket}")
        os.makedirs(d, exist_ok=True)
        fg = foreground(rgb, alpha, size)
        fg.save(os.path.join(d, "ic_launcher_foreground.png"))
        monochrome(alpha, size).save(os.path.join(d, "ic_launcher_monochrome.png"))
        print(f"  mipmap-{bucket:8} {size}x{size}")

    src_h = rgb.shape[0]
    bgx = os.path.join(RES, "drawable", "ic_launcher_background.xml")
    with open(bgx, "w") as f:
        f.write(gradient_xml(at, src_h))
    print(f"  {os.path.relpath(bgx, ROOT)}")

    os.makedirs(os.path.dirname(STORE), exist_ok=True)
    store_icon(rgb, alpha, at).save(STORE)
    print(f"  {os.path.relpath(STORE, ROOT)}  512x512")


if __name__ == "__main__":
    main()
