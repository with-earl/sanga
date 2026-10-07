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
    # Two strips of tape at the top corners.
    canvas = Image.new("RGBA", (w + 60 * s, h + 60 * s), (0, 0, 0, 0))
    canvas.alpha_composite(paper, (30 * s, 30 * s))
    for x, angle in ((30 * s, 35), (w + 30 * s, -35)):
        tape = Image.new("RGBA", (70 * s, 22 * s), (236, 226, 190, 175))
        tape = tape.rotate(angle, expand=True, resample=Image.BICUBIC)
        canvas.alpha_composite(tape, (x - tape.width // 2, 30 * s - tape.height // 2))
    canvas = outline(canvas, 5, (70, 44, 24, 255))
    final = canvas.resize((canvas.width // SCALE, canvas.height // SCALE), Image.LANCZOS)
    final.save(PROPS / "police_poster.png")


def draw_card_on_floor() -> None:
    """The food delivery card lying flat on the floor, seen at the room's angle, made from the
    card's own picture so it keeps its look."""
    card = Image.open(PROPS / "food_delivery_card.png").convert("RGBA")
    card = card.resize((card.width * SCALE, card.height * SCALE), Image.LANCZOS)
    w, h = card.size
    out_w, out_h = int(w * 1.05), int(h * 0.62)
    square = [(0, 0), (w, 0), (w, h), (0, h)]
    # Lying down: the far edge is narrower and higher, the near edge wide and low.
    flat = [(int(out_w * 0.16), 0), (int(out_w * 0.9), int(out_h * 0.1)), (out_w, out_h), (0, int(out_h * 0.86))]
    lying = card.transform((out_w, out_h), Image.PERSPECTIVE, perspective_coeffs(square, flat), Image.BICUBIC)
    lying = lying.crop(lying.getbbox())
    final = lying.resize((lying.width // SCALE, lying.height // SCALE), Image.LANCZOS)
    final.save(PROPS / "food_delivery_card_floor.png")


if __name__ == "__main__":
    draw_key()
    draw_poster()
    draw_card_on_floor()
    print("Drew keys.png, police_poster.png and food_delivery_card_floor.png")
