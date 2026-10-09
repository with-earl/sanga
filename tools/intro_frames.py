"""The first and third pictures of the Tokhang intro, drawn from nothing in 3D like the TV news scene
(tv_store.py): no game art is used.

  Frame 1, the skyway: a low shot from the side as Peter rides his pink scooter along the elevated
  expressway at speed (the road streaks towards the vanishing point, the bike stays sharp), a green
  exit gantry and far traffic ahead, a hazy Manila beyond the barrier with a Gothic church spire.
  Frame 3, the market: a chase view from above and behind Peter's left shoulder as he rolls into the
  palengke street: his helmet and backpack, his hand on the grip, the dashboard and the phone on the
  handlebar, then a crowded palengke: vendors and shoppers, stalls of fish, vegetables, meat, fruit, rice and isaw,
  tarpaulin roofs, wires, a parked jeepney and a banner over the far entrance, all glowing in low sunlight.

The scooter and Peter are built by bike_parts.py, the market's stalls, people and tarps by market_parts.py. In each picture the bike is drawn in a pass of its own
over the background, so the background can be softened (speed in frame 1, shallow focus in frame 3).

Run: python tools/intro_frames.py skyway|market [out.png] [width height]
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bike_parts as bp  # noqa: E402
import market_parts as mp  # noqa: E402
import scene3d as s3  # noqa: E402
from street_scene import noise  # noqa: E402
from tv_store import FONT_BLACK, FONT_BOLD, _fit  # noqa: E402

SIZE = (1672, 941)
PINK = (232, 70, 140)


# ---------------------------------------------------------------- small shapes


def tube(scene, a, b, width, color, layer=2, sides=6):
    """A straight round-ish bar from point `a` to point `b`, drawn as a prism with `sides` sides."""
    a, b = np.array(a, float), np.array(b, float)
    d = b - a
    d /= np.linalg.norm(d)
    up = np.array([0.0, 1.0, 0.0]) if abs(d[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = np.cross(d, up)
    u /= np.linalg.norm(u)
    v = np.cross(d, u)
    ring = [(math.cos(2 * math.pi * i / sides) * u + math.sin(2 * math.pi * i / sides) * v) * width / 2 for i in range(sides)]
    for i in range(sides):
        r0, r1 = ring[i], ring[(i + 1) % sides]
        scene.face([a + r0, a + r1, b + r1, b + r0], color, layer=layer, two_sided=True)


def asphalt(w, h, seed, base=(86, 86, 92)):
    """Road surface: soft blotches and fine grit."""
    blotch = noise(w, h, 60, seed) * 0.5 + noise(w, h, 14, seed + 1) * 0.3 + noise(w, h, 3, seed + 2) * 0.35
    rgb = np.array(base, np.float32)[None, None, :] * (0.72 + 0.5 * blotch)[..., None]
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert("RGBA")


def concrete(w, h, seed, base=(176, 172, 164), grooves=0):
    blotch = noise(w, h, 40, seed) * 0.5 + noise(w, h, 9, seed + 1) * 0.3
    rgb = np.array(base, np.float32)[None, None, :] * (0.8 + 0.35 * blotch)[..., None]
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(img)
    for i in range(1, grooves + 1):
        y = int(h * i / (grooves + 1))
        d.line((0, y, w, y), fill=(110, 106, 100, 255), width=max(h // 80, 1))
    return img


def contact_shadow(canvas, camera, cx, cz, alpha=150, length=0.4):
    """A soft dark patch on the ground under the tyre."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    pts = [camera.project((cx + 0.14 * math.cos(t), 0.0, cz + length * math.sin(t)))[:2] for t in np.linspace(0, 2 * math.pi, 28)]
    ImageDraw.Draw(layer).polygon(pts, fill=(10, 8, 8, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(canvas.size[0] / 200))
    out = canvas.copy()
    out.alpha_composite(layer)
    return out


# ---------------------------------------------------------------- picture effects


def radial_blur(img, centre, strength=0.08, steps=16, clear_radius=0.18):
    """Speed lines: copies of the picture scaled about `centre`, averaged, kept sharp near the centre."""
    w, h = img.size
    cx, cy = centre
    acc = np.zeros((h, w, 3), np.float32)
    rgb = img.convert("RGB")
    for s in np.linspace(1.0, 1.0 + strength, steps):
        acc += np.asarray(rgb.transform((w, h), Image.AFFINE, (1 / s, 0, cx - cx / s, 0, 1 / s, cy - cy / s), Image.BICUBIC)).astype(np.float32)
    acc /= steps
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.hypot((xx - cx) / w, (yy - cy) / w)
    weight = np.clip((d - clear_radius) / 0.35, 0, 1)[..., None]
    base = np.asarray(rgb).astype(np.float32)
    return Image.fromarray(np.clip(base * (1 - weight) + acc * weight, 0, 255).astype(np.uint8)).convert("RGBA")


def finish(canvas, bloom_from=205, grain=3.0):
    """Sunlit film look: highlights bloom, edges soften, corners darken a little, fine grain."""
    w, h = canvas.size
    pixels = np.asarray(canvas.convert("RGB")).astype(np.float32)
    bright = np.clip(pixels - bloom_from, 0, 255)
    bloom = np.asarray(Image.fromarray(bright.astype(np.uint8)).filter(ImageFilter.GaussianBlur(w / 70))).astype(np.float32)
    pixels += bloom * 0.9
    image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
    pixels = np.asarray(image).astype(np.float32)
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)) / 1.414
    pixels *= (1 - np.clip((edge - 0.45) / 0.55, 0, 1) ** 1.6 * 0.38)[..., None]
    pixels += np.random.default_rng(5).normal(0, grain, (h, w))[..., None]
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).convert("RGBA")


