"""The news scene of Tokhang: a television shop in daylight, seen from the pavement through its
front window, over the shoulder of a delivery rider who watches the news.

Built in 3D with scene3d.py so it has a true camera angle, perspective and light:
- the rider stands near the glass in the foreground, seen from behind, so the picture is taken over his
  shoulder (drawn by rider_back.py, not from any
  character art in the game);
- the shop inside is lit by ceiling lights: three shelves, each a row of five identical tube sets
  standing side by side with a clear gap between them, all turned to the drug-war news;
- the glass is drawn as a see-through sheet that holds the sky, the buildings across the street and
  the sun's glare, so the shop looks like it is behind a window;
- a thick wooden utility pole stands at the kerb in front of the glass, pasted with many posters;
- the shops on either side are in focus, with overhead wires crossing the street;
- a double glass door leads into the shop.

Run this file to save the picture next to it as tv_store_preview.png.
"""

import math
from pathlib import Path

import numpy as np
from scipy.ndimage import gaussian_filter
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


def crt_set(scene, cx, y0, cz, frame: Image.Image, bezel=(26, 26, 30), layer=2, k=1.0):
    """A regular tube television, 50 cm wide and 40 cm high with a deep boxy body, standing on a
    shelf at (cx, cz) and facing the street. All the shop's sets are this size. Its screen glows
    with the news, and the body's sides and top catch the light so it reads as a solid."""
    w, h, depth = 0.50 * k, 0.40 * k, 0.42 * k
    turned_box(scene, (cx, cz + depth / 2), y0, y0 + h, w, depth, 0, (52, 52, 58), layer)
    # The bulge of the tube at the back, narrower than the front.
    turned_box(scene, (cx, cz + depth + 0.14 * k), y0 + 0.05 * k, y0 + h - 0.05 * k, w * 0.62, 0.28 * k, 0, (40, 40, 46), layer)
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
    # Let the shop show through more clearly.
    img.putalpha(img.getchannel("A").point(lambda v: int(v * 0.72)))
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


def _fit(d: ImageDraw.ImageDraw, xy, words: str, width: float, size: int, fill, font_path=FONT_BLACK, anchor="mm") -> None:
    """Draws `words` as large as `size` allows without going wider than `width` pixels."""
    size = max(size, 8)
    font = ImageFont.truetype(font_path, size)
    while d.textlength(words, font=font) > width and size > 7:
        size -= 1
        font = ImageFont.truetype(font_path, size)
    d.text(xy, words, font=font, fill=fill, anchor=anchor)


