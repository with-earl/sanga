"""Things that fill a Philippine public market (palengke) in 3D, for the third Tokhang intro frame: people
(vendors, shoppers, a boy with a sack), stalls (vegetables, fish on ice, hanging meat, fruit, rice sacks,
dried fish, cooked food), overhead tarpaulins, price signs, a parked jeepney, tangled wires and the clutter
on the wet floor. Built from the shapes in bike_parts.py (loft, ellipsoid, limb); no game art.

Facing: yaw 0 looks along +z (deeper into the market), yaw 180 looks back at the camera.
"""

import math

import numpy as np
from PIL import Image, ImageDraw

import bike_parts as bp
from tv_store import FONT_BLACK, FONT_BOLD, _fit

SKINS = [(182, 132, 98), (160, 112, 82), (198, 150, 114), (142, 98, 72), (170, 122, 90)]
SHIRTS = [(214, 62, 56), (60, 110, 190), (236, 206, 80), (70, 160, 104), (240, 240, 232), (232, 130, 60), (150, 80, 160), (40, 44, 60), (226, 120, 150)]
PANTS = [(40, 48, 76), (30, 30, 34), (86, 76, 60), (60, 90, 120), (120, 40, 50)]
HAIRS = [(22, 18, 16), (36, 26, 20), (60, 44, 34), (30, 30, 34)]


def _place(x, z, yaw_deg):
    a = math.radians(yaw_deg)
    ca, sa = math.cos(a), math.sin(a)

    def to_world(lx, ly, lz):
        return (x + lx * ca + lz * sa, ly, z - lx * sa + lz * ca)

    return to_world