def sky_gradient(size, horizon_y, top, mid, low):
    """Sky from `top` down through `mid` to a pale hazy `low` at the horizon."""
    w, h = size
    img = np.zeros((h, w, 3), np.float32)
    ys = np.arange(h, dtype=np.float32)
    t = np.clip(ys / max(horizon_y, 1), 0, 1)
    for c in range(3):
        col = np.where(t < 0.55, top[c] + (mid[c] - top[c]) * (t / 0.55), mid[c] + (low[c] - mid[c]) * ((t - 0.55) / 0.45))
        img[:, :, c] = col[:, None]
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert("RGBA")


def clouds(img, horizon_y, seed, amount=0.55, tint=(255, 250, 240), shade=(176, 186, 206)):
    """Soft, flat-bottomed afternoon clouds stretched across the sky."""
    w, h = img.size
    rng = np.random.default_rng(seed)
    small = rng.random((max(h // 70, 3), max(w // 260, 3))).astype(np.float32)
    n = np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float32) / 255
    n2 = noise(w, h, 40, seed + 4)
    cover = np.clip((n * 0.8 + n2 * 0.25 - (1 - amount)) * 4.0, 0, 1)
    ys = np.arange(h, dtype=np.float32)[:, None]
    fade = np.clip((horizon_y - ys) / (horizon_y * 0.9), 0, 1) ** 0.6 * np.clip(ys / 40, 0, 1)
    cover *= fade
    lit = np.clip(1.0 - n2 * 0.9, 0, 1)[..., None]
    cloud_rgb = np.array(shade, np.float32) * (1 - lit) + np.array(tint, np.float32) * lit
    out = np.asarray(img.convert("RGB")).astype(np.float32)
    out = out * (1 - cover[..., None] * 0.9) + cloud_rgb * cover[..., None] * 0.9
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).convert("RGBA")


# ---------------------------------------------------------------- the dashboard and phone pictures


def cluster_texture():
    """The scooter's little dashboard: speed, fuel, clock."""
    img = Image.new("RGBA", (400, 200), (10, 14, 20, 255))
    d = ImageDraw.Draw(img)
    _fit(d, (150, 92), "48", 200, 120, (214, 244, 255, 255))
    _fit(d, (150, 160), "km/h", 140, 40, (140, 190, 220, 255), FONT_BOLD)
    d.rectangle((290, 40, 380, 62), outline=(214, 244, 255, 255), width=3)
    d.rectangle((294, 44, 350, 58), fill=(255, 190, 60, 255))
    _fit(d, (335, 110), "3:42", 100, 44, (214, 244, 255, 255), FONT_BOLD)
    d.ellipse((300, 140, 316, 156), fill=(70, 220, 110, 255))
    d.ellipse((330, 140, 346, 156), fill=(70, 220, 110, 255))
    return img


def phone_texture():
    """A delivery rider's phone on the handlebar: a message from Gwen over the map."""
    img = Image.new("RGBA", (180, 340), (236, 240, 232, 255))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 180, 54), fill=(232, 70, 140, 255))
    _fit(d, (90, 28), "HULING BIYAHE", 150, 24, (255, 255, 255, 255), FONT_BOLD)
    for i in range(5):
        d.line((0, 80 + i * 44, 180, 100 + i * 44), fill=(200, 206, 196, 255), width=6)
    d.line((30, 340, 150, 90), fill=(255, 255, 255, 255), width=10)
    d.ellipse((72, 180, 108, 216), fill=(232, 70, 140, 255))
    d.rounded_rectangle((10, 60, 170, 120), radius=10, fill=(255, 255, 255, 245), outline=(180, 180, 180, 255), width=2)
    _fit(d, (90, 80), "Gwen", 140, 22, (40, 40, 48, 255))
    _fit(d, (90, 104), "umuwi ka nang maaga", 150, 17, (80, 80, 90, 255), FONT_BOLD)
    d.rectangle((0, 296, 180, 340), fill=(40, 44, 56, 255))
    _fit(d, (90, 318), "ETA 3:55 PM", 150, 22, (255, 255, 255, 255), FONT_BOLD)
    return img



# ---------------------------------------------------------------- frame 1: the skyway


HAZE = (240, 218, 192)


def _hazed(color, k):
    return tuple(int(c * (1 - k) + h * k) for c, h in zip(color, HAZE))


