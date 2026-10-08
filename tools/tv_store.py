"""The news scene of Tokhang: a television shop in daylight, seen from the pavement through its
front window, and in the foreground a delivery rider seen from behind, watching the news.

Built in 3D with scene3d.py so it has a true camera angle, perspective and light:
- the street outside, in sun: a pavement with the rider's long shadow, the shop front with its sign,
  an awning, aluminium window frames and a glass pane;
- the shop inside, lit by ceiling lights: tiers of televisions of every size (flat panels and old
  tube sets), all turned to the news, and a big screen on the back wall;
- the glass is drawn last, as a see-through sheet that holds the sky, the buildings across the street
  and the sun's glare, so the shop looks like it is behind a window;
- the rider is drawn by rider_back.py (not from any character art in the game).

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


def television(scene, centre_xz, y0, w, h, yaw, frame: Image.Image, tube: bool = False, layer=2):
    """A set facing the street (the glass), turned by `yaw`: a flat panel on a stand, or an old
    tube set with a deep body. Its screen glows with the news."""
    cx, cz = centre_xz
    if tube:
        depth = h * 0.85
        turned_box(scene, (cx, cz + depth / 2), y0, y0 + h, w, depth, yaw, (46, 46, 50), layer)
        bezel = 0.045
        front_z = cz - 0.002
        corners = [(cx - w / 2 + bezel, y0 + h - bezel, front_z), (cx + w / 2 - bezel * 1.6, y0 + h - bezel, front_z),
                   (cx + w / 2 - bezel * 1.6, y0 + bezel * 3.2, front_z), (cx - w / 2 + bezel, y0 + bezel * 3.2, front_z)]
        scene.face(_turned(corners, centre_xz, yaw), (30, 30, 34), texture=frame, layer=layer + 1, emissive=True)
        # Control strip under the glass.
        strip = [(cx - w / 2 + bezel, y0 + bezel * 3.0, cz - 0.003), (cx + w / 2 - bezel, y0 + bezel * 3.0, cz - 0.003),
                 (cx + w / 2 - bezel, y0 + bezel, cz - 0.003), (cx - w / 2 + bezel, y0 + bezel, cz - 0.003)]
        scene.face(_turned(strip, centre_xz, yaw), (150, 150, 156), layer=layer + 1)
    else:
        stand_h = 0.12 if w > 0.6 else 0.06
        turned_box(scene, centre_xz, y0, y0 + 0.012, w * 0.42, 0.22, yaw, (170, 172, 180), layer)
        turned_box(scene, centre_xz, y0 + 0.012, y0 + stand_h, 0.07, 0.05, yaw, (60, 60, 66), layer)
        body_y0 = y0 + stand_h
        turned_box(scene, centre_xz, body_y0, body_y0 + h, w, 0.05, yaw, (14, 14, 18), layer)
        m = min(w, h) * 0.025
        corners = [(cx - w / 2 + m, body_y0 + h - m, cz - 0.0255), (cx + w / 2 - m, body_y0 + h - m, cz - 0.0255),
                   (cx + w / 2 - m, body_y0 + m * 2.4, cz - 0.0255), (cx - w / 2 + m, body_y0 + m * 2.4, cz - 0.0255)]
        scene.face(_turned(corners, centre_xz, yaw), (30, 30, 34), texture=frame, layer=layer + 1, emissive=True)
    # The set's own glow, a little light on what is around it.
    scene.light((cx, y0 + h * 0.6, cz - 0.4), (150, 175, 255), 0.35 * min(w, 1.2), reach=1.6)


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


# ---------------------------------------------------------------- the whole picture


def build(size) -> Image.Image:
    w, h = size
    camera = s3.Camera((-1.7, 1.42, -4.0), 13.0, -2.4, 56.0, size)
    scene = s3.Scene(camera, ambient=(168, 170, 178), sky_dir=(0.15, 1.0, -0.25))
    scene.light((9.0, 11.0, -9.0), SUN, 900.0, reach=22.0)

    # The pavement, with a joint pattern, and the gutter edge near the camera.
    slabs = paving(13.0, 3.1)
    px_per_m = slabs.width / 13.0
    for ix in range(8):
        for iz in range(4):
            x0, x1 = -6.0 + ix * 1.625, -6.0 + (ix + 1) * 1.625
            z0, z1 = -3.1 + iz * 0.775, -3.1 + (iz + 1) * 0.775
            crop = slabs.crop((int(ix * 1.625 * px_per_m), int(iz * 0.775 * px_per_m), int((ix + 1) * 1.625 * px_per_m), int((iz + 1) * 0.775 * px_per_m)))
            scene.face([(x0, 0, z1), (x1, 0, z1), (x1, 0, z0), (x0, 0, z0)], (150, 148, 142), texture=crop, layer=0)

    # The shop front: wall piers, the sign band, the stall riser under the window.
    wall = stained(512, 512, (214, 200, 176), 41, 0.2)
    gx0, gx1, gy0, gy1 = -2.1, 2.5, 0.5, 2.62
    scene.face([(-6.0, 4.2, 0), (gx0, 4.2, 0), (gx0, 0.0, 0), (-6.0, 0.0, 0)], (214, 200, 176), texture=wall, layer=1)
    scene.face([(gx1, 4.2, 0), (7.0, 4.2, 0), (7.0, 0.0, 0), (gx1, 0.0, 0)], (214, 200, 176), texture=wall, layer=1)
    scene.face([(gx1 + 0.35, 2.55, -0.01), (gx1 + 2.9, 2.55, -0.01), (gx1 + 2.9, 0.0, -0.01), (gx1 + 0.35, 0.0, -0.01)], (150, 156, 162),
               texture=shutter_texture(520, 520), layer=2)
    # On the left pier: a meter box, a grey pipe down the wall and a sagging cable.
    scene.box(gx0 - 1.2, gx0 - 0.7, 1.2, 1.75, -0.12, -0.01, (186, 184, 176), layer=2)
    scene.box(gx0 - 0.5, gx0 - 0.42, 0.0, 3.6, -0.1, -0.01, (150, 150, 150), layer=2)
    scene.face([(gx0 - 0.7, 1.5, -0.125), (gx0 - 0.5, 1.5, -0.125), (gx0 - 0.5, 1.4, -0.125), (gx0 - 0.7, 1.4, -0.125)], (40, 40, 44), layer=3)
    scene.face([(gx0, gy0, 0), (gx1, gy0, 0), (gx1, 0.0, 0), (gx0, 0.0, 0)], (96, 96, 100), layer=1)
    scene.face([(gx0, 3.5, 0), (gx1, 3.5, 0), (gx1, 2.62, 0), (gx0, 2.62, 0)], (24, 52, 120), texture=sign_texture(1400, 230), layer=1)
    scene.face([(gx0, 4.2, 0), (gx1, 4.2, 0), (gx1, 3.5, 0), (gx0, 3.5, 0)], (214, 200, 176), texture=wall, layer=1)
    # Awning: a sloped striped sheet over the window, with a dark underside.
    scene.face([(gx0 - 0.1, 2.66, -0.04), (gx1 + 0.1, 2.66, -0.04), (gx1 + 0.1, 2.38, -1.0), (gx0 - 0.1, 2.38, -1.0)], (230, 230, 232),
               texture=awning_texture(900, 260), layer=3, two_sided=True)
    scene.face([(gx0 - 0.1, 2.38, -1.0), (gx1 + 0.1, 2.38, -1.0), (gx1 + 0.1, 2.28, -1.0), (gx0 - 0.1, 2.28, -1.0)], (170, 28, 38), layer=3)

    # ---- the inside of the shop (seen through the glass)
    scene.face([(gx0, 0.0, 5.0), (gx1, 0.0, 5.0), (gx1, 0.0, 0.05), (gx0, 0.0, 0.05)], (130, 128, 124), texture=tile_floor(720, 720), layer=0)
    scene.face([(gx0, 3.0, 5.0), (gx1, 3.0, 5.0), (gx1, 0.0, 5.0), (gx0, 0.0, 5.0)], (96, 98, 108), layer=0)
    scene.face([(gx0, 3.0, 0.05), (gx0, 3.0, 5.0), (gx0, 0.0, 5.0), (gx0, 0.0, 0.05)], (84, 84, 94), layer=0, two_sided=True)
    scene.face([(gx1, 3.0, 5.0), (gx1, 3.0, 0.05), (gx1, 0.0, 0.05), (gx1, 0.0, 5.0)], (84, 84, 94), layer=0, two_sided=True)
    scene.face([(gx0, 3.0, 0.05), (gx1, 3.0, 0.05), (gx1, 3.0, 5.0), (gx0, 3.0, 5.0)], (110, 110, 118), layer=0, two_sided=True)
    for lx in (-1.4, 0.6, 2.4):
        for lz in (1.2, 3.2):
            scene.face([(lx - 0.5, 2.99, lz + 0.12), (lx + 0.5, 2.99, lz + 0.12), (lx + 0.5, 2.99, lz - 0.12), (lx - 0.5, 2.99, lz - 0.12)], (255, 255, 250), layer=1, emissive=True, two_sided=True)
            scene.light((lx, 2.7, lz), (255, 244, 220), 1.5, reach=4.2)
    # Back wall: a big wall-mounted screen and a shelf of boxes.
    television(scene, (1.1, 4.9), 1.35, 2.2, 1.24, 0, broadcast(640, 360, 0), layer=1)
    for i in range(6):
        scene.face([(-2.3 + i * 0.5, 1.2, 4.95), (-1.9 + i * 0.5, 1.2, 4.95), (-1.9 + i * 0.5, 0.2, 4.95), (-2.3 + i * 0.5, 0.2, 4.95)],
                   [(220, 70, 60), (60, 120, 210), (240, 200, 60), (80, 170, 100), (200, 200, 205), (230, 120, 50)][i], layer=1)

    # Tiers of sets: tall ones on the floor, a middle shelf and an upper shelf.
    plank = (118, 92, 66)
    scene.box(-2.0, 2.4, 0.0, 0.42, 0.55, 1.15, (44, 46, 54), layer=1)
    scene.box(-2.0, 2.4, 0.9, 0.93, 0.5, 1.2, plank, layer=1)
    scene.box(-2.0, 2.4, 1.55, 1.58, 0.5, 1.2, plank, layer=1)
    for ux in (-2.0, 0.2, 2.4):
        scene.box(ux - 0.02, ux + 0.02, 0.0, 1.62, 0.5, 1.2, (70, 72, 82), layer=1)
    frames = [broadcast(640, 360, k % 5) for k in range(10)]
    # Floor tier: three big sets.
    television(scene, (-1.38, 0.78), 0.42, 1.2, 0.68, -10, frames[1])
    television(scene, (0.2, 0.8), 0.42, 1.1, 0.62, 3, frames[0])
    television(scene, (1.7, 0.78), 0.42, 1.2, 0.68, 12, frames[2])
    # Middle shelf: four mid-size sets, turned a little this way and that.
    for i, (cx, ww, yaw) in enumerate(((-1.6, 0.66, -8), (-0.5, 0.64, 5), (0.6, 0.7, -4), (1.8, 0.64, 10))):
        television(scene, (cx, 0.78), 0.93, ww, ww * 0.56, yaw, frames[(i + 3) % 10])
    # Upper shelf: small flat panels and old tube sets.
    for i, (cx, ww, yaw, tube) in enumerate(((-1.7, 0.52, -10, True), (-0.85, 0.5, 6, False), (0.0, 0.52, -2, True), (0.9, 0.5, 8, False), (1.8, 0.52, -6, True))):
        television(scene, (cx, 0.76), 1.58, ww, ww * 0.78 if tube else ww * 0.56, yaw, frames[(i + 6) % 10], tube=tube)
    # Price tags on the shelf edges.
    for tx in (-1.8, -0.9, 0.0, 1.0, 2.0):
        scene.face([(tx - 0.05, 0.93, 0.5), (tx + 0.05, 0.93, 0.5), (tx + 0.05, 0.87, 0.5), (tx - 0.05, 0.87, 0.5)], (250, 220, 40), layer=3, emissive=True)

    # ---- window frames in aluminium, the glass sheet last
    frame_c = (176, 180, 188)
    for fx in (gx0, -0.55, 1.0, gx1):
        scene.box(fx - 0.035, fx + 0.035, gy0, gy1, -0.06, 0.03, frame_c, layer=4)
    scene.box(gx0, gx1, gy1 - 0.03, gy1 + 0.03, -0.06, 0.03, frame_c, layer=4)
    scene.box(gx0, gx1, gy0 - 0.03, gy0 + 0.03, -0.06, 0.03, frame_c, layer=4)
    scene.box(gx0, gx1, 2.08 - 0.025, 2.08 + 0.025, -0.05, 0.03, frame_c, layer=4)
    gw, gh = 1600, 640
    scene.face([(gx0, gy1, -0.01), (gx1, gy1, -0.01), (gx1, gy0, -0.01), (gx0, gy0, -0.01)], (255, 255, 255),
               texture=glass_layer(gw, gh), layer=5, emissive=True)
    # A paper notice taped inside the glass.
    notice = Image.new("RGBA", (200, 280), (250, 245, 220, 255))
    nd = ImageDraw.Draw(notice)
    _text(nd, (100, 56), "0%", 80, (190, 24, 30, 255), anchor="mm")
    _text(nd, (100, 130), "INSTALLMENT", 26, (30, 30, 40, 255), FONT_BOLD, "mm")
    _text(nd, (100, 190), "UP TO", 22, (30, 30, 40, 255), FONT_BOLD, "mm")
    _text(nd, (100, 228), "12 MOS.", 34, (190, 24, 30, 255), FONT_BLACK, "mm")
    scene.face([(2.08, 2.0, -0.015), (2.44, 2.0, -0.015), (2.44, 1.3, -0.015), (2.08, 1.3, -0.015)], (250, 245, 220), texture=notice, layer=5, emissive=True)

    # The rider's shadow on the pavement, long and thrown towards the shop, away from the sun.
    rider_x, rider_z = -1.75, -1.35
    shadow = Image.new("RGBA", (160, 520), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse((58, 460, 102, 510), fill=(8, 8, 14, 190))
    sd.rounded_rectangle((26, 120, 134, 390), 24, fill=(8, 8, 14, 190))
    sd.rectangle((44, 380, 116, 520), fill=(8, 8, 14, 190))
    sd.rectangle((70, 380, 90, 520), fill=(0, 0, 0, 0))
    shadow = shadow.filter(ImageFilter.GaussianBlur(5)).transpose(Image.FLIP_TOP_BOTTOM)
    far, near = -0.06, rider_z
    drift = -1.0
    scene.face([(rider_x - 0.34 + drift, 0.003, far), (rider_x + 0.34 + drift, 0.003, far), (rider_x + 0.2, 0.003, near), (rider_x - 0.2, 0.003, near)],
               (0, 0, 0), texture=shadow, layer=1)

    canvas = Image.new("RGBA", size, (176, 206, 238, 255))
    canvas = scene.render(canvas)

    # ---- his motorbike, parked at the kerb on the right, with the same delivery box
    bike = Image.open(Path(__file__).resolve().parent.parent / "assets" / "props" / "motor.png").convert("RGBA")
    bike_foot = camera.project((1.9, 0.0, -1.9))
    bike_h = camera.pixels_for(1.05, bike_foot[2])
    bike = bike.resize((int(bike.width * bike_h / bike.height), int(bike_h)), Image.LANCZOS)
    bike_shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(bike_shadow).ellipse((bike_foot[0] - bike.width * 0.5, bike_foot[1] - 8, bike_foot[0] + bike.width * 0.62, bike_foot[1] + 16), fill=(10, 10, 14, 130))
    canvas.alpha_composite(bike_shadow.filter(ImageFilter.GaussianBlur(8)))
    canvas.alpha_composite(bike, (int(bike_foot[0] - bike.width / 2), int(bike_foot[1] - bike.height)))

    # ---- the rider, from behind, standing at the pavement edge of the window
    rider = rider_back.rider_back()
    foot = camera.project((rider_x, 0.0, rider_z))
    height_px = camera.pixels_for(1.75, foot[2])
    scale = height_px / rider.height
    sprite = rider.resize((int(rider.width * scale), int(rider.height * scale)), Image.LANCZOS)
    # Light from the shop on the side of him nearest the screens, a cool rim.
    px = np.asarray(sprite).astype(np.float32)
    ramp = np.linspace(1.0, 0.0, sprite.width)[None, :]
    px[..., 2] += ramp * 14
    px[..., :3] = np.clip(px[..., :3], 0, 255)
    sprite = Image.fromarray(px.astype(np.uint8), "RGBA")
    contact = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(contact).ellipse((foot[0] - sprite.width * 0.4, foot[1] - 10, foot[0] + sprite.width * 0.4, foot[1] + 14), fill=(10, 10, 14, 120))
    canvas.alpha_composite(contact.filter(ImageFilter.GaussianBlur(7)))
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