def person(scene, x, z, yaw, rng, height=1.62, layer=3, role="shopper", walking=True):
    """A standing figure: shoes, trousers, a shirt (a vendor wears an apron and a cap), a head with hair,
    arms that swing or hold a bag, and for a shopper often a reusable bag in one hand."""
    s = height / 1.62
    P = _place(x, z, yaw)
    skin = SKINS[int(rng.integers(0, len(SKINS)))]
    shirt = SHIRTS[int(rng.integers(0, len(SHIRTS)))]
    pants = PANTS[int(rng.integers(0, len(PANTS)))]
    hair = HAIRS[int(rng.integers(0, len(HAIRS)))]
    swing = 0.1 if walking else 0.0
    # Legs and shoes.
    for sgn, ph in ((-1, 1), (1, -1)):
        hip = P(sgn * 0.09, 0.9 * s, 0.0)
        knee = P(sgn * 0.095, 0.5 * s, ph * swing * 0.5)
        ankle = P(sgn * 0.095, 0.08 * s, ph * swing)
        bp.limb(scene, hip, knee, 0.075 * s, 0.058 * s, pants, layer, n=10)
        bp.limb(scene, knee, ankle, 0.058 * s, 0.04 * s, pants, layer, n=10)
        bp.ellipsoid(scene, P(sgn * 0.095, 0.035 * s, ph * swing + 0.05), (0.05 * s, 0.035 * s, 0.1 * s), (30, 30, 34) if role == "vendor" else (210, 210, 214), layer, n=10, m=5)
    # Torso.
    rings = [bp.ring_points(P(0, y * s, 0), (math.cos(math.radians(yaw)), 0, -math.sin(math.radians(yaw))), (math.sin(math.radians(yaw)), 0, math.cos(math.radians(yaw))), rx * s, rz * s, 14, 0.85)
             for y, rx, rz in ((0.88, 0.17, 0.1), (1.1, 0.185, 0.115), (1.3, 0.2, 0.12), (1.42, 0.215, 0.105))]
    bp.loft(scene, rings, shirt, layer, caps=(True, False))
    if role == "vendor":   # an apron over the front, tied with a string
        apron = (236, 236, 228) if rng.random() < 0.5 else (60, 110, 190)
        front = [P(-0.15 * s, 1.24 * s, 0.125 * s), P(0.15 * s, 1.24 * s, 0.125 * s), P(0.17 * s, 0.78 * s, 0.12 * s), P(-0.17 * s, 0.78 * s, 0.12 * s)]
        scene.face(front, apron, layer=layer + 1, two_sided=True)
    # Neck, head, hair, ears.
    bp.limb(scene, P(0, 1.4 * s, 0), P(0, 1.5 * s, 0), 0.045 * s, 0.042 * s, skin, layer, n=8)
    bp.ellipsoid(scene, P(0, 1.57 * s, 0.0), (0.085 * s, 0.108 * s, 0.1 * s), skin, layer, n=12, m=8)
    bp.ellipsoid(scene, P(0, 1.6 * s, -0.012 * s), (0.092 * s, 0.1 * s, 0.1 * s), hair, layer + 1, n=12, m=6, e=0.9)
    bp.ellipsoid(scene, P(0, 1.55 * s, 0.092 * s), (0.016 * s, 0.022 * s, 0.02 * s), tuple(int(c * 0.9) for c in skin), layer + 1, n=6, m=4)   # nose
    if role == "vendor" and rng.random() < 0.7:   # a cap with a short peak
        cap_color = SHIRTS[int(rng.integers(0, len(SHIRTS)))]
        bp.ellipsoid(scene, P(0, 1.63 * s, 0.0), (0.098 * s, 0.07 * s, 0.108 * s), cap_color, layer + 2, n=12, m=6, e=0.9)
        bp.ellipsoid(scene, P(0, 1.6 * s, 0.1 * s), (0.08 * s, 0.01 * s, 0.07 * s), cap_color, layer + 2, n=10, m=4)
    # Arms, with an eco bag or a plastic bag for some shoppers.
    carries = role == "shopper" and rng.random() < 0.6
    for sgn in (-1, 1):
        shoulder = P(sgn * 0.225 * s, 1.38 * s, 0.0)
        bend = 0.1 * (-sgn) * swing / 0.1
        elbow = P(sgn * 0.26 * s, 1.1 * s, bend * 0.8)
        wrist = P(sgn * 0.26 * s, 0.84 * s, bend * 1.2)
        bp.limb(scene, shoulder, elbow, 0.055 * s, 0.045 * s, shirt, layer, n=10)
        bp.limb(scene, elbow, wrist, 0.045 * s, 0.035 * s, skin, layer, n=10)
        bp.joint(scene, wrist, 0.035 * s, skin, layer, 8, 5)
        if carries and sgn == 1:
            bag = (232, 232, 224) if rng.random() < 0.5 else SHIRTS[int(rng.integers(0, len(SHIRTS)))]
            bp.ellipsoid(scene, P(sgn * 0.27 * s, 0.7 * s, bend * 1.2), (0.09 * s, 0.14 * s, 0.07 * s), bag, layer + 1, n=10, m=6, e=0.9)


def boy_with_sack(scene, x, z, yaw, rng, layer=3):
    """A young helper bent under a rice sack on his shoulder, in shorts and a vest."""
    P = _place(x, z, yaw)
    person(scene, x, z, yaw, rng, 1.35, layer, "vendor", True)
    bp.ellipsoid(scene, P(0.06, 1.5, -0.1), (0.16, 0.17, 0.3), (226, 214, 180), layer + 2, n=12, m=7, e=0.8)


# ---------------------------------------------------------------- stalls and goods


def _table(scene, x0, x1, z0, z1, top=0.78, layer=2, cloth=None):
    """A wooden table on legs with an optional cloth thrown over the top."""
    scene.box(x0, x1, top - 0.04, top, z0, z1, (176, 138, 98), layer=layer)
    for lx, lz in ((x0 + 0.05, z0 + 0.05), (x1 - 0.05, z0 + 0.05), (x0 + 0.05, z1 - 0.05), (x1 - 0.05, z1 - 0.05)):
        scene.box(lx - 0.03, lx + 0.03, 0.0, top - 0.04, lz - 0.03, lz + 0.03, (122, 92, 66), layer=layer)
    if cloth:
        scene.box(x0 - 0.02, x1 + 0.02, top, top + 0.01, z0 - 0.02, z1 + 0.02, cloth, layer=layer)


