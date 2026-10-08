"""Cutscene pictures whose subject is a thing or a place, built in 3D with scene3d.py like the
police car, so they have a true camera angle, perspective and light.

- true_morning_batista.png: Batista's badge left on a desk in morning light, beside a folded
  letter headed "Pagbibitiw" and a cup of coffee gone cold.
- true_visiting.png: a jail visiting booth seen from the visitor's chair: a counter, a partition
  with a glass window and a round speaking grille (like a confessional's), and behind the glass
  Father Eli in an inmate's orange shirt, facing us.
- padala_jeep.png: inside a jeepney at night, from the back: red vinyl benches, chrome handrails,
  a painted ceiling, the city's lights streaking past the open windows, and Mercy on the bench.
- tokhang_tv_news.png: a dark room at night lit only by an old television, showing the news: a
  street under police lights and a red news bar, "OPERASYON: 3 PATAY".
- prologue_booth.png: inside the confessional, on the priest's side: dark wood, and through the
  lattice screen a faint candle glow and the shape of someone kneeling close.
- padala_luggage.png / padala_luggage_closed.png: a hard suitcase on the apartment floor, open and
  empty, its lining crushed; then shut, in the dark.
"""

import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import scene3d as s3
from street_scene import finish, noise

SERIF = str((__import__("pathlib").Path(__file__).resolve().parent.parent / "assets" / "fonts" / "Lora.ttf"))
FONT_BLACK = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
SUN = (255, 214, 160)


# ---------------------------------------------------------------- shared pieces


