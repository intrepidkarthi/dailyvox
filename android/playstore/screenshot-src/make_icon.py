#!/usr/bin/env python3
"""Render the 512x512 hi-res icon Play Console requires.

It was simply missing. The app's launcher icon is an adaptive vector — two XML
drawables, no raster anywhere — which is right for the APK and leaves nothing to
upload to the store listing.

Rather than redraw the mark by hand and let the two drift, this reads the paths
out of `app/src/main/res/drawable/ic_launcher_{background,foreground}.xml` and
renders them. Android's `pathData` is SVG path syntax, so the paths transfer
verbatim; if someone edits the icon, re-running this picks the change up.

### The crop, which is the only real decision here

An adaptive icon is drawn on a 108dp canvas of which only the middle 72dp is
guaranteed visible — launchers crop the rest to make room for their own mask.
So the same file has two defensible renderings, and they do not look alike:

  * the full 108 canvas, where the mark sits small inside a lot of background
  * the inner 72, which is what a person actually sees on their home screen

Play applies its own rounding to whatever it is given, and the listing icon
should match the launcher, so this renders the **inner 72dp** by default. Pass
`--full` to see the other one.
"""
import os
import subprocess
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.abspath(os.path.join(HERE, "..", "..", "app", "src", "main", "res", "drawable"))
OUT = os.path.abspath(os.path.join(HERE, "..", "assets", "icon-512.png"))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

ANDROID = "{http://schemas.android.com/apk/res/android}"
SIZE = 512
# Adaptive-icon geometry: 108dp canvas, middle 72dp guaranteed visible.
CANVAS, VISIBLE = 108.0, 72.0


def paths(xml_file):
    """Every <path> in an Android VectorDrawable, as SVG attributes."""
    root = ET.parse(os.path.join(RES, xml_file)).getroot()
    out = []
    for p in root.iter("path"):
        d = p.get(ANDROID + "pathData")
        if not d:
            continue
        fill = p.get(ANDROID + "fillColor", "#00000000")
        # Android writes a fully transparent fill as #00000000; SVG wants none,
        # or the stroke-only shapes come out as filled blobs.
        if fill.lower() in ("#00000000", "@android:color/transparent", ""):
            fill = "none"
        attrs = [f'd="{d}"', f'fill="{fill}"']
        stroke = p.get(ANDROID + "strokeColor")
        if stroke and stroke.lower() != "#00000000":
            attrs.append(f'stroke="{stroke}"')
            attrs.append(f'stroke-width="{p.get(ANDROID + "strokeWidth", "1")}"')
            cap = p.get(ANDROID + "strokeLineCap")
            if cap:
                attrs.append(f'stroke-linecap="{cap}"')
            join = p.get(ANDROID + "strokeLineJoin")
            if join:
                attrs.append(f'stroke-linejoin="{join}"')
        out.append("<path " + " ".join(attrs) + " />")
    return out


def main(argv):
    full = "--full" in argv
    inset = 0.0 if full else (CANVAS - VISIBLE) / 2
    side = CANVAS if full else VISIBLE
    view = f"{inset} {inset} {side} {side}"

    # The background path is a plain rect covering the canvas; drawing it under
    # the cropped viewBox keeps the corners filled either way.
    body = "\n  ".join(paths("ic_launcher_background.xml") + paths("ic_launcher_foreground.xml"))
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" '
           f'viewBox="{view}">\n  {body}\n</svg>')

    tmp = os.path.join(HERE, "_icon.html")
    # No margin, no scrollbars: the screenshot is the SVG and nothing else.
    with open(tmp, "w") as f:
        f.write(f'<!doctype html><meta charset=utf-8>'
                f'<style>*{{margin:0;padding:0}}html,body{{overflow:hidden}}</style>{svg}')
    try:
        subprocess.run(
            [CHROME, "--headless", "--disable-gpu", f"--screenshot={OUT}",
             f"--window-size={SIZE},{SIZE}", "--default-background-color=00000000",
             f"file://{tmp}"],
            check=True, capture_output=True,
        )
    finally:
        os.remove(tmp)

    from PIL import Image
    im = Image.open(OUT)
    if im.size != (SIZE, SIZE):
        sys.exit(f"expected {SIZE}x{SIZE}, got {im.size}")
    # Play asks for a 32-bit PNG. The background is opaque and fills the square,
    # so the alpha channel is entirely 255 -- it is there to satisfy the format,
    # not to make the icon transparent, which Play would render badly anyway.
    if im.mode != "RGBA":
        im = im.convert("RGBA")
        im.save(OUT)
    print(f"{OUT}  {im.size}  mode={im.mode}  {'full 108dp' if full else 'inner 72dp'}")


if __name__ == "__main__":
    main(sys.argv[1:])