def veg_stall(scene, x0, x1, z0, z1, rng, layer=3):
    """Vegetables heaped in baskets and basins: tomatoes, eggplants, ampalaya, carrots, cabbages, onions."""
    _table(scene, x0, x1, z0, z1, 0.74, layer - 1, (214, 196, 150))
    colors = [((214, 56, 46), 0.05), ((92, 46, 120), 0.06), ((86, 150, 70), 0.055), ((236, 138, 50), 0.045), ((170, 206, 120), 0.09), ((232, 204, 160), 0.05)]
    n_bins = max(int((z1 - z0) / 0.55), 2)
    for bi in range(n_bins):
        bz = z0 + (bi + 0.5) * (z1 - z0) / n_bins
        bx = (x0 + x1) / 2
        basin = (60, 110, 180) if bi % 2 == 0 else (230, 90, 70)
        bp.ellipsoid(scene, (bx, 0.84, bz), ((x1 - x0) * 0.46, 0.1, (z1 - z0) / n_bins * 0.45), basin, layer, n=12, m=5, e=0.8)
        col, r = colors[(bi + int(rng.integers(0, 6))) % len(colors)]
        for _ in range(9):
            ox = rng.uniform(-(x1 - x0) * 0.32, (x1 - x0) * 0.32)
            oz = rng.uniform(-0.2, 0.2)
            bp.ellipsoid(scene, (bx + ox, 0.95 + rng.uniform(0, 0.07), bz + oz), (r, r * 0.9, r), col, layer + 1, n=8, m=5)
    # A hand scale hangs from the awning pole with a pan below.
    pole_x = x1 if x1 > 0 else x0
    bp.limb(scene, (pole_x, 0.0, z0 + 0.1), (pole_x, 2.4, z0 + 0.1), 0.03, 0.03, (150, 118, 86), layer, n=8)


def fish_stall(scene, x0, x1, z0, z1, rng, layer=3):
    """Fish laid on crushed ice in blue basins: silver bangus, dark tilapia, and a hanging scale."""
    _table(scene, x0, x1, z0, z1, 0.76, layer - 1, (236, 244, 250))
    n_bins = max(int((z1 - z0) / 0.6), 2)
    for bi in range(n_bins):
        bz = z0 + (bi + 0.5) * (z1 - z0) / n_bins
        bx = (x0 + x1) / 2
        bp.ellipsoid(scene, (bx, 0.82, bz), ((x1 - x0) * 0.46, 0.06, (z1 - z0) / n_bins * 0.45), (60, 120, 190), layer, n=12, m=4, e=0.8)
        bp.ellipsoid(scene, (bx, 0.87, bz), ((x1 - x0) * 0.4, 0.03, (z1 - z0) / n_bins * 0.38), (236, 246, 252), layer + 1, n=12, m=4, e=0.8)   # the ice
        for k in range(5):
            fz = bz + (k - 2) * 0.09
            tone = (186, 198, 210) if (bi + k) % 2 == 0 else (92, 100, 112)
            bp.ellipsoid(scene, (bx + rng.uniform(-0.08, 0.08), 0.92, fz), (0.14, 0.035, 0.04), tone, layer + 2, n=10, m=5)
    bp.limb(scene, (x1 if x1 > 0 else x0, 0.0, z0 + 0.1), (x1 if x1 > 0 else x0, 2.4, z0 + 0.1), 0.03, 0.03, (150, 118, 86), layer, n=8)


