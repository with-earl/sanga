"""Draws two of the apartment's props for SANGA, in code, so the art is original and free.

- assets/props/keys.png: a brass key lying on a surface, seen from a low side angle, so it shows
  foreshortening and the thickness of the metal.
- assets/props/police_poster.png: a police emergency poster taped to the wall, with the hotline.

Everything is drawn four times larger and shrunk at the end, which gives smooth, soft edges.
Run: python tools/draw_props.py
"""

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


def gradient_shape(size, points, top, bottom, rounding: float = 0.0) -> Image.Image:
    """A filled polygon shaded from `top` to `bottom` colour, as a see-through layer. `rounding`
    softens its corners, as moulded plastic has no sharp ones."""
    w, h = size
    ys = [y for _, y in points]
    shade = Image.new("RGBA", size)
    sd = ImageDraw.Draw(shade)
    y0, y1 = min(ys), max(ys)
    for y in range(int(y0), int(y1) + 1):
        t = (y - y0) / max(y1 - y0, 1)
        sd.line([(0, y), (w, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    if rounding > 0.0:
        mask = mask.filter(ImageFilter.GaussianBlur(rounding)).point(lambda v: 255 if v >= 110 else 0)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    layer.paste(shade, (0, 0), mask)
    return layer


def draw_telephone() -> None:
    """A new desk telephone, drawn to sit exactly over the one painted on the nightstand and hide
    it: the same size, the same three-quarter angle, the handset resting on its left. Coordinates
    are pixels of the painted phone's box, drawn eight times larger and shrunk for smooth edges."""
    k = 8
    box_w, box_h = TELEPHONE_BOX[2] - TELEPHONE_BOX[0], TELEPHONE_BOX[3] - TELEPHONE_BOX[1]
    size = (box_w * k, box_h * k)
    P = lambda pts: [(x * k, y * k) for x, y in pts]
    phone = Image.new("RGBA", size, (0, 0, 0, 0))
    # The base: a dark shell whose sloping top faces the viewer.
    phone.alpha_composite(gradient_shape(size, P([(66, 30), (126, 28), (131, 33), (127, 82), (120, 96),
        (40, 96), (32, 88)]), (62, 64, 66), (30, 31, 33), 2 * k))
    # The sloping face with the keys, a little lighter.
    phone.alpha_composite(gradient_shape(size, P([(76, 33), (124, 32), (122, 80), (114, 88), (62, 88),
        (66, 50)]), (84, 86, 88), (52, 54, 57)))
    # The front lip where the base meets the table.
    phone.alpha_composite(gradient_shape(size, P([(40, 89), (116, 89), (120, 96), (40, 96)]),
        (40, 41, 43), (20, 20, 22)))
    d = ImageDraw.Draw(phone)
    # The screen, pale green-grey with a glint.
    d.polygon(P([(80, 36), (121, 35), (120, 47), (78, 48)]), fill=(150, 168, 152))
    d.polygon(P([(81, 37), (100, 36.5), (96, 41), (80, 41.5)]), fill=(186, 200, 184))
    d.line(P([(76, 51), (121, 50)]), fill=(120, 122, 124), width=k)
    # The keys: three columns of numbers and a column of function keys.
    for row in range(4):
        for col in range(3):
            x = 72 + col * 10 - row * 1.4
            y = 56 + row * 7.5
            d.rounded_rectangle(P([(x, y), (x + 7, y + 4.5)]), radius=2 * k, fill=(28, 29, 31))
            d.rounded_rectangle(P([(x + 0.5, y), (x + 6.5, y + 3.3)]), radius=2 * k, fill=(108, 110, 113))
        x = 106 - row * 1.0
        y = 55 + row * 7.5
        d.rounded_rectangle(P([(x, y), (x + 9, y + 4.5)]), radius=2 * k, fill=(28, 29, 31))
        d.rounded_rectangle(P([(x + 0.5, y), (x + 8.5, y + 3.3)]), radius=2 * k, fill=(96, 98, 101))
    # The handset, resting in its cradle on the left, with a soft shine down its back.
    handset = gradient_shape(size, P([(48, 18), (64, 18), (76, 26), (71, 34), (60, 40), (52, 74),
        (52, 86), (40, 92), (28, 88), (29, 72), (38, 46), (43, 26)]), (70, 72, 75), (30, 31, 33), 3 * k)
    phone.alpha_composite(handset)
    d.line(P([(50, 22), (44, 40), (37, 66), (35, 82)]), fill=(132, 134, 138), width=int(1.6 * k))
    d.line(P([(62, 22), (70, 27)]), fill=(118, 120, 124), width=k)
    phone = phone.resize((box_w, box_h), Image.LANCZOS)
    phone.save(PROPS / "telephone.png")


if __name__ == "__main__":
    draw_telephone()
    draw_key()
    draw_poster()
    draw_card_on_floor()
    print("Drew telephone.png, keys.png, police_poster.png and food_delivery_card_floor.png")