def poster_image(w: int, h: int, kind: int, seed: int) -> Image.Image:
    """A flyer stuck on the pole, one of six kinds: septic siphoning service, job hiring (call
    Gloria), an election poster, a drug watchlist, a police poster and a food delivery flyer.
    Each has torn edges and tape so it reads as pasted by hand."""
    kind %= 6
    bgs = [(250, 224, 60), (245, 245, 238), (70, 140, 70), (236, 232, 218), (28, 60, 140), (236, 80, 120)]
    img = Image.new("RGBA", (w, h), bgs[kind] + (255,))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(seed + kind * 7)
    bw = w * 0.88
    cx = w // 2
    dark, white, red = (30, 30, 36, 255), (255, 255, 255, 255), (190, 28, 34, 255)
    if kind == 0:   # septic siphoning
        _fit(d, (cx, h * 0.12), "SEPTIC TANK", bw, int(h * 0.13), red)
        _fit(d, (cx, h * 0.26), "SIPHONING", bw, int(h * 0.17), dark)
        _fit(d, (cx, h * 0.38), "SERVICE", bw, int(h * 0.12), dark)
        d.rectangle((w * 0.14, h * 0.46, w * 0.86, h * 0.66), fill=(40, 120, 170, 255))
        d.rectangle((w * 0.3, h * 0.52, w * 0.7, h * 0.62), fill=(230, 230, 232, 255))
        d.ellipse((w * 0.2, h * 0.62, w * 0.34, h * 0.7), fill=dark)
        d.ellipse((w * 0.66, h * 0.62, w * 0.8, h * 0.7), fill=dark)
        _fit(d, (cx, h * 0.78), "24 HRS  MURA", bw, int(h * 0.075), dark, FONT_BOLD)
        _fit(d, (cx, h * 0.88), "0900-000-0000", bw, int(h * 0.09), red)
    elif kind == 1:   # job hiring
        d.rectangle((0, 0, w, h * 0.24), fill=(190, 28, 34, 255))
        _fit(d, (cx, h * 0.12), "HIRING!", bw, int(h * 0.17), white)
        _fit(d, (cx, h * 0.33), "TAUHAN SA TINDAHAN", bw, int(h * 0.07), dark, FONT_BOLD)
        for i, t in enumerate(["Cashier", "Rider", "Kasambahay", "Bantay"]):
            _fit(d, (w * 0.14, h * (0.43 + i * 0.075)), "\u2022 " + t, bw * 0.8, int(h * 0.06), dark, FONT_BOLD, "lm")
        _fit(d, (cx, h * 0.77), "CALL GLORIA", bw, int(h * 0.11), (30, 60, 150, 255))
        _fit(d, (cx, h * 0.89), "0900-000-0001", bw, int(h * 0.08), dark)
    elif kind == 2:   # election
        _fit(d, (cx, h * 0.09), "BOTO 2025", bw, int(h * 0.1), (250, 224, 60, 255))
        d.ellipse((w * 0.3, h * 0.2, w * 0.7, h * 0.46), fill=(214, 168, 130, 255))
        d.pieslice((w * 0.12, h * 0.44, w * 0.88, h * 0.9), 180, 360, fill=(240, 240, 238, 255))
        d.polygon([(w * 0.42, h * 0.45), (w * 0.58, h * 0.45), (w * 0.5, h * 0.6)], fill=(190, 28, 34, 255))
        d.rectangle((w * 0.28, h * 0.15, w * 0.72, h * 0.2), fill=(20, 20, 24, 255))
        d.rectangle((0, h * 0.7, w, h * 0.84), fill=(250, 224, 60, 255))
        _fit(d, (cx, h * 0.77), "R. DELA CRUZ", bw, int(h * 0.075), dark)
        _fit(d, (cx, h * 0.91), "PARA SA BAYAN", bw, int(h * 0.075), white, FONT_BOLD)
    elif kind == 3:   # drug watchlist
        d.rectangle((0, 0, w, h * 0.2), fill=dark)
        _fit(d, (cx, h * 0.1), "DRUG WATCHLIST", bw, int(h * 0.11), (250, 224, 60, 255))
        _fit(d, (cx, h * 0.26), "BRGY. SAN ROQUE", bw, int(h * 0.06), dark, FONT_BOLD)
        for i in range(4):
            y = h * (0.33 + i * 0.13)
            d.rectangle((w * 0.1, y, w * 0.3, y + h * 0.11), fill=(120, 110, 100, 255))
            d.ellipse((w * 0.15, y + h * 0.01, w * 0.25, y + h * 0.065), fill=(80, 74, 68, 255))
            d.rectangle((w * 0.36, y + h * 0.02, w * rng.uniform(0.7, 0.9), y + h * 0.05), fill=dark)
            d.rectangle((w * 0.36, y + h * 0.07, w * rng.uniform(0.5, 0.65), y + h * 0.09), fill=(110, 110, 114, 255))
        _fit(d, (cx, h * 0.92), "IPAGBIGAY SA PUNONG BARANGAY", bw, int(h * 0.05), red, FONT_BOLD)
    elif kind == 4:   # police
        d.polygon([(cx, h * 0.04), (w * 0.8, h * 0.12), (w * 0.8, h * 0.3), (cx, h * 0.42), (w * 0.2, h * 0.3), (w * 0.2, h * 0.12)], fill=(250, 224, 60, 255))
        d.ellipse((w * 0.36, h * 0.12, w * 0.64, h * 0.32), fill=(28, 60, 140, 255))
        _fit(d, (cx, h * 0.22), "PNP", w * 0.2, int(h * 0.09), white)
        _fit(d, (cx, h * 0.52), "MAGING ALERTO", bw, int(h * 0.1), white)
        _fit(d, (cx, h * 0.63), "BAWAL ANG ILEGAL", bw, int(h * 0.07), (250, 224, 60, 255), FONT_BOLD)
        d.rectangle((w * 0.1, h * 0.7, w * 0.9, h * 0.72), fill=(250, 224, 60, 255))
        _fit(d, (cx, h * 0.8), "MAGSUMBONG", bw, int(h * 0.09), white)
        _fit(d, (cx, h * 0.91), "TAWAG 911", bw, int(h * 0.1), (250, 224, 60, 255))
    else:   # food delivery
        _fit(d, (cx, h * 0.12), "KAIN NA!", bw, int(h * 0.16), white)
        d.ellipse((w * 0.18, h * 0.24, w * 0.82, h * 0.6), fill=(250, 250, 248, 255))
        d.ellipse((w * 0.27, h * 0.29, w * 0.73, h * 0.55), fill=(150, 80, 40, 255))
        d.ellipse((w * 0.4, h * 0.34, w * 0.6, h * 0.46), fill=(240, 200, 90, 255))
        _fit(d, (cx, h * 0.7), "ADOBO MEAL \u20b199", bw, int(h * 0.085), white)
        d.rectangle((w * 0.1, h * 0.78, w * 0.9, h * 0.9), fill=white)
        _fit(d, (cx, h * 0.84), "LIBRENG DELIVERY", w * 0.8, int(h * 0.07), (200, 30, 80, 255))
    # Tape at the corners and a torn bottom edge.
    for i in range(0, w, max(w // 6, 6)):
        d.rectangle((i, int(h * 0.965), i + max(w // 12, 3), h), fill=(0, 0, 0, 0))
    d.polygon([(0, 0), (int(w * 0.16), 0), (0, int(h * 0.05))], fill=(236, 232, 210, 220))
    d.polygon([(w, 0), (int(w * 0.84), 0), (w, int(h * 0.05))], fill=(236, 232, 210, 220))
    px = np.asarray(img).astype(np.float32)
    px[..., :3] *= (0.9 + noise(w, h, 5, seed) * 0.15)[..., None]
    return Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGBA")


def utility_pole(scene, cx, cz, radius=0.22, height=7.0, facets=56):
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
        width, hh = width * radius / 0.3, hh * radius / 0.3 * 1.15   # keep the same angle round a thinner trunk
        px_w, px_h = int(width * 900), int(hh * 900)
        poster = poster_image(px_w, px_h, k, k)
        a_left = math.radians(deg - 14)
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


def neighbour_store(scene, x0, x1, front_z, kind: str, quads=None):
    """A shop front next door, in focus: painted walls over a second floor with grilled windows and
    an air-conditioner, a sign, an awning, and a ground floor that depends on the kind of shop
    ("botika", "kainan", "hardware", "load", "sarisari", "gcash")."""
    styles = {
        "botika": ((206, 226, 206), "BOTIKA", (30, 120, 70), ((238, 238, 238), (40, 150, 90))),
        "kainan": ((244, 214, 140), "KAINAN", (196, 84, 30), ((250, 224, 100), (214, 74, 40))),
        "hardware": ((178, 194, 220), "HARDWARE", (40, 70, 140), ((222, 222, 226), (60, 90, 170))),
        "load": ((240, 168, 168), "LOAD", (30, 100, 190), ((240, 240, 244), (210, 50, 70))),
        "sarisari": ((220, 230, 160), "SARI-SARI", (186, 40, 50), ((250, 232, 130), (190, 60, 50))),
        "gcash": ((196, 170, 210), "GCASH", (30, 90, 220), ((232, 232, 242), (110, 80, 170))),
    }
    wall_color, sign_text, sign_color, awning_colors = styles[kind]
    seed = int(abs(x0) * 7) % 90 + 3
    wall = stained(256, 512, wall_color, seed, 0.22)
    width = x1 - x0
    rng = np.random.default_rng(seed)
    z = front_z

    def add(points, color, **kw):
        scene.face(points, color, **kw)

    def rect(xa, xb, ya, yb, dz):
        return [(xa, yb, z - dz), (xb, yb, z - dz), (xb, ya, z - dz), (xa, ya, z - dz)]

    add(rect(x0, x1, 0.0, 6.2, 0.0), wall_color, texture=wall, layer=1)
    # A band of darker paint at the foot of the wall, and a second band under the roof line.
    add(rect(x0, x1, 0.0, 0.5, 0.005), tuple(int(c * 0.72) for c in wall_color), layer=1)
    add(rect(x0, x1, 5.7, 6.0, 0.005), tuple(int(c * 0.86) for c in wall_color), layer=1)
    # Upper floor: two windows with white iron grilles, one with an air-conditioner under it.
    for i, wx in enumerate((x0 + width * 0.12, x0 + width * 0.58)):
        add(rect(wx, wx + 0.95, 3.9, 5.2, 0.01), (232, 232, 236), layer=2)
        add(rect(wx + 0.06, wx + 0.89, 3.96, 5.14, 0.02), (58, 78, 100), layer=2)
        for gx in np.arange(wx + 0.06, wx + 0.9, 0.14):
            add(rect(gx, gx + 0.022, 3.96, 5.14, 0.03), (238, 238, 242), layer=2)
        add(rect(wx + 0.06, wx + 0.89, 4.5, 4.52, 0.03), (238, 238, 242), layer=2)
        if i == 1:
            scene.box(wx + 0.1, wx + 0.8, 3.45, 3.8, z - 0.34, z - 0.02, (226, 228, 232), layer=2)
            add(rect(wx + 0.16, wx + 0.74, 3.5, 3.62, 0.36), (70, 72, 78), layer=3)
    # A drain pipe down the end of the wall.
    scene.box(x1 - 0.12, x1 - 0.05, 0.0, 5.9, z - 0.08, z - 0.01, (170, 170, 172), layer=2)
    sign = Image.new("RGBA", (800, 150), sign_color + (255,))
    sd = ImageDraw.Draw(sign)
    sd.rectangle((0, 0, 800, 10), fill=(255, 255, 255, 255))
    sd.text((400, 80), sign_text, font=ImageFont.truetype(FONT_BLACK, 92), fill=(255, 255, 255, 255), anchor="mm")
    add(rect(x0 + 0.1, x1 - 0.1, 2.72, 3.42, 0.04), sign_color, texture=sign, layer=3)
    stripes = Image.new("RGBA", (400, 100), awning_colors[0] + (255,))
    sd = ImageDraw.Draw(stripes)
    for i in range(0, 400, 80):
        sd.rectangle((i, 0, i + 40, 100), fill=awning_colors[1] + (255,))
    add([(x0 + 0.04, 2.7, z - 0.03), (x1 - 0.04, 2.7, z - 0.03), (x1 - 0.04, 2.34, z - 0.75), (x0 + 0.04, 2.34, z - 0.75)], awning_colors[0],
        texture=stripes, layer=3, two_sided=True)

    # The ground floor.
    if kind == "hardware":
        # A steel shutter half rolled up over shelves of paint, with pipes leaning outside.
        add(rect(x0 + 0.25, x1 - 0.25, 0.0, 2.55, 0.01), (70, 66, 62), layer=2)
        for sy in np.arange(0.3, 2.2, 0.55):
            add(rect(x0 + 0.3, x1 - 0.3, sy, sy + 0.04, 0.02), (150, 112, 70), layer=2)
            for cx in np.arange(x0 + 0.4, x1 - 0.6, 0.32):
                col = [(210, 60, 50), (240, 200, 60), (60, 120, 200), (220, 220, 224)][int(rng.integers(0, 4))]
                add(rect(cx, cx + 0.2, sy + 0.04, sy + 0.24, 0.03), col, layer=3, emissive=True)
        add(rect(x0 + 0.2, x1 - 0.2, 1.7, 2.6, 0.06), (150, 156, 162), texture=shutter_texture(400, 300), layer=3)
        for px_ in (x1 - 0.7, x1 - 0.55, x1 - 0.4):
            scene.box(px_, px_ + 0.08, 0.0, 2.1, z - 0.2, z - 0.12, (180, 184, 190), layer=3)
    elif kind == "sarisari":
        # An iron-grilled window full of hanging snacks, and a counter.
        add(rect(x0 + 0.3, x1 - 0.3, 0.7, 2.5, 0.01), (62, 56, 52), layer=2)
        for gx in np.arange(x0 + 0.4, x1 - 0.5, 0.2):
            for gy in np.arange(1.0, 2.4, 0.24):
                col = [(220, 60, 50), (240, 200, 50), (60, 150, 220), (90, 190, 110), (240, 120, 40), (240, 240, 240)][int(rng.integers(0, 6))]
                add(rect(gx, gx + 0.14, gy, gy + 0.2, 0.03), col, layer=3, emissive=True)
        for gx in np.arange(x0 + 0.3, x1 - 0.3, 0.16):
            add(rect(gx, gx + 0.02, 0.7, 2.5, 0.05), (30, 30, 34), layer=3)
        add(rect(x0 + 0.3, x1 - 0.3, 0.9, 1.0, 0.1), (120, 90, 60), layer=3)
        add(rect(x0 + 0.3, x1 - 0.3, 0.0, 0.9, 0.08), (186, 60, 50), layer=2)
    elif kind == "kainan":
        # Open front: a counter with steel trays of food, and a menu board.
        add(rect(x0 + 0.25, x1 - 0.25, 0.0, 2.55, 0.01), (96, 70, 50), layer=2, emissive=True)
        add(rect(x0 + 0.25, x1 - 0.25, 0.0, 1.0, 0.1), (190, 192, 198), layer=3)
        for tx in np.arange(x0 + 0.4, x1 - 0.8, 0.5):
            col = [(210, 90, 40), (240, 200, 70), (150, 190, 80), (200, 60, 50)][int(rng.integers(0, 4))]
            add(rect(tx, tx + 0.4, 1.0, 1.12, 0.14), (210, 212, 218), layer=3)
            add(rect(tx + 0.03, tx + 0.37, 1.02, 1.1, 0.16), col, layer=3, emissive=True)
        board = Image.new("RGBA", (200, 140), (40, 80, 50, 255))
        bd = ImageDraw.Draw(board)
        for i in range(5):
            bd.rectangle((14, 16 + i * 24, 110, 24 + i * 24), fill=(240, 240, 235, 255))
            bd.rectangle((130, 16 + i * 24, 186, 24 + i * 24), fill=(250, 220, 90, 255))
        add(rect(x0 + 0.5, x0 + 1.5, 1.6, 2.3, 0.05), (40, 80, 50), texture=board, layer=3)
    else:
        # A glass shopfront with a door and a display of goods; a lit sign above the door.
        add(rect(x0 + 0.25, x1 - 0.25, 0.0, 2.55, 0.01), (170, 190, 205), layer=2)
        add(rect(x0 + 0.3, x1 - 0.3, 0.05, 2.5, 0.02), (96, 120, 140), layer=2)
        add(rect(x0 + 0.3, x1 - 0.3, 0.9, 0.95, 0.04), (230, 230, 235), layer=3)
        dw = x0 + width * 0.55
        add(rect(dw, dw + 0.9, 0.0, 2.2, 0.04), (226, 228, 232), layer=3)
        add(rect(dw + 0.06, dw + 0.84, 0.06, 2.14, 0.05), (110, 140, 160), layer=3)
        for gx in np.arange(x0 + 0.4, dw - 0.4, 0.33):
            col = [(60, 140, 220), (240, 240, 245), (220, 70, 70), (250, 200, 60)][int(rng.integers(0, 4))]
            add(rect(gx, gx + 0.24, 0.95, 1.35 + float(rng.uniform(0, 0.4)), 0.06), col, layer=3, emissive=True)
    if quads is not None:
        quads.append(rect(x0, x1, 0.0, 6.2, 0.0))


def build(size) -> Image.Image:
    """The picture, seen over the rider's shoulder."""
    w, h = size
    camera = s3.Camera((1.2, 1.5, -1.45), 0.0, -0.4, 70.0, size)
    scene = s3.Scene(camera, ambient=(168, 170, 178), sky_dir=(0.15, 1.0, -0.25))
    scene.light((9.0, 11.0, -9.0), SUN, 900.0, reach=22.0)

    # The pavement, in slabs small enough to draw well close to the camera.
    slabs = paving(18.0, 3.6)
    px_per_m = slabs.width / 18.0
    for ix in range(12):
        for iz in range(4):
            x0, x1 = -9.0 + ix * 1.5, -9.0 + (ix + 1) * 1.5
            z0, z1 = -3.6 + iz * 0.9, -3.6 + (iz + 1) * 0.9
            crop = slabs.crop((int(ix * 1.5 * px_per_m), int(iz * 0.9 * px_per_m), int((ix + 1) * 1.5 * px_per_m), int((iz + 1) * 0.9 * px_per_m)))
            scene.face([(x0, 0, z1), (x1, 0, z1), (x1, 0, z0), (x0, 0, z0)], (150, 148, 142), texture=crop, layer=0)

    gx0, gx1, gy0, gy1 = -2.1, 3.0, 0.5, 2.62
    door_x0, door_x1, door_top = 1.62, 2.82, 2.1
    # Shops next door, left and right, all in focus.
    neighbour_store(scene, -5.45, gx0 - 0.02, 0.0, "botika")
    neighbour_store(scene, -8.9, -5.47, 0.2, "kainan")
    neighbour_store(scene, -12.4, -8.92, -0.1, "hardware")
    neighbour_store(scene, gx1 + 0.02, 6.3, 0.0, "load")
    neighbour_store(scene, 6.32, 9.7, 0.25, "sarisari")
    neighbour_store(scene, 9.72, 13.2, -0.1, "gcash")

    # The TV shop: sign band, upper wall, the riser under the window (not under the doors).
    wall = stained(512, 512, (226, 214, 190), 41, 0.2)
    scene.face([(gx0, gy0, 0), (door_x0 - 0.05, gy0, 0), (door_x0 - 0.05, 0.0, 0), (gx0, 0.0, 0)], (96, 96, 100), layer=1)
    scene.face([(door_x1 + 0.05, gy0, 0), (gx1, gy0, 0), (gx1, 0.0, 0), (door_x1 + 0.05, 0.0, 0)], (96, 96, 100), layer=1)
    scene.face([(gx0, 3.5, 0), (gx1, 3.5, 0), (gx1, 2.62, 0), (gx0, 2.62, 0)], (24, 52, 120), texture=sign_texture(1500, 230), layer=1)
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
    # Behind the doors: a clear aisle to a counter, with a bright promotion banner on the wall.
    banner = Image.new("RGBA", (500, 140), (200, 30, 40, 255))
    _text(ImageDraw.Draw(banner), (250, 70), "BIG SALE - TV PROMO", 52, (255, 255, 255, 255), anchor="mm")
    scene.face([(1.7, 2.5, 4.97), (2.9, 2.5, 4.97), (2.9, 1.9, 4.97), (1.7, 1.9, 4.97)], (200, 30, 40), texture=banner, layer=1, emissive=True)
    scene.box(1.7, 2.9, 0.0, 0.95, 3.8, 4.5, (120, 96, 70), layer=1)
    scene.box(1.7, 2.9, 0.95, 0.99, 3.75, 4.55, (210, 210, 214), layer=1)
    # Three shelves, each a row of five identical tube sets side by side with a clear gap between.
    plank = (118, 92, 66)
    shelf_tops = (0.55, 1.4)
    shelf_x0, shelf_x1 = -2.0, 1.5
    for top in shelf_tops:
        scene.box(shelf_x0, shelf_x1, top - 0.03, top, 0.5, 1.9, plank, layer=1)
    for ux in (shelf_x0, shelf_x1):
        scene.box(ux - 0.02, ux + 0.02, 0.0, 2.15, 0.5, 1.9, (70, 72, 82), layer=1)
    scene.box(shelf_x0, shelf_x1, 0.0, 0.52, 0.55, 1.85, (44, 46, 54), layer=1)
    pitch = (shelf_x1 - shelf_x0) / 3
    bezels = [(26, 26, 30), (176, 178, 184)]
    frame_no = 0
    for row, top in enumerate(shelf_tops):
        for col in range(3):
            cx = shelf_x0 + pitch * (col + 0.5)
            crt_set(scene, cx, top, 0.6, broadcast(640, 360, frame_no % 5), bezel=bezels[(row + col) % 2], k=1.5)
            frame_no += 1 + (row == 1)

    # ---- the window: aluminium frames between the sets, the double glass door, then the glass sheet
    frame_c = (176, 180, 188)
    for fx in (gx0, shelf_x0 + pitch, shelf_x0 + pitch * 2, door_x0, gx1):
        scene.box(fx - 0.035, fx + 0.035, gy0 if fx < door_x0 else 0.0, gy1, -0.06, 0.03, frame_c, layer=4)
    scene.box(gx0, gx1, gy1 - 0.03, gy1 + 0.03, -0.06, 0.03, frame_c, layer=4)
    scene.box(gx0, door_x0, gy0 - 0.03, gy0 + 0.03, -0.06, 0.03, frame_c, layer=4)
    scene.box(door_x1, gx1, gy0 - 0.03, gy0 + 0.03, -0.06, 0.03, frame_c, layer=4)
    # The door: jambs, a centre stile where the two leaves meet, a top rail, kick plates, push bars
    # and long pull handles, and a small OPEN sign.
    mid = (door_x0 + door_x1) / 2
    for fx in (door_x1, mid):
        scene.box(fx - 0.04, fx + 0.04, 0.0, door_top, -0.07, 0.03, frame_c, layer=4)
    scene.box(door_x0, door_x1, door_top - 0.04, door_top + 0.04, -0.07, 0.03, frame_c, layer=4)
    scene.box(door_x0, door_x1, 0.0, 0.04, -0.07, 0.03, frame_c, layer=4)
    for lx0, lx1 in ((door_x0 + 0.035, mid - 0.04), (mid + 0.04, door_x1 - 0.04)):
        scene.face([(lx0, 0.32, -0.075), (lx1, 0.32, -0.075), (lx1, 0.04, -0.075), (lx0, 0.04, -0.075)], (150, 154, 162), layer=4)
        scene.face([(lx0, door_top - 0.04, -0.075), (lx1, door_top - 0.04, -0.075), (lx1, door_top - 0.2, -0.075), (lx0, door_top - 0.2, -0.075)], (150, 154, 162), layer=4)
    for hx in (mid - 0.14, mid + 0.14):
        scene.box(hx - 0.012, hx + 0.012, 0.75, 1.55, -0.14, -0.1, (214, 216, 222), layer=4)
        scene.box(hx - 0.012, hx + 0.012, 0.78, 0.8, -0.14, -0.07, (214, 216, 222), layer=4)
        scene.box(hx - 0.012, hx + 0.012, 1.5, 1.52, -0.14, -0.07, (214, 216, 222), layer=4)
    open_sign = Image.new("RGBA", (220, 100), (255, 255, 255, 255))
    od = ImageDraw.Draw(open_sign)
    od.rounded_rectangle((4, 4, 216, 96), 10, fill=(190, 24, 32, 255))
    _text(od, (110, 50), "OPEN", 58, (255, 255, 255, 255), anchor="mm")
    scene.face([(1.74, 1.72, -0.012), (2.1, 1.72, -0.012), (2.1, 1.54, -0.012), (1.74, 1.54, -0.012)], (255, 255, 255), texture=open_sign, layer=5, emissive=True)
    # A door mat on the pavement.
    mat = Image.new("RGBA", (200, 60), (36, 36, 40, 255))
    ImageDraw.Draw(mat).rectangle((6, 6, 194, 54), outline=(150, 40, 40, 255), width=4)
    scene.face([(door_x0 + 0.1, 0.004, -0.15), (door_x1 - 0.1, 0.004, -0.15), (door_x1 - 0.1, 0.004, -0.75), (door_x0 + 0.1, 0.004, -0.75)], (40, 40, 44), texture=mat, layer=1)
    scene.face([(gx0, gy1, -0.01), (gx1, gy1, -0.01), (gx1, 0.0, -0.01), (gx0, 0.0, -0.01)], (255, 255, 255),
               texture=glass_layer(1700, 700), layer=5, emissive=True)
    notice = Image.new("RGBA", (200, 280), (250, 245, 220, 255))
    nd = ImageDraw.Draw(notice)
    _text(nd, (100, 56), "0%", 80, (190, 24, 30, 255), anchor="mm")
    _text(nd, (100, 130), "INSTALLMENT", 26, (30, 30, 40, 255), FONT_BOLD, "mm")
    _text(nd, (100, 190), "UP TO", 22, (30, 30, 40, 255), FONT_BOLD, "mm")
    _text(nd, (100, 228), "12 MOS.", 34, (190, 24, 30, 255), FONT_BLACK, "mm")
    # Payment stickers on the glass, stacked beside the promo notice.
    for n, (words, bg, fg, y_top) in enumerate([("BCash payment available", (24, 84, 200), (255, 255, 255), 2.45),
                                              ("HouseCredit available", (200, 30, 40), (255, 255, 255), 2.21),
                                              ("Loro payment", (12, 12, 14), (60, 220, 100), 1.97)]):
        tag = Image.new("RGBA", (360, 150), bg + (255,))
        td = ImageDraw.Draw(tag)
        parts = words.split(" ", 1)
        _fit(td, (180, 52), parts[0], 320, 72, fg + (255,))
        _fit(td, (180, 112), parts[1], 320, 44, fg + (255,), FONT_BOLD)
        scene.face([(0.86, y_top, -0.015), (1.18, y_top, -0.015), (1.18, y_top - 0.2, -0.015), (0.86, y_top - 0.2, -0.015)], bg, texture=tag, layer=5, emissive=True)
    scene.face([(1.22, 2.45, -0.015), (1.5, 2.45, -0.015), (1.5, 1.9, -0.015), (1.22, 1.9, -0.015)], (250, 245, 220), texture=notice, layer=5, emissive=True)

    # ---- the wooden pole at the kerb in front of the neighbouring shop, with its shadow
    pole_x, pole_z = 1.72, -0.42
    utility_pole(scene, pole_x, pole_z)
    pole_shadow = Image.new("RGBA", (60, 400), (0, 0, 0, 0))
    ImageDraw.Draw(pole_shadow).rectangle((10, 0, 50, 400), fill=(8, 8, 14, 150))
    pole_shadow = pole_shadow.filter(ImageFilter.GaussianBlur(3))
    scene.face([(pole_x - 1.4 - 0.3, 0.003, pole_z + 0.7), (pole_x - 1.4 + 0.3, 0.003, pole_z + 0.7), (pole_x + 0.3, 0.003, pole_z), (pole_x - 0.3, 0.003, pole_z)],
               (0, 0, 0), texture=pole_shadow, layer=1)

    # ---- the rider's shadow, thrown towards the shop, away from the sun
    rider_x, rider_z = 0.75, -1.0
    shadow = Image.new("RGBA", (160, 520), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse((58, 460, 102, 510), fill=(8, 8, 14, 190))
    sd.rounded_rectangle((26, 120, 134, 390), 24, fill=(8, 8, 14, 190))
    sd.rectangle((44, 380, 116, 520), fill=(8, 8, 14, 190))
    sd.rectangle((70, 380, 90, 520), fill=(0, 0, 0, 0))
    shadow = shadow.filter(ImageFilter.GaussianBlur(5)).transpose(Image.FLIP_TOP_BOTTOM)
    far, near = -0.06, rider_z
    drift = -0.9
    scene.face([(rider_x - 0.34 + drift, 0.003, far), (rider_x + 0.34 + drift, 0.003, far), (rider_x + 0.2, 0.003, near), (rider_x - 0.2, 0.003, near)],
               (0, 0, 0), texture=shadow, layer=1)

    canvas = Image.new("RGBA", size, (176, 206, 238, 255))
    canvas = scene.render(canvas)

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

    # ---- the rider, seen from behind, so near the camera that only his head, shoulders and chest are
    # in the picture: the sprite is pasted with whatever falls outside the frame cut off.
    foot = camera.project((rider_x, 0.0, rider_z))
    scale = camera.pixels_for(1.75, foot[2]) / rider_back.HEIGHT
    sprite = rider_back.rider_back(scale)
    px = np.asarray(sprite).astype(np.float32)
    ramp = np.linspace(0.0, 1.0, sprite.width)[None, :]
    px[..., :3] *= (0.94 + 0.12 * ramp)[..., None]   # a little more sun on the side nearest the shop
    px[..., 2] += (1 - ramp) * 10                      # a cool bounce from the shop's screens on the other side
    sprite = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGBA")
    left, top = int(foot[0] - sprite.width / 2), int(foot[1] - sprite.height)
    x0, y0 = max(left, 0), max(top, 0)
    x1, y1 = min(left + sprite.width, w), min(top + sprite.height, h)
    if x1 > x0 and y1 > y0:
        near = sprite.crop((x0 - left, y0 - top, x1 - left, y1 - top))
        # Out of focus: he is much closer than the shop, so the lens softens him (premultiplied, so no dark fringe).
        a = np.asarray(near).astype(np.float32)
        a[..., :3] *= a[..., 3:4] / 255.0
        a = np.stack([gaussian_filter(a[..., i], 7.0) for i in range(4)], axis=-1)
        a[..., :3] = a[..., :3] / np.maximum(a[..., 3:4] / 255.0, 1e-3)
        near = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
        canvas.alpha_composite(near, (x0, y0))
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