def meat_stall(scene, x0, x1, z0, z1, rng, layer=3):
    """A butcher's table with a chopping block and cuts of pork and beef hanging from hooks on a rail."""
    _table(scene, x0, x1, z0, z1, 0.8, layer - 1, (230, 226, 218))
    scene.box((x0 + x1) / 2 - 0.2, (x0 + x1) / 2 + 0.2, 0.8, 0.9, (z0 + z1) / 2 - 0.2, (z0 + z1) / 2 + 0.2, (170, 126, 84), layer=layer)   # block
    rail_x = x1 if x1 > 0 else x0
    bp.limb(scene, (rail_x, 2.05, z0), (rail_x, 2.05, z1), 0.02, 0.02, (176, 180, 186), layer, n=8, bulge=1.0)
    for k in range(5):
        hz = z0 + 0.2 + k * (z1 - z0 - 0.4) / 4
        bp.limb(scene, (rail_x, 2.05, hz), (rail_x, 1.8, hz), 0.006, 0.006, (176, 180, 186), layer, n=6, bulge=1.0)
        tone = (222, 120, 124) if k % 2 == 0 else (178, 52, 56)
        bp.ellipsoid(scene, (rail_x, 1.55, hz), (0.08, 0.26, 0.07), tone, layer + 1, n=10, m=6, e=0.85)
    for k in range(4):   # trays of cut meat on the table
        bp.ellipsoid(scene, ((x0 + x1) / 2 + rng.uniform(-0.2, 0.2), 0.86, z0 + 0.25 + k * 0.4), (0.2, 0.05, 0.14), (200, 70, 76), layer, n=10, m=4, e=0.8)


