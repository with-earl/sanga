"""Draws two of the apartment's props for SANGA, in code, so the art is original and free.

- assets/props/keys.png: a brass key lying on a surface, seen from a low side angle, so it shows
  foreshortening and the thickness of the metal.
- assets/props/police_poster.png: a police emergency poster taped to the wall, with the hotline.
- assets/props/telephone.png: a desk phone built as a tiny 3D model at the room's angle, fitted
  exactly over the phone painted on the nightstand.

Everything is drawn four times larger and shrunk at the end, which gives smooth, soft edges.
Run: python tools/draw_props.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
PROPS = ROOT / "assets" / "props"
SCALE = 4
INK = (46, 26, 14, 255)
FONT_BOLD = "/usr/share/fonts/opentype/inter/Inter-Bold.otf"
FONT_BLACK = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
## Where the telephone is in the apartment's painting (pixels of apartment_room_bath.png).
TELEPHONE_BOX = (1293, 503, 1443, 614)


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size * SCALE)


def outline(image: Image.Image, width: int, color=INK) -> Image.Image:
    """A soft dark outline around the shape, like the other props' cel style."""
    alpha = image.getchannel("A").point(lambda a: 255 if a > 40 else 0)
    grown = alpha.filter(ImageFilter.MaxFilter(width * 2 + 1)).filter(ImageFilter.GaussianBlur(1.2))
    back = Image.new("RGBA", image.size, color)
    back.putalpha(grown)
    back.alpha_composite(image)
    return back


def perspective_coeffs(source, target):
    """Coefficients for Image.transform(PERSPECTIVE) mapping `target` corners back to `source`."""
    import numpy as np

    rows = []
    for (x, y), (u, v) in zip(target, source):
        rows.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        rows.append([0, 0, 0, x, y, 1, -v * x, -v * y])
    a = np.array(rows, dtype=float)
    b = np.array(source, dtype=float).reshape(8)
    return np.linalg.solve(a, b).tolist()


def key_face(width: int, height: int, fill_top, fill_bottom) -> Image.Image:
    """The key's flat top face, as seen from straight above."""
    face = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)
    cy = height // 2
    # Bow: a ring with a hole, then the collar and the shaft.
    draw.ellipse((40, cy - 150, 340, cy + 150), fill=255)
    draw.ellipse((125, cy - 62, 255, cy + 62), fill=0)
    draw.rounded_rectangle((320, cy - 44, 400, cy + 44), radius=14, fill=255)
    draw.rectangle((380, cy - 26, 1180, cy + 26), fill=255)
    draw.rounded_rectangle((1150, cy - 30, 1200, cy + 30), radius=10, fill=255)
    # Teeth (the bit) along the blade.
    for x0, x1, depth in ((880, 940, 92), (980, 1030, 62), (1070, 1150, 104)):
        draw.rectangle((x0, cy, x1, cy + depth), fill=255)
    gradient = Image.linear_gradient("L").resize((width, height))
    colored = Image.composite(Image.new("RGBA", (width, height), fill_bottom), Image.new("RGBA", (width, height), fill_top), gradient)
    face.paste(colored, (0, 0), mask)
    return face


