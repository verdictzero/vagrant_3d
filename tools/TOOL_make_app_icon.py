#!/usr/bin/env python3
"""The app icon: a white cube on white with black edges, cut down the middle,
the right half inverted.

    python3 tools/TOOL_make_app_icon.py     -> ui/UI_app_icon*.png

Writes the legacy launcher icon (192), the adaptive layers (432: foreground,
background, monochrome) and the window icon (256). Drawn at 8x and shrunk,
so the edges are clean at every size. The adaptive foreground keeps the cube
inside Android's safe circle (the middle 66%); the background carries the
split so the inversion survives whatever mask the launcher cuts.
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ui")
SS = 8  # supersample

WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)
CLEAR = (0, 0, 0, 0)


def cube_points(cx, cy, r):
    """An isometric cube as its outline hexagon and the three inner edges,
    the same shape as the `object` glyph in SCRIPT_icons.gd."""
    hexagon = [(cx, cy - r), (cx + r * 0.87, cy - r * 0.5), (cx + r * 0.87, cy + r * 0.5),
               (cx, cy + r), (cx - r * 0.87, cy + r * 0.5), (cx - r * 0.87, cy - r * 0.5)]
    centre = (cx, cy)
    inner = [(centre, hexagon[1]), (centre, hexagon[5]), (centre, hexagon[3])]
    return hexagon, inner


def draw_cube(img, cx, cy, r, face, edge, width):
    d = ImageDraw.Draw(img)
    hexagon, inner = cube_points(cx, cy, r)
    if face is not None:
        d.polygon(hexagon, fill=face)
    d.line(hexagon + [hexagon[0]], fill=edge, width=width, joint="curve")
    for a, b in inner:
        d.line([a, b], fill=edge, width=width)
    # Square the joints: a dot of the edge width at each vertex.
    for x, y in hexagon + [(cx, cy)]:
        d.rectangle([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=edge)


def split(img):
    """Invert the right half (RGB only; alpha stays)."""
    w, h = img.size
    right = img.crop((w // 2, 0, w, h))
    r, g, b, a = right.split()
    inv = Image.merge("RGBA", (r.point(lambda v: 255 - v), g.point(lambda v: 255 - v),
                               b.point(lambda v: 255 - v), a))
    img.paste(inv, (w // 2, 0))
    return img


def render(size, bg, cube_scale, face, edge, width_frac, invert=True):
    s = size * SS
    img = Image.new("RGBA", (s, s), bg)
    draw_cube(img, s / 2, s / 2, s * cube_scale, face, edge, max(1, int(s * width_frac)))
    if invert:
        split(img)
    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    # Legacy launcher and window icon: the whole thing in one square.
    for size, name in [(192, "UI_app_icon.png"), (256, "UI_app_icon_256.png")]:
        render(size, WHITE, 0.36, WHITE, BLACK, 1 / 28).save(os.path.join(OUT, name))
    # Adaptive background: the split field, no cube.
    render(432, WHITE, 0.0, None, CLEAR, 1 / 28).save(os.path.join(OUT, "UI_app_icon_background.png"))
    # Adaptive foreground: the cube, in the safe circle, split to match.
    fg = render(432, CLEAR, 0.24, WHITE, BLACK, 1 / 36)
    fg.save(os.path.join(OUT, "UI_app_icon_foreground.png"))
    # Monochrome: the launcher tints the silhouette, so the edges alone.
    mono = render(432, CLEAR, 0.24, None, BLACK, 1 / 36, invert=False)
    mono.save(os.path.join(OUT, "UI_app_icon_monochrome.png"))
    for n in sorted(os.listdir(OUT)):
        if n.startswith("UI_app_icon"):
            print(os.path.join("ui", n))


if __name__ == "__main__":
    main()
