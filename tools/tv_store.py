"""The news scene of Tokhang: a television shop in daylight, seen from the pavement through its
front window, over the shoulder of a delivery rider who watches the news.

Built in 3D with scene3d.py so it has a true camera angle, perspective and light:
- the rider is in the foreground, close to the camera and a little out of focus, seen from behind and
  cropped at the chest, so the picture is taken over his shoulder (drawn by rider_back.py, not from any
  character art in the game);
- the shop inside is lit by ceiling lights: three shelves, each a row of six identical tube sets
  standing side by side with a clear gap between them, all turned to the drug-war news;
- the glass is drawn as a see-through sheet that holds the sky, the buildings across the street and
  the sun's glare, so the shop looks like it is behind a window;
- a thick wooden utility pole stands at the kerb in front of the glass, pasted with many posters;
- the shops on either side are out of focus (blurred), with overhead wires crossing the street.

Run this file to save the picture next to it as tv_store_preview.png.
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

import rider_back
import scene3d as s3
import street_scene
from street_scene import noise, stained

FONT_BLACK = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
FONT_BOLD = "/usr/share/fonts/opentype/inter/Inter-Bold.otf" if Path("/usr/share/fonts/opentype/inter/Inter-Bold.otf").exists() else FONT_BLACK
SUN = (255, 236, 200)

# The street footage, drawn once.
_footage: Image.Image | None = None


# ---------------------------------------------------------------- what the televisions show


def street_footage(w: int, h: int) -> Image.Image:
    """The reporter's footage: the street under police lights."""
    global _footage
    if _footage is None:
        cache = Path("/tmp/tv_store_footage.png")
        if cache.exists():
            _footage = Image.open(cache).convert("RGB")
        else:
            _footage = street_scene.draw((960, 540), car_at=(1.6, 0.0, 12.0), car_yaw=-20.0).convert("RGB")
            _footage.save(cache)
    return _footage.resize((w, h), Image.LANCZOS).convert("RGBA")


def _text(d: ImageDraw.ImageDraw, xy, words: str, size: int, fill, font_path=FONT_BLACK, anchor="la"):
    d.text(xy, words, font=ImageFont.truetype(font_path, size), fill=fill, anchor=anchor)