def draw_key() -> None:
    w, h = 1240, 420
    top = key_face(w, h, (247, 214, 120, 255), (206, 156, 58, 255))
    side = key_face(w, h, (150, 100, 34, 255), (118, 76, 24, 255))
    # A shine along the shaft and on the bow.
    shine = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shine)
    sd.rounded_rectangle((420, h // 2 - 18, 1100, h // 2 - 6), radius=6, fill=(255, 246, 214, 170))
    sd.arc((70, h // 2 - 120, 310, h // 2 + 120), 200, 300, fill=(255, 246, 214, 190), width=18)
    top.alpha_composite(Image.composite(shine, Image.new("RGBA", (w, h)), top.getchannel("A")))

    # Seen from a low side angle: the far side is narrower and everything is squashed in depth.
    out_w, out_h = w, 380
    square = [(0, 0), (w, 0), (w, h), (0, h)]
    tilted = [(90, 30), (out_w - 70, 70), (out_w - 10, 320), (20, 290)]
    coeffs = perspective_coeffs(square, tilted)
    top_view = top.transform((out_w, out_h), Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    side_view = side.transform((out_w, out_h), Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    # The metal's thickness: the darker side face, stacked just under the top face.
    key = Image.new("RGBA", (out_w, out_h + 40), (0, 0, 0, 0))
    thickness = 30
    for dy in range(thickness, 0, -2):
        key.alpha_composite(side_view, (0, dy))
    key.alpha_composite(top_view, (0, 0))
    key = outline(key, 9)
    key = key.crop(key.getbbox())
    pad = 24
    framed = Image.new("RGBA", (key.width + pad * 2, key.height + pad * 2), (0, 0, 0, 0))
    framed.alpha_composite(key, (pad, pad))
    final = framed.resize((framed.width // SCALE, framed.height // SCALE), Image.LANCZOS)
    final.save(PROPS / "keys.png")


def centered(draw: ImageDraw.ImageDraw, cx: int, y: int, text: str, fnt, fill) -> None:
    left, top, right, bottom = draw.textbbox((0, 0), text, font=fnt)
    draw.text((cx - (right - left) // 2 - left, y), text, font=fnt, fill=fill)


def draw_poster() -> None:
    w, h = 300 * SCALE, 420 * SCALE
    paper = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(paper)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=6 * SCALE, fill=(246, 240, 224, 255))
    # Red header band.
    d.rectangle((0, 0, w, 74 * SCALE), fill=(196, 38, 36, 255))
    centered(d, w // 2, 16 * SCALE, "EMERGENCY", font(FONT_BLACK, 38), (255, 248, 236, 255))
    # A plain badge: a blue shield with a gold star (no real emblem).
    cx, cy = w // 2, 150 * SCALE
    s = SCALE
    shield = [(cx - 50 * s, cy - 52 * s), (cx + 50 * s, cy - 52 * s), (cx + 50 * s, cy + 6 * s),
              (cx, cy + 56 * s), (cx - 50 * s, cy + 6 * s)]
    d.polygon(shield, fill=(28, 54, 120, 255))
    d.line(shield + [shield[0]], fill=(214, 170, 64, 255), width=6 * s, joint="curve")
    import math

    star = []
    for i in range(10):
        r = (26 if i % 2 == 0 else 11) * s
        a = -math.pi / 2 + i * math.pi / 5
        star.append((cx + r * math.cos(a), cy - 4 * s + r * math.sin(a)))
    d.polygon(star, fill=(232, 190, 76, 255))
    centered(d, w // 2, 222 * SCALE, "TUMAWAG SA PULIS", font(FONT_BOLD, 22), (28, 54, 120, 255))
    centered(d, w // 2, 252 * SCALE, "911", font(FONT_BLACK, 96), (196, 38, 36, 255))
    centered(d, w // 2, 368 * SCALE, "Police Emergency Hotline", font(FONT_BOLD, 15), (60, 50, 44, 255))
    # Slightly aged paper: a faint warm vignette toward the edges.
    aged = Image.radial_gradient("L").resize((w, h)).point(lambda v: int(v * 0.22))
    stain = Image.new("RGBA", (w, h), (150, 110, 60, 255))
    stain.putalpha(Image.composite(aged, Image.new("L", (w, h), 0), paper.getchannel("A")))
    paper.alpha_composite(stain)
    # Real paper: soft wrinkles from being handled, a little shading from the room's light falling
    # from the top left, and the bottom right corner lifting off the wall.
    paper = wrinkle(paper, strength=0.07, seed=3)
    light = Image.linear_gradient("L").rotate(-35, expand=False).resize((w, h)).point(lambda v: int(v * 0.16))
    shade = Image.new("RGBA", (w, h), (40, 30, 30, 255))
    shade.putalpha(Image.composite(light, Image.new("L", (w, h), 0), paper.getchannel("A")))
    paper.alpha_composite(shade)
    curl = 46 * s
    corner = ImageDraw.Draw(paper)
    corner.polygon([(w, h - curl), (w - curl, h), (w, h)], fill=(0, 0, 0, 0))
    corner.polygon([(w, h - curl), (w - curl, h), (w - curl * 0.82, h - curl * 0.82)], fill=(226, 218, 198, 255))
    # Two strips of tape at the top corners.
    canvas = Image.new("RGBA", (w + 60 * s, h + 60 * s), (0, 0, 0, 0))
    canvas.alpha_composite(paper, (30 * s, 30 * s))
    for x, angle in ((30 * s, 35), (w + 30 * s, -35)):
        tape = Image.new("RGBA", (70 * s, 22 * s), (236, 226, 190, 150))
        tape = tape.rotate(angle, expand=True, resample=Image.BICUBIC)
        canvas.alpha_composite(tape, (x - tape.width // 2, 30 * s - tape.height // 2))
    canvas = outline(canvas, 2, (90, 66, 44, 200))
    # On the room's left wall, which turns away toward a vanishing point far to the right: the right
    # edge is a little shorter and narrower, the top slopes down and the bottom slopes up.
    cw, ch = canvas.size
    out_w, out_h = int(cw * 0.89), int(ch * 1.04)
    square = [(0, 0), (cw, 0), (cw, ch), (0, ch)]
    wall = [(0, 0), (out_w, int(ch * 0.106)), (out_w, out_h), (0, int(ch * 1.0))]
    canvas = canvas.transform((out_w, out_h), Image.PERSPECTIVE, perspective_coeffs(square, wall), Image.BICUBIC)
    canvas = canvas.crop(canvas.getbbox())
    final = canvas.resize((canvas.width // SCALE, canvas.height // SCALE), Image.LANCZOS)
    final.save(PROPS / "police_poster.png")


def wrinkle(image: Image.Image, strength: float, seed: int) -> Image.Image:
    """Soft, smooth light and dark patches across paper, like gentle wrinkles."""
    import numpy as np

    rng = np.random.default_rng(seed)
    w, h = image.size
    coarse = Image.fromarray((rng.random((9, 7)) * 255).astype("uint8"), "L").resize((w, h), Image.BICUBIC)
    field = (np.asarray(coarse, dtype=float) / 255.0 - 0.5) * 2.0 * strength
    rgba = np.asarray(image, dtype=float)
    rgba[..., :3] = np.clip(rgba[..., :3] * (1.0 + field[..., None]), 0, 255)
    return Image.fromarray(rgba.astype("uint8"), "RGBA")


def _smooth(values, w: int, h: int):
    """A small grid of numbers enlarged smoothly to w x h."""
    import numpy as np

    small = Image.fromarray(np.asarray(values, dtype="float32"), "F")
    return np.asarray(small.resize((w, h), Image.BICUBIC), dtype=float)


def _sample(channel, ys, xs):
    """Reads a picture channel at fractional positions, blending the four nearest pixels."""
    import numpy as np

    h, w = channel.shape
    x0 = np.clip(np.floor(xs).astype(int), 0, w - 2)
    y0 = np.clip(np.floor(ys).astype(int), 0, h - 2)
    fx = np.clip(xs - x0, 0, 1)
    fy = np.clip(ys - y0, 0, 1)
    top = channel[y0, x0] * (1 - fx) + channel[y0, x0 + 1] * fx
    bottom = channel[y0 + 1, x0] * (1 - fx) + channel[y0 + 1, x0 + 1] * fx
    out = top * (1 - fy) + bottom * fy
    outside = (xs < 0) | (ys < 0) | (xs > w - 1) | (ys > h - 1)
    out[outside] = 0
    return out


def crumple(image: Image.Image, seed: int) -> Image.Image:
    """Paper that was crumpled and smoothed out again: flat facets each catching the light a bit
    differently, darker creases between them, and slightly bent edges."""
    import numpy as np

    rng = np.random.default_rng(seed)
    w, h = image.size
    rgba = np.asarray(image, dtype=float)
    # Facets: every pixel belongs to its nearest of a few random points.
    points = rng.random((22, 2)) * [w, h]
    ys, xs = np.mgrid[0:h:4, 0:w:4]
    dist = np.sqrt((xs[..., None] - points[:, 0]) ** 2 + (ys[..., None] - points[:, 1]) ** 2)
    order = np.sort(dist, axis=-1)
    nearest = np.argmin(dist, axis=-1)
    tone = rng.uniform(0.9, 1.05, len(points))[nearest]
    # A crease where two facets meet: the two nearest points are almost equally near.
    crease = np.clip(1.0 - (order[..., 1] - order[..., 0]) / (9.0 * SCALE), 0.0, 1.0)
    light = _smooth(tone * (1.0 - 0.13 * crease), w, h)
    # Soften the folds so they read as paper, not as drawn lines.
    folds = Image.fromarray(np.clip(light * 200.0, 0, 255).astype("uint8"), "L").filter(ImageFilter.GaussianBlur(3 * SCALE))
    light = np.asarray(folds, dtype=float) / 200.0
    rgba[..., :3] = np.clip(rgba[..., :3] * light[..., None], 0, 255)
    # Bent edges: every pixel is nudged a little by a smooth random field.
    bend = 7.0 * SCALE
    dx = _smooth(rng.uniform(-1, 1, (5, 6)), w, h) * bend
    dy = _smooth(rng.uniform(-1, 1, (5, 6)), w, h) * bend
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    out = np.stack([_sample(rgba[..., c], yy + dy, xx + dx) for c in range(4)], axis=-1)
    return Image.fromarray(np.clip(out, 0, 255).astype("uint8"), "RGBA")


def draw_card_on_floor() -> None:
    """The food delivery flyer lying on the floor, slightly crumpled, seen at the room's angle,
    made from the card's own picture so it keeps its look."""
    card = Image.open(PROPS / "food_delivery_card.png").convert("RGBA")
    card = card.resize((card.width * SCALE, card.height * SCALE), Image.LANCZOS)
    pad = 12 * SCALE
    padded = Image.new("RGBA", (card.width + pad * 2, card.height + pad * 2), (0, 0, 0, 0))
    padded.alpha_composite(card, (pad, pad))
    card = crumple(padded, seed=7).rotate(-9, expand=True, resample=Image.BICUBIC)
    w, h = card.size
    out_w, out_h = int(w * 1.05), int(h * 0.62)
    square = [(0, 0), (w, 0), (w, h), (0, h)]
    # Lying down: the far edge is narrower and higher, the near edge wide and low.
    flat = [(int(out_w * 0.16), 0), (int(out_w * 0.9), int(out_h * 0.1)), (out_w, out_h), (0, int(out_h * 0.86))]
    lying = card.transform((out_w, out_h), Image.PERSPECTIVE, perspective_coeffs(square, flat), Image.BICUBIC)
    lying = lying.crop(lying.getbbox())
    final = lying.resize((lying.width // SCALE, lying.height // SCALE), Image.LANCZOS)
    final.save(PROPS / "food_delivery_card_floor.png")


def gradient_fill(mask: Image.Image, fill_top, fill_bottom) -> Image.Image:
    """Fills the white part of `mask` with a top-to-bottom gradient, like the key's faces."""
    size = mask.size
    gradient = Image.linear_gradient("L").resize(size)
    colored = Image.composite(Image.new("RGBA", size, fill_bottom), Image.new("RGBA", size, fill_top), gradient)
    face = Image.new("RGBA", size, (0, 0, 0, 0))
    face.paste(colored, (0, 0), mask)
    return face


def draw_terminal_icon() -> None:
    """The developer tools icon: a plain terminal screen with a prompt, in the same style as the
    settings gear beside it (a thick near-black outline, a white shine) and filling the picture
    as fully as the gear does, so the two look the same size."""
    big = 8
    n = 128 * big
    ink, prompt, screen, low = (24, 24, 28, 255), (196, 199, 205, 255), (64, 68, 78, 255), (44, 47, 55, 255)
    icon = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(icon)
    s = big
    d.rounded_rectangle((3 * s, 12 * s, 125 * s, 116 * s), radius=20 * s, fill=ink)
    d.rounded_rectangle((12 * s, 21 * s, 116 * s, 107 * s), radius=12 * s, fill=low)
    d.rounded_rectangle((12 * s, 21 * s, 110 * s, 101 * s), radius=12 * s, fill=screen)
    # The prompt: a chevron and a cursor line.
    d.line([(32 * s, 42 * s), (52 * s, 61 * s), (32 * s, 80 * s)], fill=prompt, width=11 * s, joint="curve")
    d.line([(62 * s, 82 * s), (92 * s, 82 * s)], fill=prompt, width=11 * s)
    # The shine along the top left.
    d.arc((18 * s, 27 * s, 58 * s, 67 * s), 185, 255, fill=(255, 255, 255, 255), width=5 * s)
    icon.resize((128, 128), Image.LANCZOS).save(ROOT / "assets" / "ui" / "terminal.png")


## The HUD icons share one look: a thick near-black outline, shading from light at the top left,
## and a white shine. These greys are the steel parts.
ICON_INK = (24, 24, 28, 255)
ICON_LIGHT = (196, 199, 205, 255)
ICON_SHADE = (150, 153, 162, 255)


def _grid(n: int):
    """Coordinates from 0 to 1 across a square picture n pixels wide, for shading."""
    import numpy as np

    return np.mgrid[0:n, 0:n] / n


def _paint(icon: Image.Image, mask: Image.Image, rgb) -> None:
    """Paints `rgb` (a numpy picture, height x width x 3) through the white part of `mask`."""
    import numpy as np

    layer = Image.fromarray(np.clip(rgb, 0, 255).astype("uint8"), "RGB").convert("RGBA")
    icon.paste(layer, (0, 0), mask)


def _mask(n: int, draw_shape) -> Image.Image:
    mask = Image.new("L", (n, n), 0)
    draw_shape(ImageDraw.Draw(mask))
    return mask


def _finish(icon: Image.Image, name: str, s: int) -> None:
    """Adds the shared thick dark outline and a soft drop shadow, then saves the icon at 128 px."""
    alpha = icon.getchannel("A").point(lambda v: 255 if v > 20 else 0)
    ring = alpha.filter(ImageFilter.MaxFilter(7 * s + 1))
    shadow = ring.filter(ImageFilter.GaussianBlur(3 * s)).point(lambda v: int(v * 0.45))
    out = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", icon.size, (0, 0, 0, 255)), (2 * s, 3 * s), shadow)
    out.paste(Image.new("RGBA", icon.size, ICON_INK), (0, 0), ring)
    out.alpha_composite(icon)
    out.resize((128, 128), Image.LANCZOS).save(ROOT / "assets" / "ui" / name)


## How tall the open book is drawn (of 128), so it stands as tall as the clipboard on screen.
BOOK_HEIGHT = 104


def draw_book_icon() -> None:
    """The memories (Alaala) icon: an old book lying open, seen a little from above. A worn leather
    cover shows under the pages, the pages bow up from the spine with a deep shadow in the gutter,
    the stacked page edges give it thickness, and the paper is yellowed with faded writing and a
    few age spots."""
    import numpy as np

    s = 8
    n = 128 * s
    yy, xx = _grid(n)
    icon = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    # The cover: dark worn leather with a grain, a little wider and lower than the pages.
    cover = _mask(n, lambda d: d.polygon([(6 * s, 40 * s), (40 * s, 32 * s), (64 * s, 40 * s), (88 * s, 32 * s), (122 * s, 40 * s),
                                          (122 * s, 106 * s), (88 * s, 100 * s), (64 * s, 110 * s), (40 * s, 100 * s), (6 * s, 106 * s)], fill=255))
    leather = np.array([110, 62, 34], float)[None, None, :] * (1.0 - 0.35 * yy[..., None]) * (1 + 0.08 * np.sin(xx * 300 + yy * 90)[..., None])
    _paint(icon, cover, leather)
    # The stacked page edges under each page: thin cream lines, darker toward the bottom.
    for side in (-1, 1):
        for layer in range(5):
            dy = 14 - layer * 3
            edge = _mask(n, lambda d, side=side, dy=dy: d.polygon([((64) * s, (38 + dy) * s), ((64 + side * 24) * s, (30 + dy) * s), ((64 + side * 54) * s, (34 + dy) * s),
                                                                   ((64 + side * 54) * s, (88 + dy) * s), ((64 + side * 24) * s, (84 + dy) * s), (64 * s, (92 + dy) * s)], fill=255))
            tone = 200 - layer * 6 if layer % 2 == 0 else 176 - layer * 4
            _paint(icon, edge, np.full((n, n, 3), [tone, tone - 22, tone - 62], float))
    # The two pages: aged paper, brighter at the outer edge and shaded deep into the gutter.
    for side in (-1, 1):
        page = _mask(n, lambda d, side=side: d.polygon([(64 * s, 38 * s), ((64 + side * 24) * s, 28 * s), ((64 + side * 54) * s, 32 * s),
                                                       ((64 + side * 54) * s, 86 * s), ((64 + side * 24) * s, 82 * s), (64 * s, 92 * s)], fill=255))
        dist = np.abs(xx - 0.5) * 2
        light = 0.62 + 0.38 * np.clip(dist * 1.6, 0, 1) - (0.06 if side > 0 else 0.0)
        stains = 0.04 * np.sin(xx * 37 + 1.3) * np.sin(yy * 29) + 0.03 * np.sin(xx * 91 + yy * 53)
        paper = np.array([240, 224, 186], float)[None, None, :] * (light + stains)[..., None]
        _paint(icon, page, paper)
    d = ImageDraw.Draw(icon)
    # Faded handwriting, each line following the page's curve: up from the spine, then level.
    for side in (-1, 1):
        for row in range(6):
            y0 = 44 + row * 7
            length = 38 if row < 5 else 22
            pts = [((64 + side * 8) * s, (y0 + 2) * s), ((64 + side * 24) * s, (y0 - 6) * s),
                   ((64 + side * (8 + length)) * s, (y0 - 4) * s)]
            d.line(pts, fill=(150, 116, 76, 255), width=int(1.5 * s), joint="curve")
    # A few faint age spots, blended into the paper.
    spots = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    sd = ImageDraw.Draw(spots)
    for cx, cy, r in ((30, 72, 5), (98, 50, 4), (86, 76, 6)):
        sd.ellipse(((cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s), fill=(170, 130, 70, 60))
    spots = spots.filter(ImageFilter.GaussianBlur(2 * s))
    icon.alpha_composite(Image.composite(spots, Image.new("RGBA", (n, n)), icon.getchannel("A")))
    # The gutter: a dark crease where the pages meet the spine.
    d.line([(64 * s, 38 * s), (64 * s, 92 * s)], fill=(90, 62, 36, 255), width=3 * s)
    # A soft shine on the upper left page.
    d.arc((14 * s, 30 * s, 54 * s, 70 * s), 200, 255, fill=(255, 252, 240, 255), width=3 * s)
    # Seen more from above, so the book stands as tall as the clipboard beside it.
    box = icon.getbbox()
    book = icon.crop(box)
    tall = book.resize((book.width, BOOK_HEIGHT * s), Image.LANCZOS)
    icon = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    icon.alpha_composite(tall, ((n - tall.width) // 2, (n - tall.height) // 2))
    _finish(icon, "book.png", s)


def draw_clipboard_icon() -> None:
    """The objectives icon: a brown hardboard clipboard with real thickness, a sheet of paper whose
    corner lifts a little, and a steel clip with a lever, a hole and rivets."""
    import numpy as np

    s = 8
    n = 128 * s
    yy, xx = _grid(n)
    icon = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    # The board's thickness: a darker copy below and to the right of its face.
    side = _mask(n, lambda d: d.rounded_rectangle((22 * s, 18 * s, 112 * s, 124 * s), radius=10 * s, fill=255))
    _paint(icon, side, np.full((n, n, 3), [88, 52, 26], float))
    face = _mask(n, lambda d: d.rounded_rectangle((16 * s, 12 * s, 106 * s, 118 * s), radius=10 * s, fill=255))
    shade = 1.06 - 0.38 * (xx * 0.4 + yy * 0.6)
    grain = 0.05 * np.sin(yy * 250 + np.sin(xx * 11) * 4) + 0.025 * np.sin(yy * 700 + xx * 20)
    _paint(icon, face, np.array([156, 102, 58], float)[None, None, :] * (shade + grain)[..., None])
    d = ImageDraw.Draw(icon)
    d.rounded_rectangle((16 * s, 12 * s, 106 * s, 118 * s), radius=10 * s, outline=(204, 150, 98, 255), width=int(1.5 * s))
    # The paper, with a soft shadow, faint lines, a checklist and a lifted bottom right corner.
    shadow = _mask(n, lambda dd: dd.rectangle((29 * s, 35 * s, 97 * s, 113 * s), fill=255)).filter(ImageFilter.GaussianBlur(2 * s))
    icon.paste(Image.new("RGBA", (n, n), (40, 20, 8, 255)), (0, 0), shadow.point(lambda v: int(v * 0.6)))
    sheet = _mask(n, lambda dd: dd.polygon([(26 * s, 32 * s), (94 * s, 32 * s), (94 * s, 98 * s), (82 * s, 110 * s), (26 * s, 110 * s)], fill=255))
    _paint(icon, sheet, np.array([248, 244, 232], float)[None, None, :] * (1.0 - 0.12 * yy[..., None]))
    d.polygon([(94 * s, 98 * s), (82 * s, 110 * s), (84 * s, 99 * s)], fill=(214, 206, 188, 255))
    for row in range(6):
        y = (48 + row * 10) * s
        d.line([(32 * s, y), (88 * s, y)], fill=(170, 192, 220, 255), width=s)
    d.line([(33 * s, 52 * s), (38 * s, 57 * s), (46 * s, 46 * s)], fill=(36, 36, 44, 255), width=4 * s, joint="curve")
    d.line([(52 * s, 53 * s), (84 * s, 53 * s)], fill=(60, 60, 70, 255), width=3 * s)
    for y in (66, 86):
        d.rectangle((33 * s, y * s, 43 * s, (y + 10) * s), outline=(36, 36, 44, 255), width=3 * s)
        d.line([(52 * s, (y + 6) * s), (80 * s, (y + 6) * s)], fill=(60, 60, 70, 255), width=3 * s)
    # The steel clip: a dark back plate, a shaded lever bent toward the viewer, a hole and rivets.
    d.rounded_rectangle((34 * s, 2 * s, 88 * s, 40 * s), radius=8 * s, fill=ICON_INK)
    plate = _mask(n, lambda dd: dd.rounded_rectangle((39 * s, 22 * s, 83 * s, 36 * s), radius=4 * s, fill=255))
    _paint(icon, plate, np.full((n, n, 3), [128, 132, 142], float))
    lever = _mask(n, lambda dd: dd.rounded_rectangle((40 * s, 7 * s, 82 * s, 24 * s), radius=6 * s, fill=255))
    band = np.cos((yy - 15 / 128) * 40)
    _paint(icon, lever, np.stack([170 + 70 * band, 172 + 70 * band, 180 + 66 * band], axis=-1))
    d.ellipse((56 * s, 10 * s, 66 * s, 18 * s), fill=ICON_INK)
    d.line([(44 * s, 10 * s), (54 * s, 10 * s)], fill=(255, 255, 255, 255), width=2 * s)
    for x in (46, 76):
        d.ellipse(((x - 3) * s, 27 * s, (x + 3) * s, 33 * s), fill=(96, 98, 108, 255))
        d.ellipse(((x - 2) * s, 28 * s, x * s, 30 * s), fill=(240, 240, 244, 255))
    d.arc((20 * s, 16 * s, 48 * s, 44 * s), 190, 255, fill=(255, 236, 210, 255), width=3 * s)
    _finish(icon, "clipboard.png", s)


def draw_gear_icon() -> None:
    """The settings icon: a thick steel cog seen slightly from the front, so its side shows. The
    face is brushed metal lit from the top left, each tooth has a bevelled edge, a raised hub ring
    sits around a dark bolt hole, and a bright highlight runs along the top."""
    import math

    import numpy as np

    s = 8
    n = 128 * s
    c = 62 * s
    teeth, r_out, r_in, r_hole = 8, 56 * s, 42 * s, 15 * s
    yy, xx = _grid(n)

    def cog(scale: float, dx: float = 0.0, dy: float = 0.0) -> list:
        points = []
        for i in range(teeth * 8):
            a = (i / (teeth * 8)) * 2 * math.pi - math.pi / 2
            phase = i % 8
            r = r_out if 2 <= phase <= 5 else r_in
            points.append((c + dx + r * scale * math.cos(a), c + dy + r * scale * math.sin(a)))
        return points

    icon = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    # The cog's thickness: darker steel shifted down and right.
    for step in range(6, 0, -1):
        side = _mask(n, lambda d, step=step: d.polygon(cog(1.0, step * s, step * s), fill=255))
        _paint(icon, side, np.full((n, n, 3), 70 + step * 6, float))
    # The bevel: a slightly smaller lighter ring around the face.
    body = _mask(n, lambda d: d.polygon(cog(1.0), fill=255))
    _paint(icon, body, np.full((n, n, 3), [128, 132, 142], float))
    face = _mask(n, lambda d: d.polygon(cog(0.9, -s, -s), fill=255))
    lit = 1.08 - 0.5 * (xx * 0.5 + yy * 0.5)
    # Soft rings of brushed metal around the centre, wide enough to stay smooth when shrunk.
    radius = np.hypot(xx - 0.48, yy - 0.48)
    brushed = 0.04 * np.sin(radius * 70)
    metal = 200 * (lit + brushed)
    _paint(icon, face, np.stack([metal, metal + 4, metal + 12], axis=-1))
    d = ImageDraw.Draw(icon)
    # The raised hub: a dark groove, a lit rim, and the bolt hole with its inner wall.
    d.ellipse((c - 30 * s, c - 30 * s, c + 30 * s, c + 30 * s), outline=(96, 100, 110, 255), width=3 * s)
    d.ellipse((c - 27 * s, c - 27 * s, c + 27 * s, c + 27 * s), outline=(240, 242, 246, 255), width=2 * s)
    d.ellipse((c - r_hole - 4 * s, c - r_hole - 4 * s, c + r_hole + 4 * s, c + r_hole + 4 * s), fill=(150, 154, 164, 255))
    d.ellipse((c - r_hole - 2 * s, c - r_hole - 2 * s, c + r_hole + 2 * s, c + r_hole + 2 * s), fill=ICON_INK)
    # The hole's inner wall: a sliver of dark steel at the top, as the hole goes through the cog.
    d.ellipse((c - r_hole + 2 * s, c - r_hole + 3 * s, c + r_hole - 2 * s, c + r_hole - 1 * s), fill=(0, 0, 0, 0))
    d.arc((c - 46 * s, c - 46 * s, c + 46 * s, c + 46 * s), 200, 250, fill=(255, 255, 255, 255), width=4 * s)
    _finish(icon, "gear.png", s)


class PhoneModel:
    """A very small 3D model of the desk telephone, so its faces have a true angle, depth and light.
    The phone is built from flat faces in the room's space (x to the right, y up, z away from the
    viewer), seen by a camera a little above and to the right like the room's painting, lit from
    the window side, and drawn back to front. The base is a wedge whose top leans back toward the
    viewer; the handset lies on the left of that slope."""

    TILT = math.radians(44)
    SLOPE = 176.0
    FRONT = 16.0
    WIDTH = 196.0
    CAMERA_YAW = math.radians(-9)
    CAMERA_PITCH = math.radians(17)
    LIGHT = (0.42, 0.78, -0.46)

    def __init__(self) -> None:
        self.faces = []

    def on_slope(self, u: float, v: float, n: float):
        """A point on the base's sloping top: `u` across, `v` up the slope, `n` raised off it."""
        c, s = math.cos(self.TILT), math.sin(self.TILT)
        return (u, self.FRONT + v * s + n * c, v * c - n * s)

    def project(self, point):
        x, y, z = point
        x -= self.WIDTH / 2
        cy, sy = math.cos(self.CAMERA_YAW), math.sin(self.CAMERA_YAW)
        x, z = x * cy + z * sy, -x * sy + z * cy
        cp, sp = math.cos(self.CAMERA_PITCH), math.sin(self.CAMERA_PITCH)
        y, z = y * cp + z * sp, -y * sp + z * cp
        distance = 1400.0
        return (x * distance / (z + distance), -y * distance / (z + distance), z)

    def add(self, points, color, layer: int, texture=None) -> None:
        self.faces.append({"points": points, "color": color, "layer": layer, "texture": texture})

    def shade(self, points) -> float:
        import numpy as np

        a, b, c = (np.array(p, dtype=float) for p in points[:3])
        normal = np.cross(b - a, c - a)
        normal /= np.linalg.norm(normal) + 1e-9
        light = np.array(self.LIGHT) / np.linalg.norm(self.LIGHT)
        return 0.66 + 0.5 * max(float(np.dot(normal, light)), 0.0)

    def block(self, u0, u1, v0, v1, height, bevel, color, layer, texture=None, taper=0.0) -> None:
        """A raised block on the slope with chamfered top edges, like moulded plastic."""
        def ring(inset, n, shrink=0.0):
            return [self.on_slope(u0 + inset + shrink, v0 + inset, n), self.on_slope(u1 - inset - shrink, v0 + inset, n),
                    self.on_slope(u1 - inset - shrink, v1 - inset, n), self.on_slope(u0 + inset + shrink, v1 - inset, n)]
        base, edge, top = ring(0, 0), ring(0, height - bevel, taper), ring(bevel, height, taper)
        for low, high in ((base, edge), (edge, top)):
            for i in range(4):
                j = (i + 1) % 4
                self.add([low[i], low[j], high[j], high[i]], color, layer)
        self.add(top, color, layer, texture)

    def wedge(self, color) -> None:
        """The base: flat on the table, its top sloping up and away, with a bevelled rim."""
        c, s = math.cos(self.TILT), math.sin(self.TILT)
        depth, back = self.SLOPE * c, self.FRONT + self.SLOPE * s
        w, b = self.WIDTH, 7.0
        floor = [(0, 0, 0), (w, 0, 0), (w, 0, depth), (0, 0, depth)]
        rim = [(0, self.FRONT, 0), (w, self.FRONT, 0), (w, back, depth), (0, back, depth)]
        for i in range(4):
            j = (i + 1) % 4
            self.add([floor[i], floor[j], rim[j], rim[i]], color, 0)
        top = [self.on_slope(b, b, b * 0.7), self.on_slope(w - b, b, b * 0.7),
               self.on_slope(w - b, self.SLOPE - b, b * 0.7), self.on_slope(b, self.SLOPE - b, b * 0.7)]
        for i in range(4):
            j = (i + 1) % 4
            self.add([rim[i], rim[j], top[j], top[i]], color, 0)
        self.add(top, color, 0, "face")
        return top


def phone_face_texture(width: int, height: int) -> Image.Image:
    """The base's sloping top, straight on: a plain cradle on the left (the handset hides most of
    it), then the screen, a chrome strip and the keys, each key with a lit top and a dark rim."""
    face = gradient_fill(Image.new("L", (width, height), 255), (92, 94, 98, 255), (66, 68, 72, 255))
    d = ImageDraw.Draw(face)
    left = int(width * 0.33)
    d.rectangle((0, 0, left - 12, height), fill=(52, 54, 58, 255))
    d.line((left - 12, 0, left - 12, height), fill=(36, 37, 40, 255), width=6)
    # The image's top is the far (upper) end of the slope.
    d.rounded_rectangle((left + 30, 40, width - 40, 200), radius=14, fill=(34, 36, 38, 255))
    d.rounded_rectangle((left + 42, 52, width - 52, 188), radius=10, fill=(150, 170, 152, 255))
    d.polygon([(left + 52, 62), (left + 230, 62), (left + 170, 122), (left + 52, 122)], fill=(190, 204, 188, 255))
    d.rounded_rectangle((left + 30, 236, width - 40, 250), radius=7, fill=(176, 178, 182, 255))
    # Three soft keys under the screen and a small red light.
    soft = (width - 40 - (left + 30)) / 3
    for i in range(3):
        x = left + 30 + i * soft
        d.rounded_rectangle((x + 14, 205, x + soft - 14, 226), radius=10, fill=(44, 46, 50, 255))
    d.ellipse((width - 64, 24, width - 46, 42), fill=(214, 70, 56, 255))
    # A speaker grille at the near end.
    for row in range(3):
        for col in range(9):
            cx, cy = left + 60 + col * 26, height - 70 + row * 18
            d.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=(36, 37, 40, 255))
    def key(x0, y0, x1, y1, top):
        d.rounded_rectangle((x0, y0 + 12, x1, y1 + 12), radius=18, fill=(24, 25, 28, 255))
        d.rounded_rectangle((x0, y0, x1, y1), radius=18, fill=top)
        d.rounded_rectangle((x0 + 12, y0 + 6, x1 - 12, y0 + 18), radius=6, fill=(176, 178, 184, 255))
    columns = (width - 40 - (left + 30)) / 4
    for row in range(4):
        y = 286 + row * 98
        for col in range(3):
            x = left + 30 + col * columns
            key(x + 8, y, x + columns - 16, y + 70, (120, 122, 128, 255))
        x = left + 30 + 3 * columns
        key(x + 18, y, x + columns - 4, y + 70, (178, 66, 52, 255) if row == 3 else (102, 104, 110, 255))
    return face


def handset_texture(width: int, height: int) -> Image.Image:
    """The handset's top: a soft shine down its length and the earpiece holes at the far end."""
    top = gradient_fill(Image.new("L", (width, height), 255), (108, 110, 116, 255), (64, 66, 70, 255))
    d = ImageDraw.Draw(top)
    d.rounded_rectangle((width * 0.62, height * 0.06, width * 0.78, height * 0.94), radius=10, fill=(150, 152, 158, 255))
    return top


def draw_telephone() -> None:
    """A desk telephone, drawn like the keys, poster and flyer (soft gradients, a shine, the props'
    dark outline), but built as a small 3D model so it sits in the room at the painting's angle.
    It is then fitted over the phone painted on the nightstand so it hides it completely
    (coordinates are pixels of that phone's box)."""
    import numpy as np

    k = 2 * SCALE
    box_w, box_h = TELEPHONE_BOX[2] - TELEPHONE_BOX[0], TELEPHONE_BOX[3] - TELEPHONE_BOX[1]
    model = PhoneModel()
    body = (92, 94, 100)
    model.wedge(body)
    # The handset: earpiece and mouthpiece blocks joined by a slimmer grip, lying on the cradle.
    grey = (98, 100, 106)
    model.block(4, 62, 2, 52, 30, 10, grey, 1, taper=3)
    model.block(4, 62, 126, 174, 30, 10, grey, 1, taper=3)
    model.block(12, 54, 28, 152, 22, 8, grey, 1, "handset")
    textures = {"face": phone_face_texture(600, 760), "handset": handset_texture(220, 760)}

    projected = []
    for face in model.faces:
        pts = [model.project(p) for p in face["points"]]
        flat = [(x, y) for x, y, _ in pts]
        area = sum(flat[i][0] * flat[(i + 1) % len(flat)][1] - flat[(i + 1) % len(flat)][0] * flat[i][1] for i in range(len(flat)))
        if area >= 0:
            continue
        depth = sum(z for _, _, z in pts) / len(pts)
        projected.append((face["layer"], -depth, flat, face))
    projected.sort(key=lambda item: (item[0], item[1]))

    # Fit the drawing over the painted phone: its edge must be covered everywhere.
    painted = [(49, 22), (58, 20), (70, 21), (75, 26), (79, 26), (125, 29), (128, 33), (127, 41), (126, 60),
               (125, 79), (119, 88), (113, 95), (70, 94), (40, 90), (30, 85), (30, 74), (37, 56), (45, 31)]
    xs = [x for _, _, flat, _ in projected for x, _ in flat]
    ys = [y for _, _, flat, _ in projected for _, y in flat]
    def silhouette(rect):
        mask = Image.new("L", (box_w * 2, box_h * 2), 0)
        md = ImageDraw.Draw(mask)
        sx, sy = (rect[2] - rect[0]) / (max(xs) - min(xs)), (rect[3] - rect[1]) / (max(ys) - min(ys))
        for _, _, flat, _ in projected:
            md.polygon([((x - min(xs)) * sx * 2 + rect[0] * 2, (y - min(ys)) * sy * 2 + rect[1] * 2) for x, y in flat], fill=255)
        return np.asarray(mask) > 0
    target = Image.new("L", (box_w * 2, box_h * 2), 0)
    ImageDraw.Draw(target).polygon([(x * 2, y * 2) for x, y in painted], fill=255)
    target = np.asarray(target) > 0
    px, py = [x for x, _ in painted], [y for _, y in painted]
    rect = [min(px), min(py), max(px), max(py)]
    for _ in range(40):
        missed = target & ~silhouette(rect)
        if not missed.any():
            break
        my, mx = np.nonzero(missed)
        cx, cy = (rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2
        if (mx / 2 < cx).any(): rect[0] -= 0.5
        if (mx / 2 >= cx).any(): rect[2] += 0.5
        if (my / 2 < cy).any(): rect[1] -= 0.5
        if (my / 2 >= cy).any(): rect[3] = min(rect[3] + 0.5, max(py) + 1.5)
    sx, sy = (rect[2] - rect[0]) / (max(xs) - min(xs)), (rect[3] - rect[1]) / (max(ys) - min(ys))
    to_canvas = lambda x, y: (((x - min(xs)) * sx + rect[0]) * k, ((y - min(ys)) * sy + rect[1]) * k)

    size = (box_w * k, box_h * k)
    layers = [Image.new("RGBA", size, (0, 0, 0, 0)) for _ in range(2)]
    for layer, _, flat, face in projected:
        phone = layers[layer]
        corners = [to_canvas(x, y) for x, y in flat]
        light = model.shade(face["points"])
        if face["texture"] is None:
            color = tuple(min(int(ch * light), 255) for ch in face["color"]) + (255,)
            ImageDraw.Draw(phone).polygon(corners, fill=color)
            continue
        texture = textures[face["texture"]]
        tw, th = texture.size
        # Texture rows run from the far end of the slope (top) to the near end (bottom).
        ordered = [corners[3], corners[2], corners[1], corners[0]]
        square = [(0, 0), (tw, 0), (tw, th), (0, th)]
        warped = texture.transform(size, Image.PERSPECTIVE, perspective_coeffs(square, ordered), Image.BICUBIC)
        lit = Image.eval(warped.convert("RGB"), lambda v: min(int(v * light), 255)).convert("RGBA")
        mask = Image.new("L", size, 0)
        ImageDraw.Draw(mask).polygon(corners, fill=255)
        phone.paste(lit, (0, 0), mask)
    # The handset casts a soft shadow onto the base, away from the window, and has its own thin
    # dark edge so it reads as a separate piece resting in the cradle.
    phone, handset = layers
    shadow = Image.new("RGBA", size, (10, 8, 8, 0))
    shadow.putalpha(handset.getchannel("A").filter(ImageFilter.GaussianBlur(2 * k)).point(lambda a: int(a * 0.7)))
    shadow = Image.composite(shadow, Image.new("RGBA", size), phone.getchannel("A"))
    phone.alpha_composite(shadow, (-2 * k, k))
    phone.alpha_composite(outline(handset, k // 2, (20, 16, 16, 255)))
    phone = outline(phone, k, INK)
    phone.resize((box_w, box_h), Image.LANCZOS).save(PROPS / "telephone.png")


if __name__ == "__main__":
    draw_terminal_icon()
    draw_book_icon()
    draw_clipboard_icon()
    draw_gear_icon()
    draw_telephone()
    draw_key()
    draw_poster()
    draw_card_on_floor()
    print("Drew telephone.png, keys.png, police_poster.png and food_delivery_card_floor.png")