def manila_skyline(img, horizon_y, vp_x, seed):
    """Layers of Manila on the horizon, each hazier the further it is: far glass towers, a middle
    layer of mid-rise blocks with a Gothic church spire (a steel spire like San Sebastian's) and
    water tanks, and a nearer layer of low roofs in rust, blue and green."""
    out_w, out_h = img.size
    scale = 1672.0 / out_w   # everything below is drawn for a 1672-wide picture, then brought down
    w, h = 1672, int(out_h * scale)
    horizon_y, vp_x = horizon_y * scale, vp_x * scale
    rng = np.random.default_rng(seed)
    big = img.resize((w, h))
    d = ImageDraw.Draw(big)
    horizon_y, vp_x = int(horizon_y), int(vp_x)

    def blocks(x0, x1, base, hmin, hmax, wmin, wmax, color, windows, antenna=0.2):
        x = x0
        while x < x1:
            bw, bh = int(rng.integers(wmin, wmax)), int(rng.integers(hmin, hmax))
            d.rectangle((x, base - bh, x + bw, base + 400), fill=color)
            d.rectangle((x, base - bh, x + bw, base - bh + max(bh // 28, 2)), fill=tuple(min(255, c + 14) for c in color))
            if windows:
                step = max(int(bw / 5), 4)
                for wy in range(base - bh + 8, base, step + 3):
                    d.line((x + 2, wy, x + bw - 2, wy), fill=tuple(max(0, c - 16) for c in color), width=1)
            if rng.random() < antenna:
                d.line((x + bw // 2, base - bh, x + bw // 2, base - bh - int(rng.integers(14, 40))), fill=color, width=2)
            x += bw + int(rng.integers(0, 5))

    # Far towers: a cluster of tall glass towers a little right of the vanishing point, low blocks around.
    far = _hazed((96, 120, 160), 0.46)
    blocks(0, w, horizon_y + 6, 22, 130, 14, 38, far, True)
    tints = [(96, 124, 168), (120, 130, 150), (84, 110, 150), (132, 120, 128)]
    for i, (dx, hh, ww) in enumerate(((-60, 300, 52), (10, 440, 44), (74, 250, 60), (150, 390, 42), (214, 280, 56), (290, 350, 46), (352, 220, 58), (-150, 210, 50))):
        x = int(vp_x + dx * 1.15)
        color = _hazed(tints[i % len(tints)], 0.46)
        top = horizon_y + 6 - hh
        d.rectangle((x, top, x + ww, horizon_y + 400), fill=color)
        d.rectangle((x + 5, top - 14, x + ww - 5, top), fill=color)               # a setback at the roof
        d.rectangle((x + ww // 2 - 3, top - 36, x + ww // 2 + 3, top - 14), fill=color)
        d.line((x + ww // 2, top - 36, x + ww // 2, top - 70), fill=color, width=2)
        for wy in range(top + 8, horizon_y, 9):
            d.line((x + 2, wy, x + ww - 2, wy), fill=_hazed((178, 196, 224), 0.46), width=1)
        for wx in range(x + 8, x + ww - 4, 10):
            d.line((wx, top + 4, wx, horizon_y), fill=tuple(max(0, c - 18) for c in color), width=1)
    # Middle layer: mid-rise blocks and the church, warmer.
    mid = _hazed((122, 112, 124), 0.3)
    blocks(0, w, horizon_y + 34, 50, 190, 36, 96, mid, True, 0.1)
    cx = int(vp_x - 430)
    base = horizon_y + 34
    church = _hazed((104, 98, 112), 0.26)
    d.rectangle((cx - 70, base - 150, cx + 70, base + 300), fill=church)
    for tx in (-62, 62):
        d.rectangle((cx + tx - 14, base - 230, cx + tx + 14, base), fill=church)
        d.polygon([(cx + tx - 17, base - 230), (cx + tx + 17, base - 230), (cx + tx, base - 300)], fill=church)
    d.polygon([(cx - 22, base - 150), (cx + 22, base - 150), (cx + 4, base - 420), (cx - 4, base - 420)], fill=church)   # the tall steel spire
    d.line((cx, base - 420, cx, base - 450), fill=church, width=3)
    d.line((cx - 7, base - 438, cx + 7, base - 438), fill=church, width=3)
    d.ellipse((cx - 16, base - 120, cx + 16, base - 88), fill=_hazed((196, 176, 140), 0.4))   # the rose window
    for wx in range(-50, 51, 25):
        d.polygon([(cx + wx - 6, base - 40), (cx + wx + 6, base - 40), (cx + wx + 6, base - 76), (cx + wx, base - 88), (cx + wx - 6, base - 76)], fill=_hazed((70, 66, 84), 0.4))
    # Water tanks and a billboard on the middle roofs.
    for tx in (int(vp_x - 140), int(vp_x + 360), int(vp_x + 640)):
        d.rectangle((tx, base - 74, tx + 22, base - 40), fill=mid)
        d.line((tx + 3, base - 40, tx + 3, base - 30), fill=mid, width=2)
        d.line((tx + 19, base - 40, tx + 19, base - 30), fill=mid, width=2)
    bx = int(vp_x + 480)
    d.rectangle((bx, base - 130, bx + 150, base - 70), fill=_hazed((214, 70, 60), 0.4))
    d.rectangle((bx + 70, base - 70, bx + 78, base), fill=mid)
    out = big.filter(ImageFilter.GaussianBlur(0.9))
    # A warm veil of haze rising from the ground.
    arr = np.asarray(out.convert("RGB")).astype(np.float32)
    ys = np.arange(h, dtype=np.float32)[:, None]
    veil = np.clip(1.0 - np.abs(ys - horizon_y) / 110.0, 0, 1) ** 1.5 * 0.22
    arr = arr * (1 - veil[..., None]) + np.array(HAZE, np.float32) * veil[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA").resize((out_w, out_h), Image.LANCZOS)


def exit_sign_texture():
    """The big green gantry sign: Philippine expressway style, white border and letters."""
    img = Image.new("RGBA", (1400, 520), (18, 104, 66, 255))
    d = ImageDraw.Draw(img)
    d.rectangle((14, 14, 1385, 505), outline=(250, 250, 250, 255), width=10)
    _fit(d, (480, 150), "SAMPALOC", 800, 150, (255, 255, 255, 255))
    _fit(d, (480, 300), "ESPAÑA", 800, 130, (255, 255, 255, 255))
    _fit(d, (480, 430), "NAGTAHAN  •  QUIAPO", 800, 70, (255, 244, 180, 255), FONT_BOLD)
    d.rectangle((1020, 70, 1360, 270), fill=(255, 255, 255, 255))
    d.polygon([(1190, 90), (1340, 190), (1060, 190)], fill=(18, 104, 66, 255))
    d.rectangle((1160, 190, 1220, 250), fill=(18, 104, 66, 255))
    _fit(d, (1190, 400), "500 m", 300, 100, (255, 255, 255, 255))
    return img


def vehicle_rear(w, h, body, stripe, seed):
    """The back of a bus or van for a far vehicle: body, a dark window band, tail lights and a plate."""
    img = Image.new("RGBA", (w, h), body + (255,))
    d = ImageDraw.Draw(img)
    d.rectangle((int(w * 0.07), int(h * 0.12), int(w * 0.93), int(h * 0.46)), fill=(30, 36, 48, 255))
    d.rectangle((0, int(h * 0.56), w, int(h * 0.64)), fill=stripe + (255,))
    for x in (int(w * 0.1), int(w * 0.82)):
        d.rectangle((x, int(h * 0.7), x + int(w * 0.08), int(h * 0.8)), fill=(210, 30, 36, 255))
    d.rectangle((int(w * 0.4), int(h * 0.76), int(w * 0.6), int(h * 0.86)), fill=(240, 232, 200, 255))
    d.rectangle((0, int(h * 0.92), w, h), fill=(40, 40, 44, 255))
    return img


def build_skyway(size):
    w, h = size
    cam_x, cam_z = 0.8, -0.85
    camera = s3.Camera((cam_x, 0.3, cam_z), -33.0, 10.0, 74.0, size)
    vp = camera.project((cam_x, 0.3, 100000.0))
    horizon_y, vp_x = int(vp[1]), int(vp[0])

    # ---- the backdrop: sky, clouds, Manila, and plain road colour below the horizon
    back = sky_gradient(size, horizon_y, (88, 142, 212), (160, 196, 232), (244, 226, 200))
    back = clouds(back, horizon_y, 11)
    back = manila_skyline(back, horizon_y, vp_x, 4)
    arr = np.asarray(back.convert("RGB")).astype(np.float32)
    ground = np.zeros_like(arr)
    ys = np.arange(h, dtype=np.float32)
    t = np.clip((ys - horizon_y) / max(h - horizon_y, 1), 0, 1) ** 0.6
    for c, (far_c, near_c) in enumerate(((176, 84), (166, 84), (156, 90))):
        ground[:, :, c] = (far_c + (near_c - far_c) * t)[:, None]
    mask = (ys >= horizon_y + 160)[:, None, None].astype(np.float32)   # only well below the horizon; the roofs sit above
    blend = np.clip((ys - horizon_y - 44 * w / 1672) / (40 * w / 1672), 0, 1)[:, None, None]
    arr = arr * (1 - blend) + ground * blend
    back = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")

    # ---- the roadway: lanes, joints, barriers, lamps, the exit gantry and far traffic
    env = s3.Scene(camera, ambient=(150, 156, 174))
    env.light((-700, 900, -900), (255, 226, 184), 1.15e6)
    road_x0, road_x1 = -3.7, 8.6
    # The asphalt: strips along the road, each starting just where it comes into view, so the
    # nearest tarmac is drawn too (a face with a corner behind the camera is skipped).
    xs_edges = np.linspace(road_x0, road_x1, 13)
    for si in range(len(xs_edges) - 1):
        xa, xb = xs_edges[si], xs_edges[si + 1]
        z_start = -3.0
        while z_start < 400 and min(camera.view((x, 0.0, z_start))[2] for x in (xa, xb)) < 0.3:
            z_start += 0.25
        marks = [z_start] + [z for z in (z_start + 2.0, z_start + 7.0, 14.0, 40.0, 120.0, 400.0) if z > z_start]
        for zi in range(len(marks) - 1):
            env.face([(xa, 0.0, marks[zi + 1]), (xb, 0.0, marks[zi + 1]), (xb, 0.0, marks[zi]), (xa, 0.0, marks[zi])], (110, 110, 118),
                     texture=asphalt(300, 300 if marks[zi + 1] - marks[zi] < 20 else 700, si * 5 + zi), layer=0, two_sided=True)
    for lane_x in (1.75, 5.15):
        z = 0.5
        while z < 200:
            env.face([(lane_x - 0.09, 0.004, z + 3.0), (lane_x + 0.09, 0.004, z + 3.0), (lane_x + 0.09, 0.004, z), (lane_x - 0.09, 0.004, z)],
                     (246, 244, 236), layer=1, two_sided=True)
            z += 9.0
    for z in range(2, 260, 14):   # the dark seams of the expansion joints
        env.face([(road_x0, 0.002, z + 0.12), (road_x1, 0.002, z + 0.12), (road_x1, 0.002, z), (road_x0, 0.002, z)], (40, 40, 46), layer=1, two_sided=True)
    for x_edge in (-3.4, 8.35):
        env.face([(x_edge - 0.06, 0.003, 400), (x_edge + 0.06, 0.003, 400), (x_edge + 0.06, 0.003, 0.3), (x_edge - 0.06, 0.003, 0.3)], (232, 196, 60), layer=1, two_sided=True)
    # The concrete barriers, in panels so the grooves and the yellow reflectors repeat.
    for side_x, face_x in ((-3.7, -3.7), (8.6, 8.6)):
        z = -1.0
        panel = 0
        while z < 260:
            length = 6.0 if z < 60 else 14.0
            tone = (178, 174, 166) if panel % 2 == 0 else (170, 166, 158)
            sign = 1 if side_x < 0 else -1
            env.face([(face_x, 1.0, z + length), (face_x, 1.0, z), (face_x, 0.0, z), (face_x, 0.0, z + length)], tone,
                     texture=concrete(600, 300, 70 + panel % 5, tone, 3), layer=2, two_sided=True)
            env.face([(face_x, 1.0, z + length), (face_x + 0.35 * -sign, 1.0, z + length), (face_x + 0.35 * -sign, 1.0, z), (face_x, 1.0, z)], (196, 192, 184), layer=2, two_sided=True)
            env.face([(face_x - 0.02 * sign, 0.62, z + 0.7), (face_x - 0.02 * sign, 0.62, z + 0.4), (face_x - 0.02 * sign, 0.5, z + 0.4), (face_x - 0.02 * sign, 0.5, z + 0.7)],
                     (240, 190, 40), layer=3, two_sided=True)
            z += length
            panel += 1
    # Lamp posts along the left barrier, arms reaching over the road.
    for lz in range(18, 240, 30):
        tube(env, (-3.9, 0.9, lz), (-3.9, 9.0, lz), 0.22, (150, 154, 160), 3, 6)
        tube(env, (-3.9, 9.0, lz), (-0.6, 9.4, lz), 0.14, (150, 154, 160), 3, 4)
        env.box(-1.0, -0.2, 9.2, 9.45, lz - 0.3, lz + 0.3, (200, 204, 208), layer=3)
    # The green exit gantry across the road.
    gz = 76.0
    for gx in (-3.9, 8.8):
        tube(env, (gx, 0.9, gz), (gx, 6.8, gz), 0.45, (130, 134, 140), 3, 6)
    tube(env, (-3.9, 6.6, gz), (8.8, 6.6, gz), 0.35, (130, 134, 140), 3, 6)
    env.face([(0.4, 6.4, gz - 0.2), (6.9, 6.4, gz - 0.2), (6.9, 4.1, gz - 0.2), (0.4, 4.1, gz - 0.2)], (20, 110, 70), texture=exit_sign_texture(), layer=4, two_sided=True)
    # Far traffic: a bus in the middle lane and a van beyond.
    for (vx, vz, vw, vh, body, stripe) in ((3.45, 46.0, 2.5, 3.4, (232, 232, 226), (200, 40, 44)), (6.85, 31.0, 1.9, 2.0, (240, 240, 240), (40, 90, 170)),
                                         (0.0, 120.0, 2.2, 3.0, (210, 60, 52), (240, 240, 240))):
        env.face([(vx - vw / 2, vh, vz), (vx + vw / 2, vh, vz), (vx + vw / 2, 0.15, vz), (vx - vw / 2, 0.15, vz)], body,
                 texture=vehicle_rear(300, int(300 * vh / vw), body, stripe, 1), layer=3, two_sided=True)
        env.box(vx - vw / 2, vx + vw / 2, 0.15, vh, vz, vz + 6.0, body, layer=3, skip=("front",))
    scene_bg = env.render(back)
    # The camera rides with the bike: the road and barrier streak towards the vanishing point.
    scene_bg = radial_blur(scene_bg, (vp_x, horizon_y), 0.1, 18, 0.22)
    scene_bg = contact_shadow(scene_bg, camera, 0.0, -0.45, 150, 0.95)

    wheel_pass = s3.Scene(camera, ambient=(150, 156, 174))
    wheel_pass.light((-700, 900, -900), (255, 226, 184), 1.15e6)
    bp.wheel(wheel_pass, 0.0, 0.0, side=1)
    bp.wheel(wheel_pass, 0.0, -1.25, side=1, front=False)
    bp.scooter_body(wheel_pass, show_leg=False)
    bp.steering(wheel_pass, 6)
    bp.rider(wheel_pass)
    return wheel_pass.render(scene_bg)


def draw_skyway(size=SIZE):
    return finish(build_skyway(size))



# ---------------------------------------------------------------- frame 3: the market


def road_strips(env, camera, x0, x1, make_texture, tint=(120, 118, 122), count=12):
    """A road drawn as strips along its length, each starting where it first comes into view (a face with a
    corner behind the camera is skipped), so the ground reaches right up to the lens."""
    xs = np.linspace(x0, x1, count + 1)
    for si in range(count):
        xa, xb = xs[si], xs[si + 1]
        z_start = -3.0
        while z_start < 100 and min(camera.view((x, 0.0, z_start))[2] for x in (xa, xb)) < 0.3:
            z_start += 0.25
        marks = [z_start] + [z for z in (z_start + 2.0, z_start + 7.0, 16.0, 40.0, 100.0) if z > z_start]
        for zi in range(len(marks) - 1):
            env.face([(xa, 0.0, marks[zi + 1]), (xb, 0.0, marks[zi + 1]), (xb, 0.0, marks[zi]), (xa, 0.0, marks[zi])], tint,
                     texture=make_texture(si * 5 + zi), layer=0, two_sided=True)


SHOP_FRONTS = [
    ("SARI-SARI STORE", (224, 190, 140), (190, 40, 44)),
    ("BOTIKA", (152, 196, 176), (30, 100, 70)),
    ("LOAD  •  GCASH", (214, 150, 130), (250, 244, 220)),
    ("KARINDERYA", (232, 214, 160), (160, 50, 40)),
    ("TAHIAN", (190, 200, 214), (40, 70, 130)),
    ("LECHON MANOK", (236, 180, 120), (110, 40, 30)),
]


def shop_front_texture(index):
    """A shophouse seen from the street: painted wall, windows with grills, a signboard and a roll-up shutter."""
    name, wall, ink = SHOP_FRONTS[index % len(SHOP_FRONTS)]
    img = concrete(900, 640, 90 + index, wall)
    d = ImageDraw.Draw(img)
    for x in (80, 380, 680):
        d.rectangle((x, 40, x + 150, 180), fill=(48, 56, 66, 255))
        for gx in range(x, x + 151, 25):
            d.line((gx, 40, gx, 180), fill=(190, 190, 196, 255), width=3)
        d.line((x, 110, x + 150, 110), fill=(190, 190, 196, 255), width=3)
    d.rectangle((40, 210, 860, 300), fill=ink + (255,))
    d.rectangle((40, 210, 860, 300), outline=(250, 250, 244, 255), width=5)
    _fit(d, (450, 255), name, 780, 74, (252, 248, 236, 255) if sum(ink) < 500 else (40, 30, 24, 255))
    d.rectangle((60, 330, 840, 640), fill=(140, 146, 154, 255))
    for ry in range(332, 640, 14):
        d.line((60, ry, 840, ry), fill=(112, 118, 126, 255), width=3)
    d.rectangle((60, 330, 840, 640), outline=(80, 84, 90, 255), width=5)
    d.rectangle((560, 330, 840, 640), fill=(60, 52, 44, 255))   # the open part of the shop
    d.rectangle((580, 350, 820, 470), fill=(226, 200, 150, 255))
    return img


def umbrella(env, cx, cz, radius, y_rim, y_top, colors, layer=3, sides=8):
    """A big market umbrella seen from underneath and the side: striped triangles round a pole."""
    for i in range(sides):
        a0, a1 = 2 * math.pi * i / sides, 2 * math.pi * (i + 1) / sides
        pts = [(cx, y_top, cz), (cx + radius * math.cos(a0), y_rim, cz + radius * math.sin(a0)), (cx + radius * math.cos(a1), y_rim, cz + radius * math.sin(a1))]
        env.face(pts, colors[i % len(colors)], layer=layer, two_sided=True)
    tube(env, (cx, 0.0, cz), (cx, y_top, cz), 0.06, (150, 126, 96), layer, 6)


def bunting(env, z, x0, x1, y, sag, count, colors, seed):
    """A string of paper flags across the street (banderitas), sagging in the middle."""
    rng = np.random.default_rng(seed)
    for i in range(count):
        t0, t1 = i / count, (i + 0.7) / count
        xa, xb = x0 + (x1 - x0) * t0, x0 + (x1 - x0) * t1
        ya = y - sag * (1 - (t0 * 2 - 1) ** 2)
        yb = y - sag * (1 - (t1 * 2 - 1) ** 2)
        env.face([(xa, ya, z), (xb, yb, z), ((xa + xb) / 2, min(ya, yb) - 0.36, z)], colors[int(rng.integers(0, len(colors)))], layer=4, two_sided=True)
    pts = [(x0 + (x1 - x0) * t, y - sag * (1 - (t * 2 - 1) ** 2), z) for t in np.linspace(0, 1, 12)]
    for a, b in zip(pts, pts[1:]):
        tube(env, a, b, 0.012, (70, 60, 50), 4, 4)


def entrance_banner_texture():
    img = Image.new("RGBA", (1800, 420), (196, 34, 40, 255))
    d = ImageDraw.Draw(img)
    d.rectangle((16, 16, 1783, 403), outline=(252, 224, 120, 255), width=10)
    _fit(d, (900, 190), "PALENGKE", 1500, 240, (255, 246, 214, 255))
    _fit(d, (900, 345), "Sampaloc  •  Bukas araw-araw  •  Sariwa at mura", 1500, 66, (252, 224, 120, 255), FONT_BOLD)
    return img


STALL_KINDS = ["veg", "fish", "fruit", "meat", "rice", "veg", "cooked", "fish", "fruit", "veg", "meat", "rice"]
BOARDS = {
    "veg": (("GULAY", "Sariwa! Mura!"), (40, 130, 70), (255, 250, 220)),
    "fish": (("ISDA", "Bagong huli  •  ₱180/kilo"), (30, 100, 170), (255, 255, 255)),
    "fruit": (("PRUTAS", "Saging  •  Mangga  •  Pakwan"), (232, 160, 40), (60, 20, 10)),
    "meat": (("KARNE", "Baboy  •  Baka  •  Manok"), (190, 36, 44), (255, 244, 220)),
    "rice": (("BIGAS", "Dinorado ₱56  •  Sinandomeng ₱48"), (236, 220, 170), (110, 40, 20)),
    "cooked": (("ISAW • BETAMAX", "₱10 isa"), (60, 60, 66), (255, 214, 70)),
}
STALL_BUILD = {"veg": mp.veg_stall, "fish": mp.fish_stall, "fruit": mp.fruit_stall, "meat": mp.meat_stall, "rice": mp.rice_stall, "cooked": mp.cooked_stall}


def market_fill(env, k):
    """Everything that makes the street a palengke: a row of stalls on each side with their goods, sign boards,
    vendors and shoppers, tarpaulin roofs, tangled wires, a parked jeepney, plastic crates and litter."""
    rng = np.random.default_rng(31)
    street_x1 = 4.4
    # Walls behind the stalls.
    env.face([(-4.5, 4.4, 80), (-4.5, 4.4, 2.0), (-4.5, 0.0, 2.0), (-4.5, 0.0, 80)], (170, 150, 128), texture=concrete(900, 400, 55, (176, 160, 140)), layer=1, two_sided=True)
    z = 2.0
    for i in range(12):
        env.face([(street_x1 + 0.1, 5.4, z + 6.0), (street_x1 + 0.1, 5.4, z), (street_x1 + 0.1, 0.0, z), (street_x1 + 0.1, 0.0, z + 6.0)], (200, 190, 170),
                 texture=shop_front_texture(i), layer=1, two_sided=True)
        z += 6.0
    # The stalls, left and right, in blocks with gaps for the cross lanes.
    blocks = [(2.6, 5.2), (6.0, 9.0), (9.8, 12.4), (13.2, 16.6), (17.4, 20.0), (20.8, 24.0), (24.8, 27.6), (28.4, 31.8), (32.6, 35.4)]
    for bi, (z0, z1) in enumerate(blocks):
        for side in (-1, 1):
            kind = STALL_KINDS[(bi * 2 + (0 if side < 0 else 1)) % len(STALL_KINDS)]
            if side < 0:
                x0, x1 = -3.9, -2.45
            else:
                x0, x1 = 2.45, 3.9
            STALL_BUILD[kind](env, x0, x1, z0, z1, rng)
            (name, line), bg_col, fg = BOARDS[kind]
            bx = x1 if side < 0 else x0
            tex = mp.sign_board((name, line), bg_col, fg)
            env.face([(bx, 2.6, z0 + 0.05), (bx, 2.6, z1 - 0.05), (bx, 2.15, z1 - 0.05), (bx, 2.15, z0 + 0.05)], bg_col, texture=tex, layer=5, two_sided=True)
            for pz in (z0 + 0.05, z1 - 0.05):
                bp.limb(env, (bx + side * 0.05, 0.0, pz), (bx + side * 0.05, 3.2, pz), 0.07, 0.07, (140, 108, 78), 4, n=8)
            # Hand-lettered price cards in front of the goods.
            if kind in ("veg", "fruit", "fish"):
                for pi, texts in enumerate(((("KAMATIS", "₱80"), ("TALONG", "₱70")) if kind == "veg" else ((("SAGING", "₱60"), ("MANGGA", "₱120")) if kind == "fruit" else (("BANGUS", "₱180"), ("TILAPIA", "₱140"))))):
                    pz = z0 + 0.4 + pi * (z1 - z0 - 0.8)
                    env.face([(bx - side * 0.0, 1.0, pz - 0.14), (bx - side * 0.0, 1.0, pz + 0.14), (bx - side * 0.0, 0.84, pz + 0.14), (bx - side * 0.0, 0.84, pz - 0.14)], (250, 248, 238),
                             texture=mp.price_card(texts), layer=5, two_sided=True)
            # A vendor behind each table, and sometimes a customer at the front.
            vx = x0 + 0.15 if side < 0 else x1 - 0.15
            mp.person(env, vx - side * 0.5, (z0 + z1) / 2 - 0.2, 90 * side * -1, rng, 1.6, 3, "vendor", False)
            if rng.random() < 0.8:
                mp.person(env, side * 1.75, (z0 + z1) / 2 + rng.uniform(-0.6, 0.6), -90 * side * -1 + 180 * (1 if side > 0 else 0), rng, 1.62, 3, "shopper", False)
        # Tarpaulin roofs over each block, one colour per stall, a little apart so light and wires show.
        tarp_colors = [((40, 96, 190), (40, 96, 190)), ((238, 142, 48), (238, 142, 48)), ((62, 150, 92), (62, 150, 92)), ((226, 56, 54), (244, 240, 232)), ((246, 214, 70), (246, 214, 70))]
        for side in (-1, 1):
            c0, c1 = tarp_colors[(bi + (0 if side < 0 else 2)) % len(tarp_colors)]
            xa, xb = (-4.3, -1.2) if side < 0 else (1.2, 4.3)
            mp.tarp(env, xa, xb, z0 - 0.3, z1 + 0.3, 3.5 + 0.1 * (bi % 3), c0, 6, 0.28, (c0, c1) if c0 != c1 else None)
    # Shoppers and workers in the aisle itself, a boy with a sack, a parked jeepney, wires and clutter.
    walkers = [(0.95, 3.4, 0), (-1.1, 5.4, 180), (1.15, 7.6, 180), (-0.95, 10.2, 0), (0.9, 12.8, 180), (-1.2, 14.6, 0), (1.0, 17.2, 0), (-0.9, 19.8, 180),
               (1.2, 22.4, 180), (-1.1, 25.0, 0), (0.95, 28.0, 180), (-0.9, 30.4, 0), (0.3, 34.0, 180), (-0.4, 37.0, 0)]
    for wx, wz, wy in walkers:
        mp.person(env, wx, wz, wy, rng, rng.uniform(1.5, 1.72), 4, "shopper", True)
    mp.boy_with_sack(env, -1.3, 4.4, 0, rng, 4)
    mp.jeepney(env, 1.9, 36.0, 41.0)
    for wz in (6.0, 13.0, 21.0, 29.0):
        mp.wire_bundle(env, -4.4, 4.4, wz, 4.7, 0.5, 6, rng)
    for wz in (4.0, 11.0, 19.0, 27.0, 35.0):   # stacks of plastic crates in the aisle edge
        for ci in range(3):
            col = [(214, 60, 56), (50, 110, 190), (240, 200, 60)][ci]
            env.box(-2.35, -2.0, ci * 0.28, ci * 0.28 + 0.26, wz, wz + 0.45, col, layer=3)
    mp.litter(env, rng, -2.2, 2.2, 1.5, 36.0)
    tube(env, (-4.3, 0.0, 41.0), (-4.3, 6.6, 41.0), 0.22, (120, 96, 70), 4, 8)
    tube(env, (4.3, 0.0, 41.0), (4.3, 6.6, 41.0), 0.22, (120, 96, 70), 4, 8)
    env.face([(-4.2, 6.3, 40.9), (4.2, 6.3, 40.9), (4.2, 4.7, 40.9), (-4.2, 4.7, 40.9)], (196, 34, 40), texture=entrance_banner_texture(), layer=5, two_sided=True)


def build_market(size):
    w, h = size
    cam_x, cam_y, cam_z = -0.62, 1.8, -1.78
    camera = s3.Camera((cam_x, cam_y, cam_z), 21.0, -16.0, 66.0, size)
    vp = camera.project((cam_x, cam_y, 100000.0))
    horizon_y, vp_x = int(vp[1]), int(vp[0])
    k = w / 1672.0

    # ---- the backdrop: a hot, hazy sky with the afternoon sun low at the end of the street, and a crowd
    back = sky_gradient(size, horizon_y, (110, 162, 214), (190, 212, 224), (240, 224, 196))
    back = clouds(back, horizon_y, 23, 0.4)
    arr = np.asarray(back.convert("RGB")).astype(np.float32)
    ground = np.zeros_like(arr)
    ys = np.arange(h, dtype=np.float32)
    t = np.clip((ys - horizon_y) / max(h - horizon_y, 1), 0, 1) ** 0.6
    for c, (far_c, near_c) in enumerate(((236, 120), (214, 114), (170, 104))):
        ground[:, :, c] = (far_c + (near_c - far_c) * t)[:, None]
    blend = np.clip((ys - horizon_y + 2) / 8.0, 0, 1)[:, None, None]
    arr = arr * (1 - blend) + ground * blend
    back = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")
    crowd = Image.new("RGBA", size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(crowd)
    rng = np.random.default_rng(8)
    palette = [(200, 60, 60), (60, 110, 190), (240, 200, 70), (70, 160, 100), (236, 236, 230), (214, 120, 60), (150, 80, 150)]
    for _ in range(150):
        px = vp_x + rng.normal(0, 150 * k)
        bw = rng.uniform(10, 24) * k
        bh = rng.uniform(34, 62) * k
        py = horizon_y + rng.uniform(-6, 18) * k
        cd.ellipse((px - bw / 2, py - bh, px + bw / 2, py), fill=palette[int(rng.integers(0, len(palette)))] + (230,))
        cd.ellipse((px - bw / 3, py - bh - bw * 0.5, px + bw / 3, py - bh + bw * 0.4), fill=(112, 80, 62, 235))
    back.alpha_composite(crowd.filter(ImageFilter.GaussianBlur(3 * k)))
    back = s3.add_glow(back, (vp_x, horizon_y - 40 * k), (255, 214, 140), w * 0.22, 0.8)

    # ---- the street
    env = s3.Scene(camera, ambient=(150, 146, 156))
    env.light((500, 520, 1400), (255, 214, 156), 1.2e6)
    street_x0, street_x1 = -4.4, 4.4
    road_strips(env, camera, street_x0, street_x1, lambda i: concrete(300, 300, 30 + i, (178, 170, 158)))
    for gx in (-3.4, 3.1):   # gutters along both sides
        env.face([(gx - 0.18, 0.004, 120), (gx + 0.18, 0.004, 120), (gx + 0.18, 0.004, 1.0), (gx - 0.18, 0.004, 1.0)], (104, 98, 92), layer=1, two_sided=True)
    for px_, pz_, pw, pd in ((0.5, 2.2, 0.9, 1.1), (-1.6, 5.4, 1.4, 0.8), (1.6, 8.0, 1.1, 1.3), (-0.8, 13.0, 1.8, 1.0)):   # puddles shining the sky
        pts = [(px_ + pw * math.cos(t_), 0.006, pz_ + pd * math.sin(t_)) for t_ in np.linspace(0, 2 * math.pi, 18)]
        env.face(pts, (206, 222, 236), layer=1, two_sided=True, emissive=True)
    # Street litter: a manhole cover, a drain grate, and scattered vegetable leaves from the stalls.
    env.face([(-1.2 + 0.42 * math.cos(t_), 0.005, 3.4 + 0.42 * math.sin(t_)) for t_ in np.linspace(0, 2 * math.pi, 20)], (70, 66, 64), layer=1, two_sided=True)
    env.face([(-1.2 + 0.3 * math.cos(t_), 0.006, 3.4 + 0.3 * math.sin(t_)) for t_ in np.linspace(0, 2 * math.pi, 20)], (92, 88, 84), layer=1, two_sided=True)
    lrng = np.random.default_rng(12)
    for _ in range(26):
        lx, lz = lrng.uniform(-3.0, 2.4), lrng.uniform(1.2, 9.0)
        ang, ln, wd = lrng.uniform(0, math.pi), lrng.uniform(0.18, 0.34), lrng.uniform(0.07, 0.12)
        dx, dz = math.cos(ang) * ln / 2, math.sin(ang) * ln / 2
        px_, pz_ = -math.sin(ang) * wd / 2, math.cos(ang) * wd / 2
        tone = [(78, 150, 70), (112, 170, 70), (214, 160, 60), (190, 60, 46)][int(lrng.integers(0, 4))]
        env.face([(lx - dx, 0.007, lz - dz), (lx + px_, 0.007, lz + pz_), (lx + dx, 0.007, lz + dz), (lx - px_, 0.007, lz - pz_)], tone, layer=1, two_sided=True)
    market_fill(env, k)
    bg = env.render(back)
    # Shallow focus: everything past the wheel goes soft, the street's sun glare blooms.
    bg = bg.filter(ImageFilter.GaussianBlur(3.2 * k))

    chase = s3.Scene(camera, ambient=(176, 170, 180))
    chase.light((500, 520, 1400), (255, 214, 156), 1.2e6)
    chase.light((-600, 900, -1200), (255, 238, 220), 6.0e5)   # soft light from behind and to the left
    bp.wheel(chase, 0.0, 0.0, side=1)
    bp.wheel(chase, 0.0, -1.25, side=1, front=False)
    bp.scooter_body(chase, show_leg=False)
    bp.steering(chase, 6, cluster=cluster_texture(), phone=phone_texture())
    bp.rider(chase)
    out = chase.render(bg)
    return out


def draw_market(size=SIZE):
    return finish(build_market(size), bloom_from=190)


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "skyway"
    out = sys.argv[2] if len(sys.argv) > 2 else f"{which}_preview.png"
    size = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else SIZE
    picture = {"skyway": draw_skyway, "market": draw_market}.get(which)
    if picture is None:
        raise SystemExit("unknown frame: " + which)
    picture(size).convert("RGB").save(out)
    print("saved", out)
