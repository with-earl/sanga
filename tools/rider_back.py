"""A delivery rider seen from behind, drawn from scratch (not from any of the game's character art).

Pink helmet, black bomber jacket, a pink insulated delivery bag on his back, navy trousers and
sneakers. Every part is a flat shape that is turned into a soft solid: the shape's mask is blurred
into a height map, its slope gives a surface direction, and a sun from the upper right lights it
(with a shine on the helmet), so the rider has real roundness, not a flat cut-out. Parts that sit
in front of others cast soft contact shadows, and fabric gets folds and a fine weave.

Used by tv_store.py for the news scene. Run this file to look at the rider alone.
"""

import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter

WIDTH, HEIGHT = 600, 1400
SUPER = 2
SUN = np.array([0.55, 0.62, 0.56])
SUN = SUN / np.linalg.norm(SUN)

PINK = (232, 52, 132)
PINK_DARK = (150, 22, 84)
BLACK = (26, 26, 31)
NAVY = (34, 46, 92)
SKIN = (176, 124, 92)
HAIR = (16, 14, 18)
SOLE = (222, 220, 214)
SHOE = (58, 60, 68)


def _canvas():
    return Image.new("RGBA", (WIDTH * SUPER, HEIGHT * SUPER), (0, 0, 0, 0))


def _mask(draw_fn):
    """A mask drawn by `draw_fn(draw, s)`, where s scales design units to the big canvas."""
    img = Image.new("L", (WIDTH * SUPER, HEIGHT * SUPER), 0)
    draw_fn(ImageDraw.Draw(img), SUPER)
    return img


def _poly(points, smooth=0):
    def draw(d, s):
        d.polygon([(x * s, y * s) for x, y in points], fill=255)
    m = _mask(draw)
    return m.filter(ImageFilter.GaussianBlur(smooth * SUPER)).point(lambda v: 255 if v > 127 else 0) if smooth else m


def _ellipse(cx, cy, rx, ry, smooth=0):
    def draw(d, s):
        d.ellipse(((cx - rx) * s, (cy - ry) * s, (cx + rx) * s, (cy + ry) * s), fill=255)
    return _mask(draw)


def _round_rect(x0, y0, x1, y1, r):
    def draw(d, s):
        d.rounded_rectangle((x0 * s, y0 * s, x1 * s, y1 * s), r * s, fill=255)
    return _mask(draw)


def _union(*masks):
    out = masks[0]
    for m in masks[1:]:
        out = Image.fromarray(np.maximum(np.asarray(out), np.asarray(m)))
    return out