def wood(w: int, h: int, seed: int, base=(120, 74, 44)) -> Image.Image:
    """Varnished wood: long grain along the width, a few darker knots, a soft sheen."""
    grain = noise(w, h // 6 + 2, 3, seed)
    grain = np.asarray(Image.fromarray((grain * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float32) / 255
    rings = 0.5 + 0.5 * np.sin(np.linspace(0, 40, h)[:, None] + grain * 9)
    shade = 0.78 + 0.16 * rings + 0.12 * noise(w, h, 120, seed + 1)
    rgb = np.array(base, np.float32)[None, None, :] * shade[..., None]
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert("RGBA")


def blinds_light(w: int, h: int, angle: float, bands: int, strength: int) -> Image.Image:
    """Morning sun through window blinds: warm bright bands at a slant, soft at their edges."""
    light = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(light)
    step = h / bands
    slant = math.tan(math.radians(angle)) * w
    for i in range(-bands, bands * 2):
        y = i * step
        d.polygon([(0, y), (w, y + slant), (w, y + slant + step * 0.55), (0, y + step * 0.55)], fill=SUN + (strength,))
    return light.filter(ImageFilter.GaussianBlur(step * 0.12))


def cylinder(scene: s3.Scene, center, radius: float, height: float, color, top=None, sides: int = 20, layer: int = 2):
    """An upright cylinder (a mug, a cup), with its top as a separate colour."""
    cx, cy, cz = center
    ring = [(cx + math.cos(a) * radius, cz + math.sin(a) * radius) for a in np.linspace(0, 2 * math.pi, sides, endpoint=False)]
    for i in range(sides):
        (x0, z0), (x1, z1) = ring[i], ring[(i + 1) % sides]
        scene.face([(x0, cy + height, z0), (x1, cy + height, z1), (x1, cy, z1), (x0, cy, z0)], color, layer=layer, two_sided=True)
    scene.face([(x, cy + height, z) for x, z in ring], top or color, layer=layer + 1, two_sided=True)


# ---------------------------------------------------------------- Batista's badge


def badge_texture(size: int = 600) -> Image.Image:
    """A generic police badge, seen from above: a gold shield with a blue enamel centre, a star
    and the word PULIS. Not any real force's insignia."""
    k = 2
    s = size * k
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    shield = [(s * 0.5, s * 0.04), (s * 0.9, s * 0.16), (s * 0.86, s * 0.6), (s * 0.5, s * 0.96), (s * 0.14, s * 0.6), (s * 0.1, s * 0.16)]
    d.polygon(shield, fill=(156, 112, 34, 255))
    inner = [(s * 0.5 + (x - s * 0.5) * 0.86, s * 0.5 + (y - s * 0.5) * 0.86) for x, y in shield]
    d.polygon(inner, fill=(214, 170, 70, 255))
    d.ellipse((s * 0.27, s * 0.27, s * 0.73, s * 0.73), fill=(150, 108, 32, 255))
    d.ellipse((s * 0.3, s * 0.3, s * 0.7, s * 0.7), fill=(28, 48, 120, 255))
    star = [(s * 0.5 + math.cos(math.pi / 2 + i * math.pi / 5) * (s * 0.15 if i % 2 == 0 else s * 0.065),
             s * 0.5 - math.sin(math.pi / 2 + i * math.pi / 5) * (s * 0.15 if i % 2 == 0 else s * 0.065)) for i in range(10)]
    d.polygon(star, fill=(232, 196, 92, 255))
    font = ImageFont.truetype(FONT_BLACK, int(s * 0.08))
    word = "PULIS"
    d.text((s * 0.5 - d.textlength(word, font=font) / 2, s * 0.76), word, font=font, fill=(110, 76, 20, 255))
    # A worn shine across the metal.
    shine = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(shine).polygon([(s * 0.2, s * 0.05), (s * 0.42, s * 0.05), (s * 0.18, s * 0.6), (s * 0.08, s * 0.5)], fill=(255, 240, 200, 90))
    shine = shine.filter(ImageFilter.GaussianBlur(s * 0.03))
    shine.putalpha(Image.composite(shine.getchannel("A"), Image.new("L", (s, s), 0), img.getchannel("A")))
    img.alpha_composite(shine)
    return img.resize((size, size), Image.LANCZOS)


def letter_texture(w: int = 700, h: int = 900) -> Image.Image:
    """A sheet of paper, handwritten: "Pagbibitiw" and a few lines, signed."""
    paper = Image.new("RGBA", (w, h), (238, 232, 216, 255))
    d = ImageDraw.Draw(paper)
    for y in range(140, h - 60, 46):
        d.line((50, y, w - 50, y), fill=(196, 206, 220, 255), width=2)
    hand = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hand)
    title = ImageFont.truetype(SERIF, 64)
    body = ImageFont.truetype(SERIF, 34)
    hd.text((70, 40), "Pagbibitiw", font=title, fill=(30, 40, 90, 255))
    lines = ["Sa kinauukulan,", "Ako ay nagbibitiw sa tungkulin", "simula sa araw na ito.", "", "Patawarin n'yo ako.", "", "                    — Batista"]
    for i, text in enumerate(lines):
        hd.text((70, 150 + i * 46 - 34), text, font=body, fill=(30, 40, 90, 255))
    # Lean the writing like a hand, then lay it on the paper.
    hand = hand.transform((w, h), Image.AFFINE, (1, 0.18, -60, 0, 1, 0), Image.BICUBIC)
    paper.alpha_composite(hand)
    # A fold across the middle.
    d.line((0, h * 0.5, w, h * 0.5), fill=(214, 206, 188, 255), width=4)
    return paper


def true_morning_batista(size) -> Image.Image:
    w, h = size
    desk_y = 0.75
    camera = s3.Camera((0.04, desk_y + 0.36, -0.02), 0.0, -40.0, 40.0, size)
    scene = s3.Scene(camera, ambient=(112, 104, 96), sky_dir=(0.4, 1.0, 0.3))
    desk = wood(1400, 900, 3)
    sun = blinds_light(1400, 900, 14, 6, 70)
    scene.face([(-0.9, desk_y, 1.2), (0.9, desk_y, 1.2), (0.9, desk_y, -0.2), (-0.9, desk_y, -0.2)], (120, 74, 44),
               texture=desk, glow=sun, layer=0)
    # Behind the desk, the wall, with the same light from the blinds falling on it.
    wall = Image.new("RGBA", (800, 400), (190, 180, 162, 255))
    scene.face([(-1.2, desk_y + 0.9, 1.2), (1.2, desk_y + 0.9, 1.2), (1.2, desk_y, 1.2), (-1.2, desk_y, 1.2)], (190, 180, 162),
               texture=wall, glow=blinds_light(800, 400, -6, 5, 80), layer=0)
    # The letter, a little askew, and the badge set down on its corner.
    def flat(cx, cz, half_w, half_d, turn, y):
        c, s_ = math.cos(math.radians(turn)), math.sin(math.radians(turn))
        corners = [(-half_w, half_d), (half_w, half_d), (half_w, -half_d), (-half_w, -half_d)]
        return [(cx + x * c - z * s_, y, cz + x * s_ + z * c) for x, z in corners]
    scene.face(flat(-0.07, 0.39, 0.105, 0.135, 9, desk_y + 0.002), (238, 232, 216), texture=letter_texture(),
               glow=blinds_light(700, 900, 14, 3, 45), layer=1)
    scene.face(flat(0.035, 0.33, 0.046, 0.046, -14, desk_y + 0.006), (214, 170, 70), texture=badge_texture(), layer=2)
    # The coffee, gone cold.
    cylinder(scene, (0.2, desk_y, 0.47), 0.042, 0.095, (232, 228, 220), top=(54, 34, 22))
    scene.box(0.238, 0.258, desk_y + 0.025, desk_y + 0.07, 0.46, 0.48, (232, 228, 220), layer=2)
    scene.light((0.7, desk_y + 0.55, 0.15), SUN, 3.2)
    canvas = Image.new("RGBA", size, (40, 32, 28, 255))
    canvas = scene.render(canvas)
    return finish(canvas)


# ---------------------------------------------------------------- the visiting booth


def in_jail_orange(picture: Image.Image, neckline: int, collar_box) -> Image.Image:
    """The priest's black clothes, below the neckline, turned into an inmate's orange shirt, keeping
    their folds and shading; the white collar tab is covered over the same way."""
    pixels = np.asarray(picture).astype(np.float32)
    rgb, alpha = pixels[..., :3], pixels[..., 3]
    light = rgb.mean(axis=2)
    spread = rgb.max(axis=2) - rgb.min(axis=2)
    ys = np.arange(picture.height)[:, None] * np.ones((1, picture.width))
    xs = np.ones((picture.height, 1)) * np.arange(picture.width)[None, :]
    cloth = (ys > neckline) & (light < 75) & (spread < 40) & (alpha > 0)
    x0, y0, x1, y1 = collar_box
    collar = (xs >= x0) & (xs <= x1) & (ys >= y0) & (ys <= y1) & (light > 150)
    shade = np.clip(light / 75.0, 0, 1)[..., None]
    dark, bright = np.array([118, 46, 12], np.float32), np.array([236, 118, 40], np.float32)
    orange = dark + (bright - dark) * (0.25 + 0.75 * shade)
    rgb = np.where((cloth | collar)[..., None], np.where(collar[..., None], dark + (bright - dark) * 0.7, orange), rgb)
    return Image.fromarray(np.concatenate([np.clip(rgb, 0, 255), alpha[..., None]], axis=2).astype(np.uint8), "RGBA")


def true_visiting(size, eli: Image.Image) -> Image.Image:
    w, h = size
    camera = s3.Camera((0.0, 1.22, -0.55), 0.0, -2.0, 46.0, size)
    scene = s3.Scene(camera, ambient=(120, 128, 126), sky_dir=(0.0, 1.0, -0.4))
    green, steel = (150, 172, 158), (120, 126, 128)
    # The visitor's counter, and the partition with its window.
    scene.box(-1.2, 1.2, 0.86, 0.9, -0.1, 0.42, (128, 112, 96), layer=1)
    for x0, x1, y0, y1 in ((-1.4, -0.42, 0.0, 2.6), (0.42, 1.4, 0.0, 2.6), (-0.42, 0.42, 0.0, 0.96), (-0.42, 0.42, 1.74, 2.6)):
        scene.face([(x0, y1, 0.42), (x1, y1, 0.42), (x1, y0, 0.42), (x0, y0, 0.42)], green, layer=1)
    for x0, x1, y0, y1 in ((-0.45, -0.42, 0.96, 1.74), (0.42, 0.45, 0.96, 1.74)):
        scene.face([(x0, y1, 0.41), (x1, y1, 0.41), (x1, y0, 0.41), (x0, y0, 0.41)], steel, layer=1)
    scene.face([(-0.45, 1.77, 0.41), (0.45, 1.77, 0.41), (0.45, 1.74, 0.41), (-0.45, 1.74, 0.41)], steel, layer=1)
    scene.face([(-0.45, 0.96, 0.41), (0.45, 0.96, 0.41), (0.45, 0.93, 0.41), (-0.45, 0.93, 0.41)], steel, layer=1)
    # The inmate's side: a bare room, a fluorescent tube, his own counter.
    back = noise(600, 400, 40, 5)
    back_img = Image.fromarray(np.stack([150 + back * 20, 160 + back * 20, 150 + back * 20], axis=-1).astype(np.uint8)).convert("RGBA")
    scene.face([(-1.4, 2.6, 2.4), (1.4, 2.6, 2.4), (1.4, 0.0, 2.4), (-1.4, 0.0, 2.4)], (150, 160, 150), texture=back_img, layer=0)
    scene.box(-0.6, 0.6, 2.3, 2.34, 2.0, 2.1, (240, 250, 255), layer=0, emissive=True)
    scene.light((0.0, 2.25, 1.6), (220, 240, 255), 4.0)
    scene.box(-1.2, 1.2, 0.0, 0.9, 0.44, 1.0, (110, 100, 88), layer=1)
    # Father Eli, seated across the glass: only his shoulders and head rise above the counter.
    tall = 1.8
    half = tall * eli.width / eli.height / 2
    seat = -0.2
    scene.face([(-half, seat + tall, 1.25), (half, seat + tall, 1.25), (half, seat, 1.25), (-half, seat, 1.25)],
               (200, 200, 200), texture=eli, layer=0)
    canvas = Image.new("RGBA", size, (30, 32, 34, 255))
    canvas = scene.render(canvas)
    # The glass: a cool sheen, two soft reflections, and the round speaking grille.
    x0, y0 = camera.project((-0.42, 1.74, 0.42))[:2]
    x1, y1 = camera.project((0.42, 0.96, 0.42))[:2]
    glass = Image.new("RGBA", size, (0, 0, 0, 0))
    g = ImageDraw.Draw(glass)
    g.rectangle((x0, y0, x1, y1), fill=(170, 200, 210, 34))
    g.polygon([(x0 + (x1 - x0) * 0.08, y0), (x0 + (x1 - x0) * 0.22, y0), (x0 + (x1 - x0) * 0.02, y1), (x0, y1), (x0, y0 + (y1 - y0) * 0.5)], fill=(255, 255, 255, 30))
    g.polygon([(x0 + (x1 - x0) * 0.7, y0), (x0 + (x1 - x0) * 0.76, y0), (x0 + (x1 - x0) * 0.5, y1), (x0 + (x1 - x0) * 0.44, y1)], fill=(255, 255, 255, 22))
    glass = glass.filter(ImageFilter.GaussianBlur(w / 300))
    canvas.alpha_composite(glass)
    cx, cy = camera.project((0.0, 1.06, 0.41))[:2]
    r = (x1 - x0) * 0.075
    grille = ImageDraw.Draw(canvas)
    grille.ellipse((cx - r * 1.12, cy - r * 1.12, cx + r * 1.12, cy + r * 1.12), fill=(96, 100, 104, 255))
    grille.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(150, 156, 160, 255))
    step = r / 4
    for gx in np.arange(-r, r + 1, step):
        for gy in np.arange(-r, r + 1, step):
            if gx * gx + gy * gy < (r * 0.86) ** 2:
                grille.ellipse((cx + gx - step * 0.22, cy + gy - step * 0.22, cx + gx + step * 0.22, cy + gy + step * 0.22), fill=(40, 42, 46, 255))
    return finish(canvas)


# ---------------------------------------------------------------- the jeepney


def city_streaks(w: int, h: int, seed: int) -> Image.Image:
    """What a moving jeepney's open window shows at night: dark shapes and the lights of shops,
    signs and cars stretched sideways by the speed."""
    rng = np.random.default_rng(seed)
    city = Image.new("RGBA", (w, h), (14, 16, 26, 255))
    d = ImageDraw.Draw(city)
    colors = [(255, 190, 110), (255, 120, 90), (120, 200, 255), (255, 230, 170), (200, 120, 255), (120, 255, 170)]
    for _ in range(70):
        y = rng.random() * h
        x = rng.random() * w
        length = 40 + rng.random() * 220
        thick = 2 + rng.random() * 8
        c = colors[rng.integers(len(colors))]
        d.rounded_rectangle((x, y, x + length, y + thick), radius=thick / 2, fill=c + (int(120 + rng.random() * 120),))
    return city.filter(ImageFilter.GaussianBlur(3))


def painted_ceiling(w: int, h: int) -> Image.Image:
    """A jeepney's ceiling: a bright painted panel with stripes and stars, like the outside."""
    img = Image.new("RGBA", (w, h), (196, 40, 46, 255))
    d = ImageDraw.Draw(img)
    for i, c in enumerate([(240, 200, 60), (40, 120, 200), (240, 240, 230)]):
        d.rectangle((0, h * (0.2 + i * 0.08), w, h * (0.24 + i * 0.08)), fill=c + (255,))
        d.rectangle((0, h * (0.76 - i * 0.08), w, h * (0.8 - i * 0.08)), fill=c + (255,))
    for x in range(40, w, 120):
        d.regular_polygon((x, h * 0.5, 18), 5, fill=(250, 220, 90, 255))
    return img


def padala_jeep(size, mercy: Image.Image) -> Image.Image:
    w, h = size
    camera = s3.Camera((0.0, 1.0, -0.3), 0.0, -4.0, 56.0, size)
    scene = s3.Scene(camera, ambient=(52, 56, 76), sky_dir=(0.0, 1.0, 0.0))
    red, chrome, floor = (150, 30, 34), (190, 196, 204), (60, 56, 52)
    length = 4.2
    scene.face([(-0.8, 0.0, length), (0.8, 0.0, length), (0.8, 0.0, 0.0), (-0.8, 0.0, 0.0)], floor, layer=0)
    ceiling = Image.eval(painted_ceiling(400, 1400).convert("RGB"), lambda v: int(v * 0.55)).convert("RGBA")
    scene.face([(-0.8, 1.42, 0.0), (0.8, 1.42, 0.0), (0.8, 1.42, length), (-0.8, 1.42, length)], (108, 22, 25),
               texture=ceiling, layer=0, two_sided=True)
    for side in (-1, 1):
        x_wall, x_seat = 0.8 * side, 0.36 * side
        # The benches: a seat and the padded back along the wall.
        scene.box(min(x_wall, x_seat), max(x_wall, x_seat), 0.0, 0.44, 0.2, length - 0.4, red, layer=1)
        scene.face([(x_wall, 0.82, 0.2), (x_wall, 0.82, length - 0.4), (x_wall, 0.44, length - 0.4), (x_wall, 0.44, 0.2)][:: -side], red, layer=1)
        # The open windows along each side, and the pillars between them.
        city = city_streaks(1600, 300, 7 + side)
        scene.face([(x_wall, 1.24, 0.1), (x_wall, 1.24, length), (x_wall, 0.84, length), (x_wall, 0.84, 0.1)][:: -side], (20, 22, 30),
                   texture=city, layer=0, emissive=True)
        for z in np.arange(0.5, length, 0.8):
            scene.box(x_wall - 0.03, x_wall + 0.03, 0.82, 1.42, z, z + 0.06, (230, 230, 220), layer=2)
        # The chrome handrail along the ceiling.
        scene.box(0.3 * side - 0.015, 0.3 * side + 0.015, 1.3, 1.33, 0.1, length, chrome, layer=2)
    # The front: the driver's back as a dark shape, and the road through the windshield.
    road = city_streaks(800, 400, 11)
    rd = ImageDraw.Draw(road)
    rd.polygon([(320, 400), (480, 400), (420, 200), (380, 200)], fill=(40, 40, 46, 255))
    scene.face([(-0.8, 1.42, length), (0.8, 1.42, length), (0.8, 0.84, length), (-0.8, 0.84, length)], (20, 22, 30),
               texture=road, layer=0, emissive=True)
    scene.face([(-0.8, 0.84, length), (0.8, 0.84, length), (0.8, 0.0, length), (-0.8, 0.0, length)], (40, 36, 34), layer=0)
    driver = Image.open(str(__import__("pathlib").Path(SERIF).parent.parent / "portraits" / "kulas_1.png")).convert("RGBA")
    driver = driver.crop((0, 0, driver.width, int(driver.height * 0.5)))
    shape = Image.new("RGBA", driver.size, (12, 10, 14, 255))
    shape.putalpha(driver.getchannel("A"))
    dh = 0.85
    dw = dh * shape.width / shape.height / 2
    scene.face([(-0.45 - dw, 0.5 + dh, length - 0.32), (-0.45 + dw, 0.5 + dh, length - 0.32), (-0.45 + dw, 0.5, length - 0.32), (-0.45 - dw, 0.5, length - 0.32)],
               (12, 10, 14), texture=shape, layer=2, emissive=True)
    # A small tube light over the aisle, cold, and the warm spill of the street.
    scene.box(-0.25, 0.25, 1.39, 1.41, 1.8, 1.86, (220, 240, 255), layer=2, emissive=True)
    scene.light((0.0, 1.3, 1.8), (200, 225, 255), 2.2)
    scene.light((0.9, 1.0, 2.0), (255, 170, 110), 1.2)
    scene.light((-0.9, 1.0, 1.0), (140, 160, 255), 1.0)
    # Mercy, seated on the right bench, her lower half hidden by the bench in front of her.
    upper = mercy.crop((0, 0, mercy.width, int(mercy.height * 0.6)))
    # Her lap fades into the shadow of the seat, so she sits rather than ends.
    fade = np.asarray(upper.getchannel("A")).astype(np.float32)
    rows = fade.shape[0]
    fade *= np.clip((rows - np.arange(rows)) / (rows * 0.18), 0, 1)[:, None]
    upper.putalpha(Image.fromarray(fade.astype(np.uint8)))
    tall = 1.62 * 0.6
    half = tall * upper.width / upper.height / 2
    seat_top, z = 0.36, 1.45
    scene.face([(0.5 - half, seat_top + tall, z), (0.5 + half, seat_top + tall, z), (0.5 + half, seat_top, z), (0.5 - half, seat_top, z)],
               (200, 200, 200), texture=upper, layer=3)
    canvas = Image.new("RGBA", size, (10, 10, 14, 255))
    canvas = scene.render(canvas)
    return finish(canvas)


# ---------------------------------------------------------------- the news on television


def news_frame(w: int, h: int) -> Image.Image:
    """The broadcast: the street under police lights (from street_scene), a red bar with the
    headline, and a small LIVE tag."""
    import street_scene
    street = street_scene.draw((w * 2, h * 2), car_at=(1.6, 0.0, 12.0), car_yaw=-20.0).resize((w, h), Image.LANCZOS)
    d = ImageDraw.Draw(street)
    bar = int(h * 0.16)
    d.rectangle((0, h - bar - int(h * 0.06), w, h - int(h * 0.06)), fill=(176, 22, 30, 255))
    d.rectangle((0, h - int(h * 0.06), w, h), fill=(16, 18, 40, 255))
    font = ImageFont.truetype(FONT_BLACK, int(bar * 0.5))
    d.text((int(w * 0.04), h - bar - int(h * 0.06) + int(bar * 0.22)), "OPERASYON: 3 PATAY", font=font, fill=(255, 255, 255, 255))
    small = ImageFont.truetype(FONT_BLACK, int(h * 0.05))
    d.rectangle((int(w * 0.04), int(h * 0.05), int(w * 0.17), int(h * 0.12)), fill=(200, 20, 30, 255))
    d.text((int(w * 0.055), int(h * 0.055)), "LIVE", font=small, fill=(255, 255, 255, 255))
    # Scan lines, like an old set.
    lines = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    for y in range(0, h, 3):
        ld.line((0, y, w, y), fill=(0, 0, 0, 46))
    street.alpha_composite(lines)
    return street


def tokhang_tv_news(size) -> Image.Image:
    w, h = size
    camera = s3.Camera((0.0, 1.05, -0.2), 0.0, -6.0, 42.0, size)
    scene = s3.Scene(camera, ambient=(26, 28, 40), sky_dir=(0.0, 1.0, 0.0))
    screen_light = (150, 170, 255)
    # The room: a wall, the floor, a low cabinet with the television on it.
    wall = noise(900, 500, 60, 21)
    wall_img = Image.fromarray(np.stack([120 + wall * 20, 150 + wall * 20, 132 + wall * 20], axis=-1).astype(np.uint8)).convert("RGBA")
    scene.face([(-2.0, 2.6, 2.4), (2.0, 2.6, 2.4), (2.0, 0.0, 2.4), (-2.0, 0.0, 2.4)], (120, 150, 132), texture=wall_img, layer=0)
    scene.face([(-2.0, 0.0, 2.4), (2.0, 0.0, 2.4), (2.0, 0.0, -0.4), (-2.0, 0.0, -0.4)], (90, 80, 72), layer=0)
    scene.box(-0.75, 0.75, 0.0, 0.62, 1.9, 2.35, (92, 60, 40), layer=1)
    # An old set: a deep body, a bevel, and the glowing screen.
    scene.box(-0.42, 0.42, 0.62, 1.22, 1.95, 2.3, (40, 40, 44), layer=2)
    scene.face([(-0.34, 1.16, 1.948), (0.34, 1.16, 1.948), (0.34, 0.68, 1.948), (-0.34, 0.68, 1.948)], (200, 200, 220),
               texture=news_frame(640, 452), layer=3, emissive=True)
    scene.box(-0.3, 0.3, 1.22, 1.24, 2.05, 2.25, (30, 30, 32), layer=2)
    scene.light((0.0, 0.92, 1.6), screen_light, 1.6)
    scene.light((0.0, 0.92, 1.7), (255, 80, 90), 0.5)
    canvas = Image.new("RGBA", size, (8, 8, 12, 255))
    canvas = scene.render(canvas)
    centre = camera.project((0.0, 0.92, 1.95))[:2]
    canvas = s3.add_glow(canvas, centre, screen_light, w / 4, 0.25)
    return finish(canvas)


# ---------------------------------------------------------------- the confessional


def lattice(w: int, h: int, hole: int, bar: int, color=(84, 52, 30)) -> Image.Image:
    """A confessional's wooden screen: diagonal bars with diamond holes you can see through."""
    screen = Image.new("RGBA", (w, h), color + (255,))
    holes = Image.new("L", (w, h), 255)
    d = ImageDraw.Draw(holes)
    step = hole + bar
    for cy in range(-step, h + step, step):
        for cx in range(-step, w + step, step):
            for ox, oy in ((0, 0), (step // 2, step // 2)):
                x, y = cx + ox, cy + oy
                d.polygon([(x, y - hole / 2), (x + hole / 2, y), (x, y + hole / 2), (x - hole / 2, y)], fill=0)
    screen.putalpha(holes)
    # The bars are rounded wood: lighter along their middles.
    shade = noise(w, h, 30, 41)
    rgb = np.asarray(screen).astype(np.float32)
    rgb[..., :3] *= (0.85 + 0.3 * shade)[..., None]
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGBA")


def prologue_booth(size, figure: Image.Image) -> Image.Image:
    w, h = size
    camera = s3.Camera((0.0, 1.1, -0.45), 0.0, 0.0, 50.0, size)
    scene = s3.Scene(camera, ambient=(34, 29, 26), sky_dir=(0.0, 1.0, 0.0))
    panel = wood(600, 900, 51, base=(84, 52, 32))
    # The priest's side: wooden walls close on either hand, and the wall with the screen ahead.
    for x in (-0.5, 0.5):
        scene.face([(x, 2.2, -0.6), (x, 2.2, 0.32), (x, 0.0, 0.32), (x, 0.0, -0.6)][:: (-1 if x > 0 else 1)], (84, 52, 32), texture=panel, layer=1, two_sided=True)
    for y0, y1 in ((0.0, 0.86), (1.46, 2.2)):
        scene.face([(-0.5, y1, 0.32), (0.5, y1, 0.32), (0.5, y0, 0.32), (-0.5, y0, 0.32)], (84, 52, 32), texture=panel, layer=1)
    for x0, x1 in ((-0.5, -0.24), (0.24, 0.5)):
        scene.face([(x0, 1.46, 0.32), (x1, 1.46, 0.32), (x1, 0.86, 0.32), (x0, 0.86, 0.32)], (84, 52, 32), texture=panel, layer=1)
    # The screen itself, a frame around it, and a small shelf below.
    scene.face([(-0.24, 1.46, 0.315), (0.24, 1.46, 0.315), (0.24, 0.86, 0.315), (-0.24, 0.86, 0.315)], (84, 52, 32),
               texture=lattice(480, 600, 26, 9), layer=2)
    for x0, x1, y0, y1 in ((-0.27, -0.24, 0.83, 1.49), (0.24, 0.27, 0.83, 1.49), (-0.27, 0.27, 1.46, 1.49), (-0.27, 0.27, 0.83, 0.86)):
        scene.face([(x0, y1, 0.31), (x1, y1, 0.31), (x1, y0, 0.31), (x0, y0, 0.31)], (104, 68, 40), layer=3)
    scene.box(-0.3, 0.3, 0.8, 0.83, 0.18, 0.32, (104, 68, 40), layer=3)
    # Beyond the screen: the penitent's side, lit by a candle, and someone kneeling close.
    scene.face([(-0.8, 2.2, 1.4), (0.8, 2.2, 1.4), (0.8, 0.0, 1.4), (-0.8, 0.0, 1.4)], (90, 60, 40), texture=wood(400, 500, 52, base=(90, 60, 40)), layer=0)
    shape = Image.new("RGBA", figure.size, (8, 6, 6, 255))
    shape.putalpha(figure.getchannel("A").filter(ImageFilter.GaussianBlur(3)))
    tall = 1.75
    half = tall * shape.width / shape.height / 2
    # Kneeling close to the screen: only the head and shoulders rise into the window.
    low = -0.58
    scene.face([(-0.02 - half, low + tall, 0.6), (-0.02 + half, low + tall, 0.6), (-0.02 + half, low, 0.6), (-0.02 - half, low, 0.6)],
               (8, 6, 6), texture=shape, layer=0, emissive=True)
    scene.light((0.35, 1.0, 1.1), (255, 170, 90), 1.2)
    scene.light((0.0, 1.15, 0.0), (255, 170, 90), 0.25)
    canvas = Image.new("RGBA", size, (6, 5, 5, 255))
    canvas = scene.render(canvas)
    return finish(canvas)


# ---------------------------------------------------------------- the suitcase


def shell_texture(w: int, h: int, seam: float = 0.0) -> Image.Image:
    """A hard suitcase's shell: dark grey plastic with raised ribs and a soft sheen."""
    shell = Image.new("RGBA", (w, h), (58, 60, 66, 255))
    d = ImageDraw.Draw(shell)
    for x in range(int(w * 0.08), w, int(w * 0.14)):
        d.rectangle((x, 0, x + int(w * 0.03), h), fill=(72, 74, 80, 255))
        d.line((x + int(w * 0.03), 0, x + int(w * 0.03), h), fill=(40, 42, 46, 255), width=3)
    if seam:
        # Where the two shells meet: a dark zip with a light edge above it.
        y = int(h * seam)
        d.rectangle((0, y - 3, w, y + 5), fill=(26, 26, 30, 255))
        d.line((0, y - 4, w, y - 4), fill=(110, 112, 118, 255), width=2)
    return shell.filter(ImageFilter.GaussianBlur(1.2))


def lining_texture(w: int, h: int) -> Image.Image:
    """The inside: grey-blue cloth crushed into folds, with two crossed straps."""
    folds = noise(w, h, 60, 61) * 0.6 + noise(w, h, 18, 62) * 0.4
    rgb = np.stack([70 + folds * 50, 78 + folds * 52, 96 + folds * 56], axis=-1)
    lining = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(lining)
    strap = int(min(w, h) * 0.05)
    d.line((0, 0, w, h), fill=(40, 42, 50, 255), width=strap)
    d.line((0, h, w, 0), fill=(40, 42, 50, 255), width=strap)
    d.rectangle((w * 0.47, h * 0.45, w * 0.53, h * 0.55), fill=(150, 150, 156, 255))
    return lining


def floor_tiles(w: int, h: int) -> Image.Image:
    base = noise(w, h, 30, 71)
    rgb = np.stack([196 + base * 16, 188 + base * 16, 172 + base * 16], axis=-1)
    tiles = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(tiles)
    step = w // 6
    for i in range(0, w + 1, step):
        d.line((i, 0, i, h), fill=(150, 144, 132, 255), width=4)
    for j in range(0, h + 1, step):
        d.line((0, j, w, j), fill=(150, 144, 132, 255), width=4)
    return tiles


def _turn_about_x(point, hinge_y: float, hinge_z: float, degrees: float):
    """A point of the lid, swung open about the hinge along the suitcase's back edge."""
    x, y, z = point
    a = math.radians(degrees)
    dy, dz = y - hinge_y, z - hinge_z
    return (x, hinge_y + dy * math.cos(a) - dz * math.sin(a), hinge_z + dy * math.sin(a) + dz * math.cos(a))


def padala_luggage(size, closed: bool = False) -> Image.Image:
    w, h = size
    camera = s3.Camera((-0.45, 0.95, -0.2), 14.0, -28.0, 46.0, size)
    scene = s3.Scene(camera, ambient=(70, 72, 84) if not closed else (24, 26, 34), sky_dir=(-0.3, 1.0, -0.3))
    scene.face([(-1.6, 0.0, 2.0), (1.6, 0.0, 2.0), (1.6, 0.0, 0.2), (-1.6, 0.0, 0.2)], (196, 188, 172), texture=floor_tiles(900, 600), layer=0)
    scene.face([(-1.6, 1.6, 2.0), (1.6, 1.6, 2.0), (1.6, 0.0, 2.0), (-1.6, 0.0, 2.0)], (150, 176, 160), layer=0)
    scene.face([(-1.6, 0.1, 1.99), (1.6, 0.1, 1.99), (1.6, 0.0, 1.99), (-1.6, 0.0, 1.99)], (110, 96, 84), layer=0)
    x0, x1, z0, z1, top = -0.38, 0.38, 0.95, 1.45, 0.2 if not closed else 0.26
    shell, lining = shell_texture(500, 200, 0.5 if closed else 0.0), lining_texture(600, 400)
    # The shell's outside walls, ribbed.
    scene.face([(x0, top, z0), (x1, top, z0), (x1, 0.0, z0), (x0, 0.0, z0)], (58, 60, 66), texture=shell, layer=1)
    scene.face([(x1, top, z1), (x0, top, z1), (x0, 0.0, z1), (x1, 0.0, z1)], (58, 60, 66), texture=shell, layer=1)
    scene.face([(x0, top, z1), (x0, top, z0), (x0, 0.0, z0), (x0, 0.0, z1)], (58, 60, 66), texture=shell, layer=1)
    scene.face([(x1, top, z0), (x1, top, z1), (x1, 0.0, z1), (x1, 0.0, z0)], (58, 60, 66), texture=shell, layer=1)
    if closed:
        scene.face([(x0, top, z1), (x1, top, z1), (x1, top, z0), (x0, top, z0)], (58, 60, 66), texture=shell_texture(500, 340), layer=1)
        # The handle and two latches along the front.
        scene.box(-0.12, 0.12, top * 0.66, top * 0.82, z0 - 0.05, z0 - 0.03, (24, 24, 28), layer=2)
        for x in (-0.12, 0.1):
            scene.box(x, x + 0.02, top * 0.62, top * 0.82, z0 - 0.05, z0, (24, 24, 28), layer=2)
        for x in (-0.24, 0.24):
            scene.box(x - 0.025, x + 0.025, top * 0.62, top * 0.8, z0 - 0.015, z0 - 0.002, (170, 170, 176), layer=2)
        scene.light((-1.2, 0.3, 1.2), (180, 200, 255), 0.9)
    else:
        # Inside: the crushed lining, the inner walls, and the lid standing open behind it.
        inset = 0.02
        scene.face([(x0 + inset, 0.03, z1 - inset), (x1 - inset, 0.03, z1 - inset), (x1 - inset, 0.03, z0 + inset), (x0 + inset, 0.03, z0 + inset)],
                   (80, 88, 106), texture=lining, layer=2)
        for points in ([(x0 + inset, top, z1 - inset), (x1 - inset, top, z1 - inset), (x1 - inset, 0.03, z1 - inset), (x0 + inset, 0.03, z1 - inset)],
                       [(x1 - inset, top, z0 + inset), (x1 - inset, top, z1 - inset), (x1 - inset, 0.03, z1 - inset), (x1 - inset, 0.03, z0 + inset)],
                       [(x0 + inset, top, z1 - inset), (x0 + inset, top, z0 + inset), (x0 + inset, 0.03, z0 + inset), (x0 + inset, 0.03, z1 - inset)]):
            scene.face(points, (66, 72, 88), layer=2, two_sided=True)
        lid = [_turn_about_x(p, top, z1, 100.0) for p in [(x0, top, z0), (x1, top, z0), (x1, top, z1), (x0, top, z1)]]
        scene.face([lid[3], lid[2], lid[1], lid[0]][::-1], (80, 88, 106), texture=lining_texture(600, 400), layer=1, two_sided=True)
        scene.light((0.4, 1.6, 0.6), (255, 220, 170), 1.6)
    canvas = Image.new("RGBA", size, (10, 10, 12, 255))
    canvas = scene.render(canvas)
    if closed:
        # One cold strip of light from under the door across the floor and the case.
        strip = Image.new("RGBA", size, (0, 0, 0, 0))
        ImageDraw.Draw(strip).polygon([(0, h * 0.72), (w, h * 0.5), (w, h * 0.56), (0, h * 0.8)], fill=(150, 170, 230, 70))
        canvas = s3.add_light_layer(canvas, strip, w / 80)
    return finish(canvas)