def fruit_stall(scene, x0, x1, z0, z1, rng, layer=3):
    """Bananas hung in bunches, pyramids of mangoes and oranges, watermelons and pineapples."""
    _table(scene, x0, x1, z0, z1, 0.72, layer - 1, (210, 190, 140))
    rail_x = x1 if x1 > 0 else x0
    bp.limb(scene, (rail_x, 2.1, z0), (rail_x, 2.1, z1), 0.02, 0.02, (150, 118, 86), layer, n=8, bulge=1.0)
    for k in range(4):   # banana bunches
        hz = z0 + 0.25 + k * (z1 - z0 - 0.5) / 3
        for j in range(5):
            bp.limb(scene, (rail_x, 2.08, hz + (j - 2) * 0.03), (rail_x - np.sign(rail_x) * 0.04, 1.62, hz + (j - 2) * 0.05), 0.026, 0.02, (236, 206, 70), layer + 1, n=6)
    for k in range(4):
        fz = z0 + 0.25 + k * (z1 - z0 - 0.5) / 3
        kind = k % 3
        if kind == 0:
            for j in range(6):
                bp.ellipsoid(scene, ((x0 + x1) / 2 + rng.uniform(-0.1, 0.1), 0.8 + 0.04 * (j // 3), fz + rng.uniform(-0.1, 0.1)), (0.055, 0.05, 0.055), (240, 188, 60), layer + 1, n=8, m=5)
        elif kind == 1:
            bp.ellipsoid(scene, ((x0 + x1) / 2, 0.88, fz), (0.18, 0.15, 0.18), (60, 130, 70), layer + 1, n=12, m=7)
        else:
            bp.ellipsoid(scene, ((x0 + x1) / 2, 0.86, fz), (0.08, 0.13, 0.08), (214, 168, 56), layer + 1, n=8, m=6)
            bp.ellipsoid(scene, ((x0 + x1) / 2, 1.02, fz), (0.07, 0.07, 0.07), (70, 140, 60), layer + 1, n=8, m=4, e=0.6)


def rice_stall(scene, x0, x1, z0, z1, rng, layer=3):
    """Open sacks of rice with a scoop, and bundles of dried fish in a hanging net."""
    n = max(int((z1 - z0) / 0.55), 2)
    for k in range(n):
        sz = z0 + (k + 0.5) * (z1 - z0) / n
        sx = (x0 + x1) / 2
        bp.ellipsoid(scene, (sx, 0.32, sz), (0.24, 0.32, 0.2), (222, 208, 172) if k % 2 == 0 else (206, 190, 150), layer, n=12, m=7, e=0.7)
        bp.ellipsoid(scene, (sx, 0.62, sz), (0.2, 0.05, 0.16), (246, 240, 224), layer + 1, n=12, m=4, e=0.8)
    scene.box(x0, x1, 0.0, 0.7, z0 - 0.02, z0, (186, 146, 100), layer=layer - 1)


def cooked_stall(scene, x0, x1, z0, z1, rng, layer=3):
    """A cart with a charcoal grill and skewers, a steaming pot and a plastic stool for customers."""
    _table(scene, x0, x1, z0, z1, 0.8, layer - 1, (60, 60, 66))
    bp.ellipsoid(scene, ((x0 + x1) / 2, 0.92, (z0 + z1) / 2), (0.2, 0.1, 0.34), (46, 44, 44), layer, n=12, m=5, e=0.7)
    for k in range(8):
        bp.limb(scene, ((x0 + x1) / 2 - 0.15, 1.02, z0 + 0.15 + k * 0.07), ((x0 + x1) / 2 + 0.15, 1.02, z0 + 0.15 + k * 0.07), 0.008, 0.008, (170, 130, 90), layer + 1, n=5, bulge=1.0)
    bp.ellipsoid(scene, ((x0 + x1) / 2 + 0.05, 1.12, z1 - 0.2), (0.1, 0.1, 0.1), (190, 194, 200), layer + 1, n=10, m=5)
    for sx, sz in ((x0 - 0.35, z0 + 0.3), (x0 - 0.35, z1 - 0.3)):   # plastic stools
        bp.limb(scene, (sx, 0.0, sz), (sx, 0.42, sz), 0.2, 0.17, (214, 60, 60), layer, n=10)
        bp.ellipsoid(scene, (sx, 0.43, sz), (0.2, 0.025, 0.2), (226, 76, 76), layer, n=10, m=4)


def price_card(texts):
    """A hand-lettered price sign: white card, red numbers, black name."""
    name, price = texts
    img = Image.new("RGBA", (220, 130), (250, 248, 238, 255))
    d = ImageDraw.Draw(img)
    d.rectangle((3, 3, 216, 126), outline=(190, 40, 44, 255), width=4)
    _fit(d, (110, 40), name, 190, 44, (30, 30, 36, 255), FONT_BLACK)
    _fit(d, (110, 92), price, 190, 54, (190, 28, 34, 255), FONT_BLACK)
    return img


def sign_board(texts, bg, fg):
    """A painted board over a stall: a big word and a smaller line."""
    big, small = texts
    img = Image.new("RGBA", (800, 260), bg + (255,))
    d = ImageDraw.Draw(img)
    d.rectangle((10, 10, 789, 249), outline=(255, 255, 255, 255), width=8)
    _fit(d, (400, 120), big, 700, 140, fg + (255,))
    _fit(d, (400, 215), small, 700, 52, fg + (255,), FONT_BOLD)
    return img


# ---------------------------------------------------------------- over the market


def tarp(scene, x0, x1, z0, z1, y, color, layer=6, sag=0.25, stripes=None):
    """A tarpaulin roof stretched between poles, sagging to a dip in the middle, optionally striped."""
    steps = 4
    for i in range(steps):
        for j in range(steps):
            xa, xb = x0 + (x1 - x0) * i / steps, x0 + (x1 - x0) * (i + 1) / steps
            za, zb = z0 + (z1 - z0) * j / steps, z0 + (z1 - z0) * (j + 1) / steps

            def h(xx, zz):
                u, v = (xx - x0) / (x1 - x0) * 2 - 1, (zz - z0) / (z1 - z0) * 2 - 1
                return y - sag * (1 - u * u) * (1 - v * v)

            col = stripes[(i + j) % 2] if stripes else color
            scene.face([(xa, h(xa, za), za), (xb, h(xb, za), za), (xb, h(xb, zb), zb), (xa, h(xa, zb), zb)], col, layer=layer, two_sided=True)


def wire_bundle(scene, x0, x1, z, y, sag, count, rng, layer=7):
    """Tangled electric and cable wires strung across the street between two poles."""
    for k in range(count):
        yy = y + rng.uniform(-0.25, 0.25)
        dz = rng.uniform(-0.3, 0.3)
        pts = [(x0 + (x1 - x0) * t, yy - sag * (1 - (t * 2 - 1) ** 2) * rng.uniform(0.8, 1.2), z + dz * t) for t in np.linspace(0, 1, 9)]
        bp.curve_tube(scene, pts, 0.006, (22, 22, 26), layer, 5)


def jeepney(scene, x, z0, z1, layer=3):
    """A parked jeepney seen from its side and back: a bright painted body with stripes, a rack of sacks on the roof,
    chrome trim and a destination board. Its long side faces the aisle (-x)."""
    length = z1 - z0
    body = (214, 52, 56)
    scene.box(x, x + 1.6, 0.45, 1.65, z0, z1, body, layer=layer)
    scene.box(x, x + 1.6, 1.65, 1.78, z0 - 0.02, z1 + 0.02, (236, 236, 232), layer=layer)   # roof
    side = Image.new("RGBA", (1400, 380), body + (255,))
    d = ImageDraw.Draw(side)
    d.rectangle((0, 130, 1400, 150), fill=(250, 214, 60, 255))
    d.rectangle((0, 160, 1400, 176), fill=(40, 90, 190, 255))
    for wx in range(120, 1300, 300):   # windows
        d.rectangle((wx, 40, wx + 240, 120), fill=(40, 52, 70, 255))
    d.rectangle((0, 240, 1400, 270), fill=(244, 244, 238, 255))
    _fit(d, (700, 322), "SAMPALOC  •  QUIAPO  •  DIVISORIA", 1200, 60, (255, 240, 200, 255), FONT_BLACK)
    scene.face([(x - 0.001, 1.65, z1), (x - 0.001, 1.65, z0), (x - 0.001, 0.45, z0), (x - 0.001, 0.45, z1)], body, texture=side, layer=layer + 1, two_sided=True)
    back = Image.new("RGBA", (500, 400), body + (255,))
    bd = ImageDraw.Draw(back)
    bd.rectangle((0, 0, 500, 60), fill=(250, 214, 60, 255))
    bd.rectangle((120, 90, 380, 220), fill=(30, 36, 50, 255))
    _fit(bd, (250, 320), "DIOS ANG BAHALA", 440, 54, (255, 240, 200, 255), FONT_BLACK)
    scene.face([(x, 1.65, z0 - 0.002), (x + 1.6, 1.65, z0 - 0.002), (x + 1.6, 0.45, z0 - 0.002), (x, 0.45, z0 - 0.002)], body, texture=back, layer=layer + 1, two_sided=True)
    for wz in (z0 + 0.7, z1 - 0.7):
        for sgn in (0.0, 1.6):
            bp.limb(scene, (x + sgn, 0.3, wz - 0.26), (x + sgn, 0.3, wz + 0.26), 0.3, 0.3, (30, 30, 34), layer, n=14, bulge=1.0)
    for k in range(3):   # sacks on the roof rack
        bp.ellipsoid(scene, (x + 0.8, 2.0, z0 + 0.8 + k * 0.9), (0.3, 0.22, 0.34), (224, 210, 176), layer, n=10, m=6, e=0.75)


def litter(scene, rng, x0, x1, z0, z1, layer=1):
    """Cardboard sheets, plastic bags, a banana leaf and wet footprints scattered on the floor."""
    for _ in range(18):
        lx, lz = rng.uniform(x0, x1), rng.uniform(z0, z1)
        ang, ln, wd = rng.uniform(0, math.pi), rng.uniform(0.3, 0.7), rng.uniform(0.25, 0.5)
        dx, dz = math.cos(ang) * ln / 2, math.sin(ang) * ln / 2
        px, pz = -math.sin(ang) * wd / 2, math.cos(ang) * wd / 2
        tone = [(176, 140, 96), (150, 118, 80), (92, 150, 70)][int(rng.integers(0, 3))]
        scene.face([(lx - dx - px, 0.008, lz - dz - pz), (lx + dx - px, 0.008, lz + dz - pz), (lx + dx + px, 0.008, lz + dz + pz), (lx - dx + px, 0.008, lz - dz + pz)], tone, layer=layer, two_sided=True)
    for _ in range(10):
        lx, lz = rng.uniform(x0, x1), rng.uniform(z0, z1)
        bp.ellipsoid(scene, (lx, 0.04, lz), (0.07, 0.04, 0.06), (236, 236, 232) if rng.random() < 0.6 else (230, 90, 80), layer + 1, n=7, m=4)