def broadcast(w: int, h: int, kind: int) -> Image.Image:
    """One channel's news frame about the drug war. Each `kind` is a different channel look."""
    if kind == 0:
        img = street_footage(w, h)
        d = ImageDraw.Draw(img)
        bar = int(h * 0.2)
        top = h - bar - int(h * 0.07)
        d.rectangle((0, top, w, top + bar), fill=(176, 22, 30, 255))
        d.rectangle((0, top + bar, w, h), fill=(14, 18, 44, 255))
        _text(d, (int(w * 0.04), top + int(bar * 0.08)), "WAR ON DRUGS", int(bar * 0.62), (255, 255, 255, 255))
        _text(d, (int(w * 0.04), top + int(bar * 0.68)), "3 PATAY SA OPERASYON SA SAMPALOC", int(bar * 0.24), (255, 232, 232, 255), FONT_BOLD)
        _text(d, (int(w * 0.04), top + bar + int(h * 0.012)), "NANLABAN DAW ANG MGA SUSPEK  |  PNP", int(h * 0.04), (230, 235, 255, 255), FONT_BOLD)
        d.rectangle((int(w * 0.04), int(h * 0.05), int(w * 0.2), int(h * 0.13)), fill=(200, 20, 30, 255))
        _text(d, (int(w * 0.062), int(h * 0.06)), "LIVE", int(h * 0.06), (255, 255, 255, 255))
    elif kind == 1:
        img = Image.new("RGBA", (w, h), (18, 40, 110, 255))
        d = ImageDraw.Draw(img)
        for i in range(h):
            d.line((0, i, w, i), fill=(14 + i * 20 // h, 36 + i * 40 // h, 100 + i * 60 // h, 255))
        for cx in (0.3, 0.62):
            d.ellipse((int(w * cx) - int(h * 0.08), int(h * 0.2), int(w * cx) + int(h * 0.08), int(h * 0.2) + int(h * 0.19)), fill=(36, 30, 36, 255))
            d.rounded_rectangle((int(w * cx) - int(h * 0.19), int(h * 0.38), int(w * cx) + int(h * 0.19), int(h * 0.7)), int(h * 0.08), fill=(28, 28, 44, 255))
        d.rectangle((0, int(h * 0.62), w, int(h * 0.74)), fill=(70, 80, 120, 255))
        d.rectangle((0, int(h * 0.74), w, int(h * 0.9)), fill=(210, 30, 36, 255))
        _text(d, (int(w * 0.04), int(h * 0.755)), "DIGMAANG KONTRA-DROGA", int(h * 0.1), (255, 255, 255, 255))
        d.rectangle((0, int(h * 0.9), w, h), fill=(240, 240, 250, 255))
        _text(d, (int(w * 0.03), int(h * 0.915)), "PNP, NAGLUNSAD NG BAGONG OPERASYON  *  TATLO ANG NASAWI SA KAMAYNILA", int(h * 0.06), (20, 20, 50, 255), FONT_BOLD)
    elif kind == 2:
        img = Image.new("RGBA", (w, h), (200, 24, 32, 255))
        d = ImageDraw.Draw(img)
        d.rectangle((0, 0, w, int(h * 0.2)), fill=(255, 255, 255, 255))
        _text(d, (int(w * 0.04), int(h * 0.03)), "BREAKING NEWS", int(h * 0.13), (200, 24, 32, 255))
        _text(d, (int(w * 0.05), int(h * 0.3)), "DRUG WAR:", int(h * 0.2), (255, 255, 255, 255))
        _text(d, (int(w * 0.05), int(h * 0.52)), "3 PATAY", int(h * 0.3), (255, 240, 120, 255))
        d.rectangle((0, int(h * 0.88), w, h), fill=(20, 20, 30, 255))
        _text(d, (int(w * 0.04), int(h * 0.9)), "OPLAN TOKHANG  *  SAMPALOC, MAYNILA", int(h * 0.07), (255, 255, 255, 255), FONT_BOLD)
    elif kind == 3:
        img = Image.new("RGBA", (w, h), (12, 16, 26, 255))
        d = ImageDraw.Draw(img)
        for x in range(0, w, int(w / 16)):
            d.line((x, 0, x, h), fill=(26, 40, 60, 255))
        for y in range(0, h, int(h / 9)):
            d.line((0, y, w, y), fill=(26, 40, 60, 255))
        _text(d, (int(w * 0.05), int(h * 0.06)), "BILANG NG PATAY SA DRUG WAR", int(h * 0.075), (255, 255, 255, 255))
        for i, v in enumerate((0.3, 0.45, 0.4, 0.62, 0.78)):
            x0 = int(w * (0.08 + i * 0.17))
            d.rectangle((x0, int(h * (0.88 - v * 0.62)), x0 + int(w * 0.11), int(h * 0.88)), fill=(220, 40, 48, 255) if i == 4 else (70, 130, 255, 255))
        d.line((int(w * 0.06), int(h * 0.88), int(w * 0.94), int(h * 0.88)), fill=(200, 210, 230, 255), width=3)
    else:
        img = Image.new("RGBA", (w, h), (232, 196, 40, 255))
        d = ImageDraw.Draw(img)
        for i in range(-h, w, int(h * 0.22)):
            d.polygon([(i, h), (i + int(h * 0.11), h), (i + int(h * 0.11) + h, 0), (i + h, 0)], fill=(30, 30, 30, 255))
        d.rectangle((0, int(h * 0.3), w, int(h * 0.74)), fill=(14, 14, 18, 255))
        _text(d, (int(w * 0.05), int(h * 0.34)), "NANLABAN DAW", int(h * 0.15), (255, 255, 255, 255))
        _text(d, (int(w * 0.05), int(h * 0.54)), "DRUG WAR: 3 PATAY", int(h * 0.15), (255, 220, 60, 255))
    # Scan lines and a slight glass sheen.
    lines = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    for y in range(0, h, 3):
        ld.line((0, y, w, y), fill=(0, 0, 0, 40))
    img.alpha_composite(lines)
    return ImageEnhance.Brightness(img.convert("RGB")).enhance(1.22).convert("RGBA")


# ---------------------------------------------------------------- placing things


def _turned(points, centre_xz, yaw_deg: float):
    """Points turned about the vertical through `centre_xz`."""
    cx, cz = centre_xz
    a = math.radians(yaw_deg)
    out = []
    for x, y, z in points:
        dx, dz = x - cx, z - cz
        out.append((cx + dx * math.cos(a) + dz * math.sin(a), y, cz - dx * math.sin(a) + dz * math.cos(a)))
    return out


def turned_box(scene, centre_xz, y0, y1, w, d, yaw, color, layer=2, skip=()):
    """A box standing at `centre_xz`, `w` wide and `d` deep, turned by `yaw` degrees."""
    cx, cz = centre_xz
    x0, x1, z0, z1 = cx - w / 2, cx + w / 2, cz - d / 2, cz + d / 2
    sides = {
        "front": [(x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (x0, y0, z0)],
        "back": [(x1, y1, z1), (x0, y1, z1), (x0, y0, z1), (x1, y0, z1)],
        "left": [(x0, y1, z1), (x0, y1, z0), (x0, y0, z0), (x0, y0, z1)],
        "right": [(x1, y1, z0), (x1, y1, z1), (x1, y0, z1), (x1, y0, z0)],
        "top": [(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)],
        "bottom": [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
    }
    for name, points in sides.items():
        if name not in skip:
            scene.face(_turned(points, centre_xz, yaw), color, layer=layer)


def crt_set(scene, cx, y0, cz, frame: Image.Image, bezel=(26, 26, 30), layer=2):
    """A regular tube television, 56 cm wide and 44 cm high with a deep boxy body, standing on a
    shelf at (cx, cz) and facing the street. All the shop's sets are this size. Its screen glows
    with the news, and the body's sides and top catch the light so it reads as a solid."""
    w, h, depth = 0.56, 0.44, 0.46
    turned_box(scene, (cx, cz + depth / 2), y0, y0 + h, w, depth, 0, (52, 52, 58), layer)
    # The bulge of the tube at the back, narrower than the front.
    turned_box(scene, (cx, cz + depth + 0.14), y0 + 0.05, y0 + h - 0.05, w * 0.62, 0.28, 0, (40, 40, 46), layer)
    # The front: a bezel around a screen, and a control strip with two knobs and a speaker grille.
    scene.face([(cx - w / 2, y0 + h, cz - 0.002), (cx + w / 2, y0 + h, cz - 0.002), (cx + w / 2, y0, cz - 0.002), (cx - w / 2, y0, cz - 0.002)],
               bezel, layer=layer + 1)
    sw, sh = w * 0.8, h * 0.76
    sx0, sx1 = cx - w / 2 + w * 0.06, cx - w / 2 + w * 0.06 + sw
    sy1 = y0 + h - h * 0.07
    sy0 = sy1 - sh
    scene.face([(sx0, sy1, cz - 0.004), (sx1, sy1, cz - 0.004), (sx1, sy0, cz - 0.004), (sx0, sy0, cz - 0.004)],
               (30, 30, 34), texture=frame, layer=layer + 2, emissive=True)
    for kx in (0.88, 0.94):
        k0 = cx - w / 2 + w * kx
        scene.face([(k0 - 0.012, y0 + h * 0.72, cz - 0.006), (k0 + 0.012, y0 + h * 0.72, cz - 0.006), (k0 + 0.012, y0 + h * 0.64, cz - 0.006), (k0 - 0.012, y0 + h * 0.64, cz - 0.006)],
                   (150, 150, 156), layer=layer + 3)
    scene.face([(sx0, y0 + h * 0.1, cz - 0.004), (sx0 + sw * 0.6, y0 + h * 0.1, cz - 0.004), (sx0 + sw * 0.6, y0 + h * 0.04, cz - 0.004), (sx0, y0 + h * 0.04, cz - 0.004)],
               (18, 18, 22), layer=layer + 3)
    # A little light spilling from the screen onto the shelf and its neighbours.
    scene.light((cx, y0 + h * 0.5, cz - 0.35), (150, 175, 255), 0.22, reach=1.2)


# ---------------------------------------------------------------- the shop front


def glass_layer(w: int, h: int) -> Image.Image:
    """What the window pane holds: the sky, the buildings across the street, the sun's glare, the
    awning's shadow, a few stickers and a little dirt. Mostly see-through."""
    sky = np.zeros((h, w, 4), np.float32)
    ys = np.linspace(0, 1, h)[:, None]
    sky[..., 0] = 175 + 60 * (1 - ys)
    sky[..., 1] = 205 + 40 * (1 - ys)
    sky[..., 2] = 238 + 14 * (1 - ys)
    sky[..., 3] = (36 + 22 * (1 - ys)) * np.ones((1, w))
    img = Image.fromarray(np.clip(sky, 0, 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    # The buildings opposite, reflected: pale blocks with window grids, and a sagging cable.
    rng = np.random.default_rng(5)
    x = 0
    while x < w:
        bw = int(rng.integers(w // 14, w // 6))
        bh = int(rng.integers(int(h * 0.3), int(h * 0.62)))
        tone = int(rng.integers(205, 240))
        d.rectangle((x, 0, x + bw, bh), fill=(tone, tone - 8, tone - 24, 22))
        for wx in range(x + 12, x + bw - 18, 36):
            for wy in range(14, bh - 12, 40):
                d.rectangle((wx, wy, wx + 20, wy + 24), fill=(60, 90, 120, 14))
        x += bw + int(rng.integers(4, 40))
    d.line([(0, int(h * 0.06)), (int(w * 0.5), int(h * 0.12)), (w, int(h * 0.05))], fill=(40, 40, 50, 90), width=3)
    img = img.filter(ImageFilter.GaussianBlur(6.0))
    # Sun glare: two broad soft diagonal bands.
    glare = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glare)
    for x0, wid, a in ((0.18, 0.09, 120), (0.46, 0.05, 90), (0.78, 0.11, 110)):
        gd.polygon([(int(w * x0), 0), (int(w * (x0 + wid)), 0), (int(w * (x0 + wid - 0.32)), h), (int(w * (x0 - 0.32)), h)], fill=(255, 250, 240, a))
    glare = glare.filter(ImageFilter.GaussianBlur(h * 0.02))
    img.alpha_composite(glare)
    # The awning's shadow along the top, and the pavement's brightness along the bottom.
    shade = np.zeros((h, w, 4), np.float32)
    top = np.clip(1 - ys / 0.22, 0, 1) ** 1.5
    shade[..., 3] = (top * 120) * np.ones((1, w))
    shade[..., :3] = 16
    img.alpha_composite(Image.fromarray(shade.astype(np.uint8), "RGBA"))
    bottom = np.clip((ys - 0.82) / 0.18, 0, 1)
    low = np.zeros((h, w, 4), np.float32)
    low[..., :3] = (190, 190, 180)
    low[..., 3] = (bottom * 70) * np.ones((1, w))
    img.alpha_composite(Image.fromarray(low.astype(np.uint8), "RGBA"))
    # Dirt and finger smears.
    smear = noise(w, h, 40, 8)
    dirt = np.zeros((h, w, 4), np.float32)
    dirt[..., :3] = 235
    dirt[..., 3] = np.clip((smear - 0.55) * 4, 0, 1) * 34
    img.alpha_composite(Image.fromarray(dirt.astype(np.uint8), "RGBA"))
    return img


def sign_texture(w: int, h: int) -> Image.Image:
    img = Image.new("RGBA", (w, h), (24, 52, 120, 255))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w, 10), fill=(235, 235, 240, 255))
    d.rectangle((0, h - 10, w, h), fill=(235, 235, 240, 255))
    _text(d, (int(w * 0.05), int(h * 0.16)), "TV CENTER", int(h * 0.52), (255, 255, 255, 255))
    d.rounded_rectangle((int(w * 0.66), int(h * 0.2), int(w * 0.95), int(h * 0.8)), 16, fill=(250, 200, 40, 255))
    _text(d, (int(w * 0.805), int(h * 0.5)), "SALE!", int(h * 0.4), (170, 20, 24, 255), anchor="mm")
    noise_img = noise(w, h, 30, 2)
    px = np.asarray(img).astype(np.float32)
    px[..., :3] *= (0.94 + noise_img * 0.1)[..., None]
    return Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGBA")


def awning_texture(w: int, h: int) -> Image.Image:
    img = Image.new("RGBA", (w, h), (240, 240, 244, 255))
    d = ImageDraw.Draw(img)
    stripe = w // 22
    for i in range(0, w, stripe * 2):
        d.rectangle((i, 0, i + stripe, h), fill=(180, 30, 40, 255))
    return img


def paving(width_m: float, length_m: float) -> Image.Image:
    """Sunlit pavement slabs: warm grey concrete with joints and weathering."""
    w, h = int(width_m * 90), int(length_m * 90)
    base = noise(w, h, 7, 31) * 0.5 + noise(w, h, 70, 32) * 0.5
    rgb = np.stack([168 + base * 26, 164 + base * 24, 154 + base * 22], axis=-1)
    img = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(img)
    step = 90
    for x in range(0, w, step):
        d.line((x, 0, x, h), fill=(112, 108, 100, 255), width=3)
    for y in range(0, h, step):
        d.line((0, y, w, y), fill=(112, 108, 100, 255), width=3)
    return img


def shutter_texture(w: int, h: int) -> Image.Image:
    """A roll-up steel shutter: ribbed, a little rusty, with a lock plate at the bottom."""
    base = noise(w, h, 40, 61)
    img = Image.fromarray(np.stack([118 + base * 26, 124 + base * 26, 130 + base * 26], axis=-1).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(img)
    for y in range(0, h, 14):
        d.line((0, y, w, y), fill=(70, 74, 80, 255), width=3)
        d.line((0, y + 4, w, y + 4), fill=(170, 176, 182, 255), width=2)
    d.rectangle((0, h - 26, w, h), fill=(78, 82, 88, 255))
    d.rectangle((w // 2 - 20, h - 22, w // 2 + 20, h - 6), fill=(160, 150, 90, 255))
    rust = noise(w, h, 24, 62)
    px = np.asarray(img).astype(np.float32)
    mask = np.clip((rust - 0.6) * 3, 0, 1)[..., None]
    px[..., :3] = px[..., :3] * (1 - mask * 0.4) + np.array([120, 70, 40], np.float32) * mask * 0.4
    return Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGBA")


def tile_floor(w: int, h: int) -> Image.Image:
    img = Image.new("RGBA", (w, h), (214, 214, 206, 255))
    d = ImageDraw.Draw(img)
    step = w // 12
    for i in range(0, w + step, step):
        d.line((i, 0, i, h), fill=(170, 170, 164, 255), width=2)
    for j in range(0, h + step, step):
        d.line((0, j, w, j), fill=(170, 170, 164, 255), width=2)
    return img


def wood_texture(w: int, h: int) -> Image.Image:
    """Weathered wood on a utility pole: long vertical grain, dark cracks, tar stains and the dirt of
    the street near the ground."""
    rng = np.random.default_rng(71)
    grain = noise(w, h // 60 + 2, 6, 72)
    grain = np.asarray(Image.fromarray((grain * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float32) / 255.0
    blot = noise(w, h, 80, 73)
    base = grain * 0.6 + blot * 0.4
    rgb = np.stack([88 + base * 56, 60 + base * 40, 38 + base * 26], axis=-1)
    img = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(img)
    for _ in range(40):
        x = int(rng.integers(0, w))
        y0 = int(rng.integers(0, h))
        d.line((x, y0, x + int(rng.integers(-6, 6)), y0 + int(rng.integers(60, 360))), fill=(34, 22, 14, 255), width=int(rng.integers(1, 4)))
    # Rings of old wire marks and a darker foot.
    px = np.asarray(img).astype(np.float32)
    ys = np.linspace(0, 1, h)[:, None]
    px[..., :3] *= (1 - np.clip((ys - 0.8) / 0.2, 0, 1) * 0.45)[..., None]
    return Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGBA")


def poster_image(w: int, h: int, kind: int, seed: int) -> Image.Image:
    """A flyer or notice stuck on the pole: a coloured sheet with a big word, some small print,
    and torn edges."""
    schemes = [((250, 224, 60), (170, 30, 36)), ((245, 245, 240), (30, 60, 150)), ((70, 130, 220), (255, 255, 255)),
               ((236, 90, 120), (255, 255, 255)), ((120, 190, 110), (24, 56, 30)), ((250, 160, 60), (60, 20, 10)),
               ((240, 230, 200), (60, 30, 20)), ((210, 40, 40), (255, 240, 200))]
    words = ["FOR RENT", "LOAD", "ROOM FOR RENT", "LOST DOG", "PROMO!", "BAWAL MAGTAPON", "FOR SALE", "CASH LOAN", "TUTOR", "SALE"]
    bg, fg = schemes[kind % len(schemes)]
    img = Image.new("RGBA", (w, h), bg + (255,))
    d = ImageDraw.Draw(img)
    word = words[(kind * 3 + seed) % len(words)]
    size = max(int(h * 0.2), 12)
    font = ImageFont.truetype(FONT_BLACK, size)
    while d.textlength(word, font=font) > w * 0.9 and size > 8:
        size -= 2
        font = ImageFont.truetype(FONT_BLACK, size)
    d.text((w // 2, int(h * 0.2)), word, font=font, fill=fg + (255,), anchor="mm")
    rng = np.random.default_rng(seed + kind * 7)
    for line in range(int(rng.integers(4, 8))):
        y = int(h * 0.38) + line * int(h * 0.075)
        d.rectangle((int(w * 0.1), y, int(w * rng.uniform(0.5, 0.9)), y + max(int(h * 0.025), 2)), fill=fg + (200,))
    d.rectangle((int(w * 0.1), int(h * 0.86), int(w * 0.5), int(h * 0.92)), fill=fg + (255,))
    # Torn bottom edge with strips, and tape at the corners.
    for i in range(0, w, max(w // 6, 6)):
        d.rectangle((i, int(h * 0.94), i + max(w // 12, 3), h), fill=(0, 0, 0, 0))
    d.polygon([(0, 0), (int(w * 0.16), 0), (0, int(h * 0.05))], fill=(236, 232, 210, 220))
    d.polygon([(w, 0), (int(w * 0.84), 0), (w, int(h * 0.05))], fill=(236, 232, 210, 220))
    px = np.asarray(img).astype(np.float32)
    px[..., :3] *= (0.9 + noise(w, h, 5, seed) * 0.15)[..., None]
    return Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGBA")


def utility_pole(scene, cx, cz, radius=0.3, height=7.0, facets=20):
    """A thick wooden pole as a many-sided prism, its facing side covered in posters pasted over one
    another. Posters are cut across the facets so they wrap round the trunk."""
    wood = wood_texture(facets * 64, 1500)
    camera = scene.camera.position
    step = 2 * math.pi / facets
    visible = []
    for i in range(facets):
        a_centre = (i + 0.5) * step - math.pi
        if math.cos(a_centre) > 0.05:
            visible.append(i)
        a0, a1 = i * step - math.pi, (i + 1) * step - math.pi
        p0 = (cx + radius * math.sin(a0), cz - radius * math.cos(a0))
        p1 = (cx + radius * math.sin(a1), cz - radius * math.cos(a1))
        scene.face([(p0[0], height, p0[1]), (p1[0], height, p1[1]), (p1[0], 0.0, p1[1]), (p0[0], 0.0, p0[1])], (120, 84, 56),
                   texture=wood.crop((i * 64, 0, (i + 1) * 64, 1500)), layer=6)
    rng = np.random.default_rng(81)
    # (angle of left edge in degrees from the camera-facing line, width in metres, bottom y, height)
    layout = [(-62, 0.30, 0.55, 0.42), (-30, 0.22, 0.7, 0.30), (-8, 0.34, 0.52, 0.46), (22, 0.26, 0.62, 0.34), (44, 0.20, 0.78, 0.28),
              (-48, 0.24, 1.15, 0.34), (-20, 0.30, 1.05, 0.38), (8, 0.22, 1.2, 0.30), (30, 0.28, 1.1, 0.40),
              (-58, 0.20, 1.6, 0.30), (-30, 0.26, 1.55, 0.34), (-4, 0.30, 1.62, 0.42), (24, 0.22, 1.7, 0.30), (40, 0.24, 1.5, 0.32),
              (-40, 0.28, 2.05, 0.38), (-10, 0.24, 2.0, 0.30), (16, 0.30, 2.1, 0.40), (-22, 0.20, 2.5, 0.26), (6, 0.24, 2.45, 0.32)]
    for k, (deg, width, y0, hh) in enumerate(layout):
        tilt = float(rng.uniform(-0.035, 0.035))
        px_w, px_h = int(width * 600), int(hh * 600)
        poster = poster_image(px_w, px_h, k + int(rng.integers(0, 8)), k)
        a_left = math.radians(deg)
        a_right = a_left + width / radius
        for i in range(facets):
            a0, a1 = i * step - math.pi, (i + 1) * step - math.pi
            lo, hi = max(a0, a_left), min(a1, a_right)
            if hi <= lo + 1e-4 or math.cos((a0 + a1) / 2) <= 0.05:
                continue
            u0, u1 = (lo - a_left) / (a_right - a_left), (hi - a_left) / (a_right - a_left)
            piece = poster.crop((int(u0 * px_w), 0, max(int(u1 * px_w), int(u0 * px_w) + 1), px_h))
            r = radius + 0.004 + 0.0012 * k
            q0 = (cx + r * math.sin(lo), cz - r * math.cos(lo))
            q1 = (cx + r * math.sin(hi), cz - r * math.cos(hi))
            scene.face([(q0[0], y0 + hh + tilt * 0, q0[1]), (q1[0], y0 + hh, q1[1]), (q1[0], y0, q1[1]), (q0[0], y0, q0[1])], (230, 230, 230),
                       texture=piece, layer=7)
    # A steel band and a few staples near the top of the posters, and a tar ring.
    for by in (0.4, 2.9):
        for i in visible:
            a0, a1 = i * step - math.pi, (i + 1) * step - math.pi
            r = radius + 0.012
            p0 = (cx + r * math.sin(a0), cz - r * math.cos(a0))
            p1 = (cx + r * math.sin(a1), cz - r * math.cos(a1))
            scene.face([(p0[0], by + 0.035, p0[1]), (p1[0], by + 0.035, p1[1]), (p1[0], by, p1[1]), (p0[0], by, p0[1])], (80, 84, 90), layer=8)


def neighbour_store(scene, x0, x1, front_z, wall_color, sign_text, sign_color, awning_colors, quads):
    """A shop front next door: coloured walls over two floors, a sign, an awning and a dark open
    front with a few bright goods. It is blurred afterwards, so only broad shapes matter. The
    quads it uses are collected so the blur can be limited to them."""
    wall = stained(256, 512, wall_color, int(x0 * 7) % 90 + 3, 0.22)
    def add(points, color, **kw):
        scene.face(points, color, **kw)
        quads.append(points)
    add([(x0, 6.2, front_z), (x1, 6.2, front_z), (x1, 0.0, front_z), (x0, 0.0, front_z)], wall_color, texture=wall, layer=1)
    # Upper floor windows with grilles and an air-conditioner.
    for wx in (x0 + 0.5, x0 + (x1 - x0) / 2 + 0.2):
        add([(wx, 5.2, front_z - 0.01), (wx + 0.9, 5.2, front_z - 0.01), (wx + 0.9, 3.9, front_z - 0.01), (wx, 3.9, front_z - 0.01)], (60, 76, 96), layer=2)
        add([(wx, 4.0, front_z - 0.03), (wx + 0.6, 4.0, front_z - 0.03), (wx + 0.6, 3.7, front_z - 0.03), (wx, 3.7, front_z - 0.03)], (226, 226, 230), layer=2)
    # The ground floor: a wide dark opening with bright shelves inside.
    add([(x0 + 0.25, 2.6, front_z - 0.01), (x1 - 0.25, 2.6, front_z - 0.01), (x1 - 0.25, 0.0, front_z - 0.01), (x0 + 0.25, 0.0, front_z - 0.01)], (150, 118, 84), layer=2, emissive=True)
    rng = np.random.default_rng(int(x0 * 13) % 500)
    for gx in np.arange(x0 + 0.4, x1 - 0.7, 0.45):
        gy = float(rng.uniform(0.5, 2.0))
        col = [(220, 70, 60), (240, 200, 60), (60, 140, 220), (90, 190, 120), (240, 240, 240)][int(rng.integers(0, 5))]
        add([(gx, gy + 0.3, front_z - 0.02), (gx + 0.35, gy + 0.3, front_z - 0.02), (gx + 0.35, gy, front_z - 0.02), (gx, gy, front_z - 0.02)], col, layer=3, emissive=True)
    # Sign band and a striped awning.
    sign = Image.new("RGBA", (800, 140), sign_color + (255,))
    ImageDraw.Draw(sign).text((400, 70), sign_text, font=ImageFont.truetype(FONT_BLACK, 84), fill=(255, 255, 255, 255), anchor="mm")
    add([(x0 + 0.15, 3.35, front_z - 0.02), (x1 - 0.15, 3.35, front_z - 0.02), (x1 - 0.15, 2.7, front_z - 0.02), (x0 + 0.15, 2.7, front_z - 0.02)], sign_color, texture=sign, layer=3)
    stripes = Image.new("RGBA", (400, 100), awning_colors[0] + (255,))
    sd = ImageDraw.Draw(stripes)
    for i in range(0, 400, 80):
        sd.rectangle((i, 0, i + 40, 100), fill=awning_colors[1] + (255,))
    add([(x0 + 0.05, 2.7, front_z - 0.02), (x1 - 0.05, 2.7, front_z - 0.02), (x1 - 0.05, 2.35, front_z - 0.7), (x0 + 0.05, 2.35, front_z - 0.7)], awning_colors[0], texture=stripes, layer=3, two_sided=True)


# ---------------------------------------------------------------- the whole picture


def build(size) -> Image.Image:
    """The picture, seen over the rider's right shoulder."""
    w, h = size
    camera = s3.Camera((-0.7, 1.52, -3.35), 6.0, -2.0, 56.0, size)
    scene = s3.Scene(camera, ambient=(168, 170, 178), sky_dir=(0.15, 1.0, -0.25))
    scene.light((9.0, 11.0, -9.0), SUN, 900.0, reach=22.0)
    quads: list = []

    # The pavement, in slabs small enough to draw well close to the camera.
    slabs = paving(16.0, 3.4)
    px_per_m = slabs.width / 16.0
    for ix in range(10):
        for iz in range(4):
            x0, x1 = -8.0 + ix * 1.6, -8.0 + (ix + 1) * 1.6
            z0, z1 = -3.3 + iz * 0.825, -3.3 + (iz + 1) * 0.825
            crop = slabs.crop((int(ix * 1.6 * px_per_m), int(iz * 0.825 * px_per_m), int((ix + 1) * 1.6 * px_per_m), int((iz + 1) * 0.825 * px_per_m)))
            scene.face([(x0, 0, z1), (x1, 0, z1), (x1, 0, z0), (x0, 0, z0)], (150, 148, 142), texture=crop, layer=0)

    gx0, gx1, gy0, gy1 = -2.1, 2.5, 0.5, 2.62
    # Shops next door, left and right, a little way back from the street line, blurred later.
    neighbour_store(scene, -5.4, gx0 - 0.02, 0.0, (196, 220, 196), "BOTIKA", (30, 120, 70), ((236, 236, 236), (40, 150, 90)), quads)
    neighbour_store(scene, -8.8, -5.42, 0.25, (240, 206, 130), "KAINAN", (200, 90, 30), ((250, 220, 90), (220, 80, 40)), quads)
    neighbour_store(scene, -12.4, -8.82, -0.1, (170, 186, 214), "HARDWARE", (40, 70, 140), ((220, 220, 224), (60, 90, 170)), quads)
    neighbour_store(scene, gx1 + 0.02, 5.9, 0.0, (232, 150, 150), "LOAD", (30, 100, 190), ((240, 240, 244), (210, 50, 70)), quads)
    neighbour_store(scene, 5.92, 9.4, 0.3, (214, 224, 150), "SARI-SARI", (190, 40, 50), ((250, 230, 120), (190, 60, 50)), quads)
    neighbour_store(scene, 9.42, 13.0, -0.12, (186, 160, 200), "GCASH", (30, 90, 220), ((230, 230, 240), (110, 80, 170)), quads)

    # The TV shop: sign band, upper wall, the riser under the window.
    wall = stained(512, 512, (226, 214, 190), 41, 0.2)
    scene.face([(gx0, gy0, 0), (gx1, gy0, 0), (gx1, 0.0, 0), (gx0, 0.0, 0)], (96, 96, 100), layer=1)
    scene.face([(gx0, 3.5, 0), (gx1, 3.5, 0), (gx1, 2.62, 0), (gx0, 2.62, 0)], (24, 52, 120), texture=sign_texture(1400, 230), layer=1)
    scene.face([(gx0, 6.2, 0), (gx1, 6.2, 0), (gx1, 3.5, 0), (gx0, 3.5, 0)], (226, 214, 190), texture=wall, layer=1)
    scene.face([(gx0 - 0.1, 2.66, -0.04), (gx1 + 0.1, 2.66, -0.04), (gx1 + 0.1, 2.38, -1.0), (gx0 - 0.1, 2.38, -1.0)], (230, 230, 232),
               texture=awning_texture(900, 260), layer=3, two_sided=True)
    scene.face([(gx0 - 0.1, 2.38, -1.0), (gx1 + 0.1, 2.38, -1.0), (gx1 + 0.1, 2.28, -1.0), (gx0 - 0.1, 2.28, -1.0)], (170, 28, 38), layer=3)

    # ---- inside the shop
    scene.face([(gx0, 0.0, 5.0), (gx1, 0.0, 5.0), (gx1, 0.0, 0.05), (gx0, 0.0, 0.05)], (130, 128, 124), texture=tile_floor(720, 720), layer=0)
    scene.face([(gx0, 3.0, 5.0), (gx1, 3.0, 5.0), (gx1, 0.0, 5.0), (gx0, 0.0, 5.0)], (96, 98, 108), layer=0)
    scene.face([(gx0, 3.0, 0.05), (gx0, 3.0, 5.0), (gx0, 0.0, 5.0), (gx0, 0.0, 0.05)], (84, 84, 94), layer=0, two_sided=True)
    scene.face([(gx1, 3.0, 5.0), (gx1, 3.0, 0.05), (gx1, 0.0, 0.05), (gx1, 0.0, 5.0)], (84, 84, 94), layer=0, two_sided=True)
    scene.face([(gx0, 3.0, 0.05), (gx1, 3.0, 0.05), (gx1, 3.0, 5.0), (gx0, 3.0, 5.0)], (110, 110, 118), layer=0, two_sided=True)
    for lx in (-1.4, 0.6, 2.4):
        for lz in (1.2, 3.2):
            scene.face([(lx - 0.5, 2.99, lz + 0.12), (lx + 0.5, 2.99, lz + 0.12), (lx + 0.5, 2.99, lz - 0.12), (lx - 0.5, 2.99, lz - 0.12)], (255, 255, 250), layer=1, emissive=True, two_sided=True)
            scene.light((lx, 2.7, lz), (255, 244, 220), 1.5, reach=4.2)
    # Three shelves, each a row of six identical tube sets side by side with a clear gap between.
    plank = (118, 92, 66)
    shelf_tops = (0.42, 1.04, 1.66)
    for top in shelf_tops:
        scene.box(-2.0, 2.4, top - 0.03, top, 0.5, 1.3, plank, layer=1)
    for ux in (-2.0, 2.4):
        scene.box(ux - 0.02, ux + 0.02, 0.0, 2.15, 0.5, 1.3, (70, 72, 82), layer=1)
    scene.box(-2.0, 2.4, 0.0, 0.39, 0.55, 1.25, (44, 46, 54), layer=1)
    pitch = 4.4 / 6
    bezels = [(26, 26, 30), (176, 178, 184)]
    frame_no = 0
    for row, top in enumerate(shelf_tops):
        for col in range(6):
            cx = -2.0 + pitch * (col + 0.5)
            crt_set(scene, cx, top, 0.6, broadcast(640, 360, frame_no % 5), bezel=bezels[(row + col) % 2])
            frame_no += 1 + (row == 1)

    # ---- the window: aluminium frames between the sets, then the glass sheet
    frame_c = (176, 180, 188)
    for fx in (gx0, -2.0 + pitch * 2 - 0.05, -2.0 + pitch * 4 - 0.14, gx1):
        scene.box(fx - 0.035, fx + 0.035, gy0, gy1, -0.06, 0.03, frame_c, layer=4)
    scene.box(gx0, gx1, gy1 - 0.03, gy1 + 0.03, -0.06, 0.03, frame_c, layer=4)
    scene.box(gx0, gx1, gy0 - 0.03, gy0 + 0.03, -0.06, 0.03, frame_c, layer=4)
    scene.face([(gx0, gy1, -0.01), (gx1, gy1, -0.01), (gx1, gy0, -0.01), (gx0, gy0, -0.01)], (255, 255, 255),
               texture=glass_layer(1600, 640), layer=5, emissive=True)
    notice = Image.new("RGBA", (200, 280), (250, 245, 220, 255))
    nd = ImageDraw.Draw(notice)
    _text(nd, (100, 56), "0%", 80, (190, 24, 30, 255), anchor="mm")
    _text(nd, (100, 130), "INSTALLMENT", 26, (30, 30, 40, 255), FONT_BOLD, "mm")
    _text(nd, (100, 190), "UP TO", 22, (30, 30, 40, 255), FONT_BOLD, "mm")
    _text(nd, (100, 228), "12 MOS.", 34, (190, 24, 30, 255), FONT_BLACK, "mm")
    scene.face([(0.72, 2.4, -0.015), (1.1, 2.4, -0.015), (1.1, 1.72, -0.015), (0.72, 1.72, -0.015)], (250, 245, 220), texture=notice, layer=5, emissive=True)

    # ---- the wooden pole at the kerb in front of the shop's right end, with its shadow
    pole_x, pole_z = -1.3, -0.8
    utility_pole(scene, pole_x, pole_z)
    pole_shadow = Image.new("RGBA", (60, 400), (0, 0, 0, 0))
    ImageDraw.Draw(pole_shadow).rectangle((10, 0, 50, 400), fill=(8, 8, 14, 150))
    pole_shadow = pole_shadow.filter(ImageFilter.GaussianBlur(3))
    scene.face([(pole_x - 1.4 - 0.3, 0.003, pole_z + 0.8), (pole_x - 1.4 + 0.3, 0.003, pole_z + 0.8), (pole_x + 0.3, 0.003, pole_z), (pole_x - 0.3, 0.003, pole_z)],
               (0, 0, 0), texture=pole_shadow, layer=1)

    # ---- the rider's shadow, thrown towards the shop, away from the sun
    rider_x, rider_z = -1.28, -2.3
    shadow = Image.new("RGBA", (160, 520), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse((58, 460, 102, 510), fill=(8, 8, 14, 190))
    sd.rounded_rectangle((26, 120, 134, 390), 24, fill=(8, 8, 14, 190))
    sd.rectangle((44, 380, 116, 520), fill=(8, 8, 14, 190))
    sd.rectangle((70, 380, 90, 520), fill=(0, 0, 0, 0))
    shadow = shadow.filter(ImageFilter.GaussianBlur(5)).transpose(Image.FLIP_TOP_BOTTOM)
    far, near = -0.06, rider_z
    drift = -1.1
    scene.face([(rider_x - 0.34 + drift, 0.003, far), (rider_x + 0.34 + drift, 0.003, far), (rider_x + 0.2, 0.003, near), (rider_x - 0.2, 0.003, near)],
               (0, 0, 0), texture=shadow, layer=1)

    canvas = Image.new("RGBA", size, (176, 206, 238, 255))
    canvas = scene.render(canvas)

    # ---- depth of field: the shops next door are out of focus
    soft = canvas.filter(ImageFilter.GaussianBlur(w / 190))
    mask = Image.new("L", size, 0)
    md = ImageDraw.Draw(mask)
    for quad in quads:
        pts = [camera.project(p)[:2] for p in quad]
        if all(camera.project(p)[2] > 0.2 for p in quad):
            md.polygon(pts, fill=255)
    # Not over the TV shop itself, the pole or the pavement.
    for part in ((gx0, 0.0, gx1, 6.2),):
        corners = [camera.project(p)[:2] for p in ((part[0], part[3], 0.0), (part[2], part[3], 0.0), (part[2], part[1], 0.0), (part[0], part[1], 0.0))]
        md.polygon(corners, fill=0)
    mask = mask.filter(ImageFilter.GaussianBlur(w / 220))
    canvas = Image.composite(soft, canvas, mask)

    # ---- two overhead wires from the pole, sagging, over the street
    wires = Image.new("RGBA", size, (0, 0, 0, 0))
    wd = ImageDraw.Draw(wires)
    top = camera.project((pole_x, 3.2, pole_z))[:2]
    for ex, ey, sag in ((-0.1 * w, 0.2 * h, 0.12 * h), (1.1 * w, 0.16 * h, 0.1 * h), (-0.1 * w, 0.12 * h, 0.14 * h)):
        pts = []
        for i in range(41):
            t = i / 40
            pts.append((top[0] + (ex - top[0]) * t, top[1] + (ey - top[1]) * t + math.sin(t * math.pi) * sag))
        wd.line(pts, fill=(18, 18, 22, 235), width=max(int(w / 420), 2), joint="curve")
    canvas.alpha_composite(wires.filter(ImageFilter.GaussianBlur(0.9)))

    # ---- the rider, seen from behind and a little to the right, close to the camera: only his
    # helmet, shoulders and the top of his bag are in the picture. He is a touch out of focus.
    rider = rider_back.rider_back()
    foot = camera.project((rider_x, 0.0, rider_z))
    scale = camera.pixels_for(1.75, foot[2]) / rider.height
    sprite = rider.resize((int(rider.width * scale), int(rider.height * scale)), Image.LANCZOS)
    px = np.asarray(sprite).astype(np.float32)
    ramp = np.linspace(0.0, 1.0, sprite.width)[None, :]
    px[..., :3] *= (0.94 + 0.12 * ramp)[..., None]   # a little more sun on the side nearest the street
    px[..., 2] += (1 - ramp) * 10                      # a cool bounce from the shop on the other side
    sprite = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGBA")
    alpha = sprite.getchannel("A")
    sprite = sprite.filter(ImageFilter.GaussianBlur(w / 900))
    sprite.putalpha(alpha.filter(ImageFilter.GaussianBlur(w / 1100)))
    canvas.alpha_composite(sprite, (int(foot[0] - sprite.width / 2), int(foot[1] - sprite.height)))
    return canvas


def finish_day(canvas: Image.Image) -> Image.Image:
    """Makes the clean drawing look filmed in sunlight: bright lights bloom a little, edges soften,
    the corners fall off gently and a fine grain sits over it all."""
    w, h = canvas.size
    pixels = np.asarray(canvas.convert("RGB")).astype(np.float32)
    bright = np.clip(pixels - 190, 0, 255)
    bloom = np.asarray(Image.fromarray(bright.astype(np.uint8)).filter(ImageFilter.GaussianBlur(w / 90))).astype(np.float32)
    pixels += bloom * 0.8
    image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    pixels = np.asarray(image).astype(np.float32)
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)) / 1.414
    pixels *= (1 - np.clip((edge - 0.45) / 0.55, 0, 1) ** 1.6 * 0.35)[..., None]
    pixels += np.random.default_rng(3).normal(0, 3.2, (h, w))[..., None]
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).convert("RGBA")


def draw(size) -> Image.Image:
    return finish_day(build(size))


if __name__ == "__main__":
    import sys
    size = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (1672, 941)
    picture = draw(size).convert("RGB")
    out = sys.argv[1] if len(sys.argv) > 1 else "tv_store_preview.png"
    picture.save(out)
    print("saved", out)