def _solid(mask, color, bulge=26.0, shine=0.0, glossy=18.0, ambient=0.42, fabric=0.035, seed=1, tint=None):
    """Colours a mask as a rounded solid: the blurred mask is a height map, its slope is the
    surface direction, and the sun lights it. Returns an RGBA layer."""
    m = np.asarray(mask).astype(np.float32) / 255.0
    height = gaussian_filter(m, bulge * SUPER / 2.0)
    gy, gx = np.gradient(height * bulge * 3.0)
    nx, ny, nz = -gx, gy, np.ones_like(gx)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / norm, ny / norm, nz / norm
    lambert = np.clip(nx * SUN[0] + ny * SUN[1] + nz * SUN[2], 0, 1)
    # Half-lambert: the shadow side still catches a little bounce light, so forms stay soft.
    lambert = (0.35 + 0.65 * lambert) ** 1.3
    light = ambient + (1.0 - ambient) * lambert
    base = np.array(color, np.float32)[None, None, :] / 255.0
    rng = np.random.default_rng(seed)
    weave = rng.normal(0, 1, m.shape).astype(np.float32)
    weave = np.asarray(Image.fromarray(((weave * 40) + 128).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32)
    weave = (weave - 128) / 128.0 * fabric
    rgb = base * (light[..., None] + weave[..., None])
    if tint is not None:
        rgb = rgb * np.array(tint, np.float32)[None, None, :]
    if shine > 0:
        half = SUN + np.array([0, 0, 1.0])
        half = half / np.linalg.norm(half)
        spec = np.clip(nx * half[0] + ny * half[1] + nz * half[2], 0, 1) ** glossy
        rgb = rgb + spec[..., None] * shine
    out = np.zeros(m.shape + (4,), np.float32)
    out[..., :3] = np.clip(rgb, 0, 1) * 255
    out[..., 3] = m * 255
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def _shadow_under(canvas, mask, dx, dy, blur, strength):
    """Darkens what is already drawn in the soft shape of `mask`, moved by (dx, dy): the shadow a
    part casts on the one behind it."""
    shifted = Image.new("L", mask.size, 0)
    shifted.paste(mask, (int(dx * SUPER), int(dy * SUPER)))
    soft = np.asarray(shifted.filter(ImageFilter.GaussianBlur(blur * SUPER))).astype(np.float32) / 255.0 * strength
    px = np.asarray(canvas).astype(np.float32)
    px[..., :3] *= (1.0 - soft)[..., None]
    return Image.fromarray(px.astype(np.uint8), "RGBA")


def _strokes(canvas, lines, color, width, blur, alpha, clip):
    """Fold lines in fabric: soft curved strokes inside `clip`."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for pts in lines:
        d.line([(x * SUPER, y * SUPER) for x, y in pts], fill=color + (255,), width=int(width * SUPER), joint="curve")
    layer = layer.filter(ImageFilter.GaussianBlur(blur * SUPER))
    a = np.asarray(layer.getchannel("A")).astype(np.float32) / 255.0 * alpha
    a *= np.asarray(clip).astype(np.float32) / 255.0
    px = np.asarray(canvas).astype(np.float32)
    px[..., :3] = px[..., :3] * (1 - a[..., None]) + np.array(color, np.float32) * a[..., None]
    return Image.fromarray(px.astype(np.uint8), "RGBA")


def _curve(p0, p1, p2, n=14):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in [i / n for i in range(n + 1)]]


def rider_back() -> Image.Image:
    """The rider, 600 x 1400, transparent around him, feet at the bottom. About 800 px to the
    metre, so he stands 1.75 m tall. Weight on his left leg, one hand in a pocket, head tipped up
    and a little to the left, towards the screens."""
    c = _canvas()

    # ---- legs: the left leg carries the weight, the right is relaxed and turned out
    left_leg = _poly([(158, 700), (300, 700), (296, 1000), (282, 1336), (178, 1336), (160, 1000)], smooth=7)
    right_leg = _poly([(300, 700), (446, 700), (462, 1004), (452, 1336), (338, 1336), (304, 1004)], smooth=7)
    for leg, seed in ((left_leg, 3), (right_leg, 4)):
        c.alpha_composite(_solid(leg, NAVY, bulge=56, ambient=0.36, seed=seed))
    legs = _union(left_leg, right_leg)
    c = _strokes(c, [_curve((172, 1010), (224, 1040), (286, 1012)), _curve((316, 1014), (386, 1048), (456, 1016)),
                     _curve((176, 1190), (224, 1204), (284, 1190)), _curve((344, 1190), (400, 1206), (452, 1192)),
                     _curve((180, 1090), (232, 1100), (288, 1086)), _curve((322, 1088), (388, 1104), (456, 1092))],
                 (12, 16, 36), 5, 3, 0.55, legs)
    c = _strokes(c, [_curve((232, 760), (226, 1050), (234, 1320)), _curve((372, 760), (384, 1050), (392, 1320))],
                 (12, 16, 36), 5, 8, 0.4, legs)
    c = _strokes(c, [_curve((196, 790), (210, 900), (200, 980)), _curve((420, 790), (404, 900), (420, 980))],
                 (92, 112, 170), 4, 6, 0.22, legs)
    c = _strokes(c, [[(190, 780), (254, 780), (252, 850), (192, 850), (190, 780)], [(346, 780), (410, 780), (408, 850), (348, 850), (346, 780)]],
                 (12, 16, 36), 3, 1.4, 0.5, legs)
    left_shoe = _union(_ellipse(222, 1372, 62, 40), _round_rect(176, 1330, 280, 1368, 20))
    right_shoe = _union(_ellipse(398, 1370, 64, 40), _round_rect(344, 1330, 456, 1366, 20))
    right_shoe = right_shoe.rotate(-9, center=(398 * SUPER, 1370 * SUPER), resample=Image.BICUBIC)
    for shoe, seed in ((left_shoe, 5), (right_shoe, 6)):
        c = _shadow_under(c, shoe, 0, -4, 6, 0.5)
        c.alpha_composite(_solid(shoe, SHOE, bulge=26, ambient=0.42, shine=0.14, seed=seed))
    for cx, tilt in ((222, 0), (398, -9)):
        sole = _round_rect(cx - 66, 1386, cx + 66, 1398, 5).rotate(tilt, center=(cx * SUPER, 1396 * SUPER), resample=Image.BICUBIC)
        c.alpha_composite(_solid(sole, SOLE, bulge=6, ambient=0.6, seed=7))
    for cx, w in ((230, 58), (398, 60)):
        cuff = _ellipse(cx, 1326, w, 15)
        c.alpha_composite(_solid(cuff, (24, 32, 66), bulge=8, ambient=0.5, seed=8))

    # ---- arms: the right hangs; the left is bent, its hand in the jacket pocket
    right_arm = _poly([(466, 318), (522, 352), (556, 520), (552, 690), (536, 760), (474, 760), (480, 690), (484, 540), (460, 400)], smooth=8)
    left_arm = _poly([(134, 322), (74, 358), (46, 500), (62, 590), (120, 654), (176, 676), (170, 610), (130, 556), (124, 440)], smooth=8)
    torso = _poly([(256, 280), (344, 280), (470, 322), (466, 470), (452, 640), (468, 724), (132, 724), (148, 640), (136, 470), (130, 318)], smooth=14)
    c = _shadow_under(c, torso, 0, 8, 12, 0.5)
    c.alpha_composite(_solid(right_arm, BLACK, bulge=40, ambient=0.28, fabric=0.05, seed=9))
    c.alpha_composite(_solid(left_arm, BLACK, bulge=40, ambient=0.28, fabric=0.05, seed=10))
    c.alpha_composite(_solid(torso, BLACK, bulge=70, ambient=0.28, fabric=0.05, seed=11))
    jacket = _union(torso, left_arm, right_arm)
    c = _strokes(c, [_curve((482, 540), (520, 558), (556, 534)), _curve((484, 612), (520, 628), (554, 606)),
                     _curve((46, 520), (84, 548), (62, 590)), _curve((72, 410), (60, 450), (50, 490)),
                     _curve((466, 330), (474, 400), (468, 470)), _curve((136, 330), (128, 400), (138, 470)),
                     _curve((470, 470), (452, 560), (440, 640)), _curve((130, 470), (146, 560), (158, 640))],
                 (140, 140, 156), 3, 3.0, 0.2, jacket)
    c = _strokes(c, [_curve((150, 680), (230, 696), (300, 684)), _curve((310, 684), (390, 698), (452, 678)),
                     _curve((460, 520), (440, 600), (456, 700)), _curve((140, 520), (160, 600), (146, 700))],
                 (4, 4, 6), 4, 2.4, 0.5, jacket)
    # Shoulder sheen: satin catches the sun on top of the shoulders.
    sheen = _union(_poly([(350, 296), (466, 326), (440, 350), (352, 316)], smooth=6))
    c = _strokes(c, [_curve((352, 300), (410, 306), (462, 328))], (170, 172, 190), 10, 6, 0.28, torso)
    hem = _round_rect(130, 690, 470, 730, 14)
    c.alpha_composite(_solid(hem, (20, 20, 25), bulge=12, ambient=0.3, fabric=0.08, seed=12))
    c = _strokes(c, [[(130 + i * 18, 696), (130 + i * 18, 726)] for i in range(1, 19)], (6, 6, 8), 2, 0.9, 0.5, hem)
    for x0, x1 in ((474, 538),):
        cuff = _round_rect(x0, 742, x1, 786, 12)
        c = _shadow_under(c, cuff, 0, 5, 5, 0.4)
        c.alpha_composite(_solid(cuff, (20, 20, 25), bulge=12, ambient=0.3, fabric=0.08, seed=13))
    # The hanging hand: a loose fist with the thumb along it.
    hand = _union(_ellipse(506, 836, 30, 56), _ellipse(520, 818, 14, 40), _ellipse(500, 892, 22, 26))
    c = _shadow_under(c, hand, 0, 6, 6, 0.3)
    c.alpha_composite(_solid(hand, SKIN, bulge=18, ambient=0.5, seed=15, fabric=0.02))
    c = _strokes(c, [_curve((486, 850), (506, 858), (526, 850)), _curve((488, 872), (506, 880), (524, 872))], (96, 62, 44), 3, 1.2, 0.6, hand)
    # The pocket: the left hand has gone in, the wrist showing at its edge.
    pocket = _poly([(120, 640), (196, 656), (190, 716), (126, 706)], smooth=4)
    c = _strokes(c, [[(122, 644), (194, 660)], [(190, 664), (186, 712)]], (4, 4, 6), 4, 1.6, 0.55, pocket)

    # ---- neck, collar, hair
    neck = _poly([(264, 214), (340, 214), (350, 300), (254, 300)], smooth=6)
    c.alpha_composite(_solid(neck, (152, 104, 78), bulge=26, ambient=0.42, seed=16, fabric=0.02))
    collar = _poly([(226, 280), (374, 280), (392, 336), (208, 336)], smooth=10)
    c = _shadow_under(c, collar, 0, 8, 6, 0.55)
    c.alpha_composite(_solid(collar, (22, 22, 27), bulge=24, ambient=0.3, fabric=0.07, seed=17))

    # ---- the delivery bag: a pink insulated pack with straps, a flap, a band and a zip
    for x0, x1, lean in ((170, 222, -5), (378, 430, 5)):
        strap = _poly([(x0, 306), (x1, 306), (x1 + lean, 420), (x0 + lean, 420)], smooth=3)
        c = _shadow_under(c, strap, 0, 5, 4, 0.5)
        c.alpha_composite(_solid(strap, (22, 22, 26), bulge=14, ambient=0.3, fabric=0.08, seed=18))
    for x0, x1 in ((126, 140), (460, 474)):
        side = _round_rect(x0, 420, x1, 540, 6)
        c.alpha_composite(_solid(side, (22, 22, 26), bulge=8, ambient=0.3, fabric=0.08, seed=28))
    bag = _round_rect(134, 340, 466, 748, 24)
    c = _shadow_under(c, bag, 8, 12, 14, 0.62)
    c.alpha_composite(_solid(bag, PINK, bulge=44, ambient=0.46, shine=0.2, glossy=10, fabric=0.03, seed=19))
    flap = _round_rect(134, 340, 466, 458, 24)
    c = _shadow_under(c, flap, 0, 8, 5, 0.38)
    c.alpha_composite(_solid(flap, (240, 74, 150), bulge=24, ambient=0.5, shine=0.22, glossy=10, seed=20))
    band = _round_rect(134, 588, 466, 624, 4)
    c.alpha_composite(_solid(band, (24, 24, 29), bulge=8, ambient=0.35, fabric=0.06, seed=21))
    c = _strokes(c, [[(134, 458), (466, 458)]], PINK_DARK, 4, 1.4, 0.8, bag)
    c = _strokes(c, [_curve((300, 340), (300, 400), (300, 458))], PINK_DARK, 3, 1.2, 0.6, bag)
    c = _strokes(c, [[(160, 748), (160, 340)], [(440, 340), (440, 748)]], PINK_DARK, 3, 4, 0.3, bag)
    c = _strokes(c, [_curve((150, 700), (300, 712), (450, 700))], PINK_DARK, 3, 1.6, 0.5, bag)
    tape = _round_rect(134, 664, 466, 678, 3)
    c.alpha_composite(_solid(tape, (214, 216, 220), bulge=5, ambient=0.7, shine=0.3, seed=22, fabric=0.01))
    handle = _round_rect(254, 322, 346, 346, 10)
    c.alpha_composite(_solid(handle, (20, 20, 25), bulge=8, ambient=0.3, seed=23))

    # ---- the helmet: glossy pink, tipped up and a little left, with a rim, a vent and a sticker
    hair = _poly([(246, 196), (354, 196), (346, 258), (254, 258)], smooth=10)
    c.alpha_composite(_solid(hair, HAIR, bulge=18, ambient=0.4, shine=0.12, glossy=6, seed=24, fabric=0.06))
    helmet = _union(_ellipse(300, 116, 112, 116), _round_rect(190, 120, 410, 214, 60))
    helmet = helmet.rotate(5, center=(300 * SUPER, 230 * SUPER), resample=Image.BICUBIC)
    c = _shadow_under(c, helmet, 4, 10, 9, 0.55)
    layer = _solid(helmet, PINK, bulge=64, ambient=0.34, shine=0.55, glossy=26, fabric=0.0, seed=25)
    c.alpha_composite(layer)
    # A reflected window and a soft sky band on the shell.
    window = _round_rect(318, 40, 388, 92, 8).rotate(5, center=(300 * SUPER, 230 * SUPER), resample=Image.BICUBIC)
    c = _strokes(c, [[(330, 56), (378, 66)]], (255, 235, 245), 18, 7, 0.55, window)
    c = _strokes(c, [_curve((210, 70), (290, 22), (384, 38))], (255, 200, 225), 10, 9, 0.28, helmet)
    # The helmet's lower edge: a thin dark rubber trim that follows the shell, not a bar across it.
    shell = _union(_ellipse(300, 116, 112, 116), _round_rect(190, 120, 410, 214, 60))
    trim = np.minimum(np.asarray(shell), 255 - np.asarray(Image.fromarray(np.asarray(shell)).transform(shell.size, Image.AFFINE, (1, 0, 0, 0, 1, 14 * SUPER), Image.BICUBIC)))
    trim = Image.fromarray(trim.astype(np.uint8)).rotate(5, center=(300 * SUPER, 230 * SUPER), resample=Image.BICUBIC)
    c.alpha_composite(_solid(trim, (30, 12, 24), bulge=6, ambient=0.4, shine=0.2, seed=26))
    vent = _round_rect(272, 34, 332, 138, 16).rotate(5, center=(300 * SUPER, 230 * SUPER), resample=Image.BICUBIC)
    c = _strokes(c, [[(286, 48), (288, 128)], [(302, 44), (304, 132)], [(318, 48), (320, 128)]], (100, 14, 58), 5, 1.4, 0.75, vent)
    sticker = _ellipse(364, 168, 15, 15)
    c.alpha_composite(_solid(sticker, (250, 250, 250), bulge=5, ambient=0.8, shine=0.3, seed=27, fabric=0.0))

    # ---- finish: a soft warm bounce from the pavement on the lower edge, then down to size
    px = np.asarray(c).astype(np.float32)
    ys = np.linspace(0, 1, px.shape[0])[:, None]
    bounce = np.clip((ys - 0.76) / 0.24, 0, 1) * 0.12
    px[..., :3] = px[..., :3] * (1 + bounce[..., None] * np.array([1.0, 0.7, 0.4]))
    out = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGBA")
    return out.resize((WIDTH, HEIGHT), Image.LANCZOS)


if __name__ == "__main__":
    rider = rider_back()
    sheet = Image.new("RGBA", rider.size, (186, 190, 196, 255))
    sheet.alpha_composite(rider)
    sheet.convert("RGB").save("rider_back_preview.png")
    print("saved rider_back_preview.png", rider.size)
