"""Parts for the intro pictures, built in 3D with scene3d: the shared parts of Peter's delivery scooter
(front wheel, fork, mudguard, steering, headlight, cowl, floorboard, side panels, seat) and Peter
himself seated on it (helmet, jacket, backpack, arms, gloves, a leg and a boot).

Everything is lofted from rings of points (`loft`, `ellipsoid`, `limb`) instead of boxes, with plenty of
facets, so the shapes read as round and smooth under the kit's flat shading.

The bike travels towards +z; the front axle stands at (0, 0.31, 0).
"""

import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import scene3d as s3  # noqa: F401  (kept so the module can be tried on its own)

PINK = (240, 44, 140)
PINK_DARK = (196, 30, 110)
JEANS, BOOT, JACKET = (46, 56, 92), (22, 22, 24), (26, 26, 30)
SKIN = (176, 126, 98)
SILVER, RUBBER = (200, 204, 210), (26, 26, 29)
WHEEL_R = 0.31


# ---------------------------------------------------------------- shapes made from rings


def _sgn_pow(v, e):
    return math.copysign(abs(v) ** e, v)


def ring_points(c, ax, ay, rx, ry, n=16, e=1.0):
    """A ring (a rounded rectangle when `e` is below 1) of `n` points round centre `c`, spanned by the
    unit vectors `ax` and `ay` with half-sizes `rx` and `ry`."""
    c, ax, ay = np.array(c, float), np.array(ax, float), np.array(ay, float)
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        out.append(c + ax * rx * _sgn_pow(math.cos(t), e) + ay * ry * _sgn_pow(math.sin(t), e))
    return out


def loft(scene, rings, color, layer, caps=(True, True), shade=None):
    """Skins a surface over consecutive rings of equal length. `shade(k, i)` may return a colour for each
    quad to give it a stripe or a panel line."""
    n = len(rings[0])
    for k in range(len(rings) - 1):
        for i in range(n):
            quad = [rings[k][i], rings[k][(i + 1) % n], rings[k + 1][(i + 1) % n], rings[k + 1][i]]
            col = color if shade is None else (shade(k, i) or color)
            scene.face(quad, col, layer=layer, two_sided=True)
    if caps[0]:
        scene.face(rings[0], color, layer=layer, two_sided=True)
    if caps[1]:
        scene.face(rings[-1], color, layer=layer, two_sided=True)


def ellipsoid(scene, c, radii, color, layer, n=18, m=10, e=1.0, shade=None, emissive=False):
    """A rounded solid at `c` with half-sizes `radii` (x, y, z). `e` below 1 squares it up."""
    cx, cy, cz = c
    rx, ry, rz = radii
    rings = []
    for k in range(m + 1):
        phi = math.pi * k / m
        s = max(math.sin(phi), 1e-3)
        rings.append(ring_points((cx, cy + ry * _sgn_pow(math.cos(phi), e), cz), (1, 0, 0), (0, 0, 1), rx * s, rz * s, n, e))
    if emissive:
        for k in range(m):
            for i in range(n):
                quad = [rings[k][i], rings[k][(i + 1) % n], rings[k + 1][(i + 1) % n], rings[k + 1][i]]
                scene.face(quad, color, layer=layer, two_sided=True, emissive=True)
    else:
        loft(scene, rings, color, layer, caps=(False, False), shade=shade)


def _frame(a, b):
    d = np.array(b, float) - np.array(a, float)
    d /= np.linalg.norm(d)
    up = np.array([0.0, 1.0, 0.0]) if abs(d[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = np.cross(d, up)
    u /= np.linalg.norm(u)
    return d, u, np.cross(d, u)


def limb(scene, a, b, ra, rb, color, layer, n=14, bulge=1.06, e=1.0, caps=True, shade=None):
    """A tapering round limb or bar from `a` to `b`, slightly fuller in the middle."""
    d, u, v = _frame(a, b)
    a, b = np.array(a, float), np.array(b, float)
    rings = [ring_points(a, u, v, ra, ra, n, e), ring_points((a + b) / 2, u, v, (ra + rb) / 2 * bulge, (ra + rb) / 2 * bulge, n, e),
             ring_points(b, u, v, rb, rb, n, e)]
    loft(scene, rings, color, layer, caps=(caps, caps), shade=shade)


def joint(scene, c, r, color, layer, n=12, m=6):
    ellipsoid(scene, c, (r, r, r), color, layer, n, m)


def curve_tube(scene, points, radius, color, layer, n=8):
    """A thin hose bent through `points`."""
    for a, b in zip(points, points[1:]):
        limb(scene, a, b, radius, radius, color, layer, n=n, bulge=1.0, caps=False)


def bezier(p0, p1, p2, steps=10):
    p0, p1, p2 = np.array(p0, float), np.array(p1, float), np.array(p2, float)
    return [(1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2 for t in np.linspace(0, 1, steps + 1)]


# ---------------------------------------------------------------- textures


def mirror_texture():
    """What a mirror shows: sky and road behind, soft."""
    img = Image.new("RGBA", (120, 70), (160, 196, 228, 255))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 42, 120, 70), fill=(92, 92, 98, 255))
    d.polygon([(60, 42), (46, 70), (74, 70)], fill=(210, 206, 196, 255))
    return img.filter(ImageFilter.GaussianBlur(2))


def lens_texture():
    img = Image.new("RGBA", (120, 90), (255, 248, 222, 255))
    d = ImageDraw.Draw(img)
    for r in (40, 30, 20):
        d.ellipse((60 - r, 45 - r * 0.8, 60 + r, 45 + r * 0.8), outline=(236, 224, 188, 255), width=3)
    return img


# ---------------------------------------------------------------- the front wheel


def wheel(scene, cx, cz, side=1, n=72, front=True):
    """A wire-spoked wheel standing at (cx, cz) like the delivery bike's: a black tyre with a ribbed tread, a
    chrome rim crossed by thin silver spokes, a silver drum hub; the front one has black telescopic forks, a
    black mudguard and a brake cable, the rear one has a chain sprocket (see rear_end). `side` is +1 when
    the camera is on the right of the bike and -1 on the left, so the near face is drawn over the far one."""
    R = WHEEL_R
    near, far = 3, 1

    def P(lx, ly, lz):
        return (cx + lx, R + ly, cz + lz)

    def ring_(r0, lx0, r1, lx1, color, layer, alt=None, count=n):
        ring(scene, P, r0, lx0, r1, lx1, color, layer, count, alt)

    rubber, groove = (34, 34, 37), (20, 20, 22)
    for sgn in (1, -1):
        layer = near if sgn == side else far
        # Tread blocks across the crown, shoulders, and a tall sidewall like a small-wheel underbone.
        ring_(0.31, sgn * 0.0, 0.31, sgn * 0.03, groove, 2, alt=(3, (50, 50, 54)))
        ring_(0.31, sgn * 0.03, 0.305, sgn * 0.044, groove, 2, alt=(2, (46, 46, 50)))
        ring_(0.305, sgn * 0.044, 0.292, sgn * 0.05, rubber, 2)
        ring_(0.292, sgn * 0.05, 0.215, sgn * 0.04, (38, 38, 42), layer)
        ring_(0.262, sgn * 0.0505, 0.254, sgn * 0.0495, (90, 90, 96), layer)   # the printed ring on the sidewall
        ring_(0.215, sgn * 0.04, 0.2, sgn * 0.034, (28, 28, 32), layer)
        ring_(0.2, sgn * 0.034, 0.186, sgn * 0.0, (218, 222, 228), layer)      # the chrome rim
    ring_(0.19, -0.034, 0.19, 0.034, (96, 98, 104), far)   # the barrel inside the rim
    # Wire spokes: thirty-six on each side, running from the hub flange to the rim in a cross-lacing.
    for sgn in (1, -1):
        layer = near if sgn == side else far
        for k in range(36):
            a_hub = 2 * math.pi * k / 36
            a_rim = a_hub + (0.34 if k % 2 == 0 else -0.34)
            hub = P(sgn * 0.042, 0.052 * math.cos(a_hub), 0.052 * math.sin(a_hub))
            rim = P(sgn * 0.004, 0.188 * math.cos(a_rim), 0.188 * math.sin(a_rim))
            limb(scene, hub, rim, 0.0045, 0.0045, (206, 210, 216), layer, n=4, bulge=1.0, caps=False)
    # The hub: a silver drum with cooling fins and a dark brake plate (front), or a plain drum (rear).
    hub_rings = [ring_points(P(lx, 0, 0), (0, 1, 0), (0, 0, 1), r, r, 20, 1.0) for lx, r in ((-0.05, 0.05), (-0.045, 0.082), (0.045, 0.082), (0.05, 0.05))]
    loft(scene, hub_rings, (176, 180, 186), near, caps=(True, True))
    for fx in (-0.03, -0.015, 0.0, 0.015, 0.03):
        loft(scene, [ring_points(P(fx, 0, 0), (0, 1, 0), (0, 0, 1), 0.086, 0.086, 20), ring_points(P(fx + 0.006, 0, 0), (0, 1, 0), (0, 0, 1), 0.086, 0.086, 20)], (130, 134, 140), near, caps=(False, False))
    if not front:
        rear_end(scene, P, side, near, far)
        return
    # The valve stem.
    limb(scene, P(side * 0.01, 0.186 * math.cos(0.9), 0.186 * math.sin(0.9)), P(side * 0.03, 0.15 * math.cos(0.9), 0.15 * math.sin(0.9)), 0.005, 0.004, (190, 194, 200), near + 1, n=6)
    # Telescopic forks: silver sliders from the axle, black upper tubes into the headstock; a brake arm and axle.
    for sgn in (1, -1):
        layer = near + 1 if sgn == side else far
        axle = P(sgn * 0.07, 0, 0)
        mid = P(sgn * 0.07, 0.34, -0.15)
        top = P(sgn * 0.08, 0.8, -0.37)
        limb(scene, axle, mid, 0.034, 0.03, (192, 196, 202), layer, n=14)
        limb(scene, mid, top, 0.028, 0.034, (22, 22, 26), layer, n=14)
        joint(scene, mid, 0.034, (160, 164, 170), layer, 12, 6)
    limb(scene, P(-0.1, 0, 0), P(0.1, 0, 0), 0.016, 0.016, (150, 154, 160), near + 1, n=10)
    joint(scene, P(side * 0.105, 0.0, 0.0), 0.022, (186, 190, 196), near + 1, 12, 6)
    limb(scene, P(0.052, 0.0, 0.0), P(0.07, 0.07, -0.14), 0.01, 0.01, (150, 154, 160), near + 1, n=6)   # the brake arm
    cable = bezier((0.4, 1.2, -0.52), (0.34, 0.8, -0.3), P(0.06, 0.05, -0.06), 12)
    curve_tube(scene, cable, 0.0045, (16, 16, 18), near, 5)
    # The mudguard: black and glossy with a silver stay.
    steps = 36
    for i in range(steps):
        t0, t1 = -0.95 + 2.25 * i / steps, -0.95 + 2.25 * (i + 1) / steps
        r = 0.338 + 0.012 * math.sin(math.pi * i / steps)
        sheet = [P(-0.07, r * math.cos(t0), r * math.sin(t0)), P(0.07, r * math.cos(t0), r * math.sin(t0)),
                 P(0.07, r * math.cos(t1), r * math.sin(t1)), P(-0.07, r * math.cos(t1), r * math.sin(t1))]
        scene.face(sheet, (26, 26, 30), layer=near + 1, two_sided=True)
        rib = [P(-0.01, (r + 0.004) * math.cos(t0), (r + 0.004) * math.sin(t0)), P(0.01, (r + 0.004) * math.cos(t0), (r + 0.004) * math.sin(t0)),
               P(0.01, (r + 0.004) * math.cos(t1), (r + 0.004) * math.sin(t1)), P(-0.01, (r + 0.004) * math.cos(t1), (r + 0.004) * math.sin(t1))]
        scene.face(rib, (70, 70, 78), layer=near + 1, two_sided=True)
        for sgn in (1, -1):
            flange = [P(sgn * 0.07, r * math.cos(t0), r * math.sin(t0)), P(sgn * 0.07, r * math.cos(t1), r * math.sin(t1)),
                      P(sgn * 0.07, (r - 0.03) * math.cos(t1), (r - 0.03) * math.sin(t1)), P(sgn * 0.07, (r - 0.03) * math.cos(t0), (r - 0.03) * math.sin(t0))]
            scene.face(flange, (20, 20, 24), layer=near + 1 if sgn == side else far, two_sided=True)


# ---------------------------------------------------------------- steering and the front of the body


def steering(scene, layer=6, glass=None, cluster=None, phone=None):
    """The handlebar end of the delivery bike: a black headlight cowl with a clear lens and orange indicators,
    a black legshield with a pink flash, a stem, a swept black bar with ribbed grips, silver levers, black
    switch gear, round black mirrors on stalks, the speedometer pod, and (optionally) a phone on the bar."""
    ellipsoid(scene, (0, 1.03, -0.3), (0.14, 0.1, 0.1), (24, 24, 28), layer - 2, n=22, m=12, e=0.8)
    ellipsoid(scene, (0, 1.03, -0.205), (0.1, 0.075, 0.03), (226, 232, 236), layer - 2, n=18, m=8)   # the lens, off in daylight
    for sgn in (-1, 1):
        ellipsoid(scene, (sgn * 0.17, 0.99, -0.32), (0.034, 0.026, 0.04), (255, 150, 30), layer - 2, n=10, m=6)   # indicators
    rings = [ring_points((0, y, z), (1, 0, 0), (0, 0, 1), rx, rz, 20, 0.75) for y, z, rx, rz in
             ((1.0, -0.42, 0.14, 0.1), (0.8, -0.46, 0.17, 0.09), (0.58, -0.52, 0.19, 0.075), (0.38, -0.56, 0.21, 0.07))]
    loft(scene, rings, (24, 24, 28), layer - 3, caps=(False, False))
    for sgn in (-1, 1):   # a hot-pink flash on each side of the legshield
        flash = [(-0.44, 0.98), (-0.5, 0.88), (-0.47, 0.8), (-0.54, 0.68), (-0.5, 0.64), (-0.56, 0.5), (-0.51, 0.62), (-0.52, 0.7), (-0.46, 0.76), (-0.47, 0.86)]
        scene.face([(sgn * 0.168, y, z) for z, y in flash], PINK, layer=layer - 2, two_sided=True)
    limb(scene, (0, 1.06, -0.36), (0, 1.2, -0.47), 0.036, 0.032, (30, 30, 34), layer - 1, n=14)
    ellipsoid(scene, (0, 1.2, -0.47), (0.08, 0.03, 0.05), (28, 28, 32), layer, n=14, m=6)
    # The bar: black, swept back, with ribbed grips and a ball-ended silver lever on each side.
    for sgn in (-1, 1):
        limb(scene, (0, 1.205, -0.47), (sgn * 0.3, 1.235, -0.6), 0.015, 0.014, (22, 22, 26), layer, n=10)
        limb(scene, (sgn * 0.3, 1.235, -0.6), (sgn * 0.37, 1.238, -0.665), 0.014, 0.014, (22, 22, 26), layer, n=10)
        for gi in range(7):
            t0, t1 = gi / 7, (gi + 1) / 7
            p0 = (sgn * (0.37 + 0.07 * t0), 1.238, -0.665 - 0.03 * t0)
            p1 = (sgn * (0.37 + 0.07 * t1), 1.238, -0.665 - 0.03 * t1)
            limb(scene, p0, p1, 0.022 if gi % 2 == 0 else 0.019, 0.022 if gi % 2 == 0 else 0.019, (16, 16, 18) if gi % 2 == 0 else (34, 34, 38), layer, n=12, bulge=1.0)
        joint(scene, (sgn * 0.445, 1.238, -0.7), 0.021, (16, 16, 18), layer, 10, 5)
        ellipsoid(scene, (sgn * 0.27, 1.225, -0.605), (0.045, 0.028, 0.038), (20, 20, 24), layer, n=14, m=6, e=0.7)   # switch gear
        for bi, bc in enumerate(((60, 200, 90), (230, 60, 50), (240, 200, 60))):
            joint(scene, (sgn * (0.255 + 0.015 * bi), 1.25, -0.58), 0.006, bc, layer + 1, 6, 3)
        lever = bezier((sgn * 0.345, 1.222, -0.63), (sgn * 0.4, 1.19, -0.57), (sgn * 0.405, 1.2, -0.5), 6)
        curve_tube(scene, lever, 0.007, (206, 210, 216), layer, 6)
        joint(scene, lever[-1], 0.011, (206, 210, 216), layer, 8, 4)
        # A black mirror on a curved black stalk, glass in a rounded housing.
        stalk = bezier((sgn * 0.3, 1.25, -0.62), (sgn * 0.34, 1.42, -0.6), (sgn * 0.42, 1.5, -0.54), 6)
        curve_tube(scene, stalk, 0.009, (22, 22, 26), layer, 6)
        ellipsoid(scene, (sgn * 0.44, 1.53, -0.52), (0.075, 0.062, 0.024), (24, 24, 28), layer, n=18, m=8, e=0.7)
        scene.face([(sgn * 0.44 - 0.063, 1.55, -0.54), (sgn * 0.44 + 0.063, 1.55, -0.54), (sgn * 0.44 + 0.063, 1.5, -0.54), (sgn * 0.44 - 0.063, 1.5, -0.54)],
                   (150, 190, 226), texture=glass or mirror_texture(), layer=layer + 1, two_sided=True, emissive=True)
    # The speedometer pod on the headstock, its dial facing the rider.
    ellipsoid(scene, (0, 1.265, -0.43), (0.125, 0.05, 0.075), (22, 22, 26), layer, n=22, m=8, e=0.55)
    if cluster is not None:
        scene.face([(-0.105, 1.31, -0.5), (0.105, 1.31, -0.5), (0.105, 1.235, -0.5), (-0.105, 1.235, -0.5)], (10, 14, 20),
                   texture=cluster, layer=layer + 1, two_sided=True, emissive=True)
    if phone is not None:
        limb(scene, (-0.2, 1.215, -0.55), (-0.215, 1.255, -0.55), 0.008, 0.008, (30, 30, 34), layer, n=8)
        ellipsoid(scene, (-0.215, 1.34, -0.555), (0.052, 0.09, 0.012), (24, 24, 28), layer, n=14, m=8, e=0.5)
        scene.face([(-0.262, 1.425, -0.569), (-0.168, 1.425, -0.569), (-0.168, 1.255, -0.569), (-0.262, 1.255, -0.569)], (30, 30, 34),
                   texture=phone, layer=layer + 1, two_sided=True, emissive=True)


def scooter_body(scene, show_leg=True, layer=5):
    """The body of the delivery bike, as in the art: a black underbone with hot-pink flashes along the flanks and
    legshield, a rubber floor with a silver footrest, a silver engine and chain, a long black seat, a black rack,
    the pink top box with black straps and trim, a red tail light with orange indicators, a black number plate,
    and a silver exhaust. When asked, Peter's right leg and boot as seen from the right."""
    near = layer
    # The step-through floor with a rubber mat, and the footrest peg on the right.
    scene.face([(-0.17, 0.31, -0.5), (0.17, 0.31, -0.5), (0.17, 0.31, -0.82), (-0.17, 0.31, -0.82)], (30, 30, 34), layer=near, two_sided=True)
    for gz in np.arange(-0.52, -0.8, -0.05):
        scene.face([(-0.15, 0.312, gz), (0.15, 0.312, gz), (0.15, 0.312, gz - 0.016), (-0.15, 0.312, gz - 0.016)], (18, 18, 22), layer=near, two_sided=True)
    limb(scene, (0.1, 0.34, -0.8), (0.22, 0.34, -0.8), 0.012, 0.012, (180, 184, 190), near + 1, n=8)
    # The flanks: a black shell (fuel tank cover and tail) with a long hot-pink flash on each side.
    stations = ((-0.62, 0.5, 0.15, 0.15), (-0.85, 0.53, 0.18, 0.18), (-1.1, 0.56, 0.19, 0.19), (-1.35, 0.6, 0.17, 0.17), (-1.62, 0.66, 0.12, 0.15), (-1.8, 0.72, 0.08, 0.1))
    rings = [ring_points((0, y, z), (1, 0, 0), (0, 1, 0), rx, ry, 22, 0.75) for z, y, rx, ry in stations]
    loft(scene, rings, (24, 24, 28), near, caps=(False, False))
    for sgn in (-1, 1):
        flash = [(-0.78, 0.5), (-0.95, 0.66), (-1.12, 0.62), (-1.3, 0.72), (-1.55, 0.74), (-1.3, 0.68), (-1.15, 0.58), (-0.96, 0.58)]
        scene.face([(sgn * 0.199, y, z) for z, y in flash], PINK, layer=near + 1, two_sided=True)
        flash2 = [(-0.72, 0.43), (-0.8, 0.55), (-0.9, 0.5), (-1.0, 0.5), (-0.9, 0.44)]
        scene.face([(sgn * 0.196, y, z) for z, y in flash2], PINK, layer=near + 1, two_sided=True)
    # The engine: a silver crankcase cover with a finned cylinder, a kick lever and a drive chain to the rear wheel.
    ellipsoid(scene, (0.12, 0.36, -0.95), (0.05, 0.1, 0.1), (178, 182, 188), near + 1, n=20, m=8, e=0.8)
    ellipsoid(scene, (0.13, 0.36, -0.95), (0.025, 0.06, 0.06), (120, 124, 130), near + 1, n=14, m=6)
    ellipsoid(scene, (0.0, 0.42, -0.82), (0.1, 0.1, 0.11), (60, 62, 68), near, n=14, m=6, e=0.8)
    for fi in range(5):
        ellipsoid(scene, (0.0, 0.5 + 0.02 * fi, -0.8 - 0.01 * fi), (0.1, 0.008, 0.1), (150, 154, 160), near + 1, n=14, m=3, e=0.8)
    limb(scene, (0.18, 0.28, -0.98), (0.2, 0.27, -1.05), 0.012, 0.012, (170, 174, 180), near + 1, n=6)
    limb(scene, (0.15, 0.4, -0.98), (0.15, 0.38, -1.25), 0.012, 0.012, (30, 30, 34), near + 1, n=6)   # chain guard
    limb(scene, (0.15, 0.31, -0.98), (0.15, 0.255, -1.25), 0.012, 0.012, (30, 30, 34), near + 1, n=6)
    # The seat: long, flat and black with a pale stitched edge.
    seat_rings = [ring_points((0, 0.8 + dy, z), (1, 0, 0), (0, 1, 0), rx, ry, 20, 0.6)
                  for z, rx, ry, dy in ((-0.84, 0.1, 0.03, 0.0), (-0.95, 0.13, 0.04, 0.01), (-1.2, 0.145, 0.045, 0.015), (-1.5, 0.12, 0.035, 0.0), (-1.62, 0.08, 0.03, -0.01))]
    loft(scene, seat_rings, (26, 26, 30), near + 1, caps=(True, True), shade=lambda k, i: (54, 54, 60) if i in (4, 5, 15, 16) else None)
    # The rack and the pink top box, with black straps, trim and silver buckles.
    for sgn in (-1, 1):
        limb(scene, (sgn * 0.19, 0.93, -1.2), (sgn * 0.19, 0.93, -1.95), 0.014, 0.014, (22, 22, 26), near + 1, n=8, bulge=1.0)
        limb(scene, (sgn * 0.19, 0.93, -1.2), (sgn * 0.12, 0.74, -1.55), 0.012, 0.012, (22, 22, 26), near + 1, n=8, bulge=1.0)
    for rz in (-1.25, -1.5, -1.75, -1.95):
        limb(scene, (-0.19, 0.93, rz), (0.19, 0.93, rz), 0.012, 0.012, (22, 22, 26), near + 1, n=8, bulge=1.0)
    box_c = (0, 1.14, -1.58)
    ellipsoid(scene, box_c, (0.23, 0.2, 0.36), PINK, near + 1, n=28, m=14, e=0.3,
              shade=lambda k, i: (20, 20, 24) if k in (4, 5) else None)
    for sgn in (-1, 1):
        for bz in (-1.4, -1.76):
            scene.face([(sgn * 0.232, 1.34, bz - 0.025), (sgn * 0.232, 1.34, bz + 0.025), (sgn * 0.232, 0.95, bz + 0.025), (sgn * 0.232, 0.95, bz - 0.025)], (22, 22, 26), layer=near + 2, two_sided=True)
            scene.box(sgn * 0.232 - 0.006, sgn * 0.232 + 0.006, 1.13, 1.2, bz - 0.02, bz + 0.02, (200, 204, 210), layer=near + 2)
    # The back: tail light, orange indicators, a black number plate and the silver exhaust.
    ellipsoid(scene, (0, 0.78, -1.9), (0.1, 0.045, 0.03), (214, 36, 40), near + 1, n=14, m=6, e=0.7)
    for sgn in (-1, 1):
        ellipsoid(scene, (sgn * 0.17, 0.77, -1.88), (0.04, 0.03, 0.03), (255, 150, 30), near + 1, n=10, m=5)
    scene.face([(-0.1, 0.7, -1.93), (0.1, 0.7, -1.93), (0.1, 0.52, -1.93), (-0.1, 0.52, -1.93)], (22, 22, 26), layer=near + 1, two_sided=True)
    scene.face([(-0.09, 0.69, -1.935), (0.09, 0.69, -1.935), (0.09, 0.61, -1.935), (-0.09, 0.61, -1.935)], (240, 240, 232), layer=near + 2, two_sided=True)
    limb(scene, (0.2, 0.3, -1.0), (0.2, 0.34, -1.78), 0.045, 0.05, (176, 180, 186), near + 1, n=14)
    ellipsoid(scene, (0.2, 0.34, -1.82), (0.05, 0.05, 0.05), (28, 28, 32), near + 1, n=12, m=6)
    if show_leg:
        rider_leg(scene, 1, layer + 2)


def _tone(color, factor):
    return tuple(int(max(0, min(255, c * factor))) for c in color)


def fabric(base, seed=1, grain=0.05, creases=(), crease_depth=0.2, stripes=(), stripe_color=None, panel=None):
    """A shading function for `loft`: the base colour with a little grain from quad to quad, darker bands
    where the cloth creases (`creases` lists ring rows k), light thin lines (`stripes` lists columns i)
    for seams or reflective tape, and `panel` (a dict column -> factor) for darker side panels."""
    rng = np.random.default_rng(seed)
    noise = rng.normal(0, grain, (64, 64))

    def shade(k, i):
        f = 1.0 + float(noise[k % 64, i % 64])
        if k in creases:
            f -= crease_depth * (1.0 if (i * 7 + k) % 3 else 0.5)
        if k - 1 in creases or k + 1 in creases:
            f -= crease_depth * 0.35
        if panel and i in panel:
            f *= panel[i]
        color = _tone(base, f)
        if i in stripes and stripe_color is not None:
            color = stripe_color
        return color

    return shade


def tube_along(scene, points, radii, color, layer, n=18, e=0.9, squash=1.0, shade=None, caps=(True, True)):
    """A smooth limb or sleeve through several points, with its own radius at each (so a knee swells and an ankle
    narrows), skinned in one piece. `squash` flattens its cross-section a little (a thigh is wider than deep)."""
    rings = []
    pts = [np.array(p, float) for p in points]
    for idx, centre in enumerate(pts):
        if idx == 0:
            d = pts[1] - pts[0]
        elif idx == len(pts) - 1:
            d = pts[-1] - pts[-2]
        else:
            d = pts[idx + 1] - pts[idx - 1]
        d = d / np.linalg.norm(d)
        up = np.array([0.0, 1.0, 0.0]) if abs(d[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
        u = np.cross(d, up)
        u /= np.linalg.norm(u)
        v = np.cross(d, u)
        rings.append(ring_points(centre, u, v, radii[idx], radii[idx] * squash, n, e))
    loft(scene, rings, color, layer, caps=caps, shade=shade)


def rider_leg(scene, sgn, layer):
    """Peter's leg: jeans from hip to ankle, drawn through a swelling at the knee with creases behind it and
    stacked at the ankle, a stitched outer seam, a rolled turn-up cuff, and a boot with a rounded toe cap, a
    darker sole, a heel, a welt line and crossed laces."""
    x = sgn * 0.2
    hip, thigh, knee, shin, ankle = (x - sgn * 0.02, 0.97, -1.08), (x - sgn * 0.005, 0.99, -0.88), (x, 1.0, -0.66), (x, 0.74, -0.68), (x, 0.5, -0.71)
    denim = fabric(JEANS, seed=5 if sgn > 0 else 6, grain=0.045, creases=(2, 4, 7), crease_depth=0.22, stripes=(3,), stripe_color=(150, 176, 214))
    tube_along(scene, [hip, thigh, knee, (x, 0.86, -0.67), shin, ankle], [0.093, 0.087, 0.07, 0.066, 0.056, 0.052], JEANS, layer, n=18, squash=0.92, shade=denim, caps=(True, False))
    joint(scene, knee, 0.074, _tone(JEANS, 1.1), layer, 14, 8)
    # The turn-up cuff: a paler band that is a little wider than the leg.
    tube_along(scene, [(x, 0.54, -0.705), (x, 0.47, -0.715)], [0.061, 0.063], (120, 142, 188), layer, n=18, shade=fabric((120, 142, 188), seed=9, grain=0.04), caps=(False, False))
    # The boot: leather with a toe cap, a heel block, a sole with a lighter welt, a tongue and laces.
    leather = fabric(BOOT, seed=11, grain=0.05, creases=(4,), crease_depth=0.12)
    ellipsoid(scene, (x, 0.405, -0.765), (0.068, 0.058, 0.155), BOOT, layer, n=18, m=10, e=0.82, shade=leather)
    ellipsoid(scene, (x, 0.385, -0.84), (0.062, 0.05, 0.075), _tone(BOOT, 1.25), layer, n=14, m=8, e=0.8)   # the toe cap, a little glossier
    ellipsoid(scene, (x, 0.345, -0.775), (0.074, 0.022, 0.165), (10, 10, 12), layer, n=18, m=6, e=0.7)       # the sole
    ellipsoid(scene, (x, 0.357, -0.775), (0.076, 0.006, 0.168), (90, 78, 66), layer, n=18, m=4, e=0.7)       # the welt
    ellipsoid(scene, (x, 0.34, -0.665), (0.06, 0.03, 0.04), (12, 12, 14), layer, n=12, m=6, e=0.8)           # the heel
    ellipsoid(scene, (x, 0.5, -0.715), (0.045, 0.04, 0.03), _tone(BOOT, 1.4), layer + 1, n=10, m=5)         # the tongue
    for li, lz in enumerate(np.arange(-0.73, -0.86, -0.028)):
        flip = 1 if li % 2 == 0 else -1
        scene.face([(x - 0.032, 0.46 - 0.002 * li, lz), (x + 0.032, 0.46 - 0.002 * li, lz - 0.01 * flip), (x + 0.032, 0.462 - 0.002 * li, lz - 0.014), (x - 0.032, 0.462 - 0.002 * li, lz - 0.004)],
                   (214, 214, 218), layer=layer + 1, two_sided=True)


# ---------------------------------------------------------------- Peter, seen from behind and above

def rider(scene, layer=7, left_only=False):
    """Peter seated on the scooter: pink helmet with a stripe and a rubber rim, black jacket with reflective
    bands, the arms reaching the grips in gloves, the legs and boots. Built for a
    camera behind him and to his left."""
    lean = 0.16   # how far the chest leans forward per metre of height
    def back(y):
        return -1.0 + lean * (y - 0.95)
    # Torso: a V-tapered nylon jacket with a zip down the back seam, a reflective band, a ribbed hem and
    # a collar, creased where it bunches at the waist.
    stations = ((0.9, 0.2, 0.135), (0.95, 0.205, 0.138), (1.06, 0.2, 0.14), (1.2, 0.225, 0.15), (1.33, 0.255, 0.145), (1.41, 0.235, 0.12), (1.45, 0.13, 0.1))
    rings = [ring_points((0, y, back(y)), (1, 0, 0), (0, 0, 1), rx, rz, 24, 0.85) for y, rx, rz in stations]
    nylon = fabric(JACKET, seed=21, grain=0.035, creases=(1, 2), crease_depth=0.25, stripes=(0, 12), stripe_color=(70, 70, 78), panel={5: 0.82, 6: 0.82, 17: 0.82, 18: 0.82})

    def shade(k, i):
        if k == 3 and i % 24 != 99:   # a reflective band round the back
            return (206, 210, 216) if i % 2 == 0 else (178, 182, 190)
        if k == 0:
            return _tone(JACKET, 1.5) if i % 2 == 0 else _tone(JACKET, 1.2)   # the ribbed hem
        return nylon(k, i)

    loft(scene, rings, JACKET, layer, caps=(True, False), shade=shade)
    # The collar and the neck.
    limb(scene, (0, 1.44, back(1.44)), (0, 1.52, back(1.52) - 0.01), 0.08, 0.07, _tone(JACKET, 1.4), layer, n=18)
    limb(scene, (0, 1.5, back(1.5)), (0, 1.56, back(1.56) - 0.01), 0.052, 0.05, SKIN, layer, n=14)
    # Helmet: a glossy pink shell, a pale racing stripe, a black rubber rim and a rear vent.
    head = (0, 1.66, back(1.66) - 0.01)
    helmet(scene, head, layer + 2, visor_i=7, back_y=back(1.545) - 0.02)
    # Arms: shoulder joints, sleeves with elbow bends and a reflective cuff, and gloves on the grips.
    for sgn in (-1, 1):
        shoulder = (sgn * 0.255, 1.36, back(1.36) + 0.0)
        elbow = (sgn * 0.37, 1.12, -0.9)
        wrist = (sgn * 0.435, 1.225, -0.72)
        joint(scene, shoulder, 0.075, JACKET, layer + 1, 16, 8)
        sleeve = fabric(JACKET, seed=31 + sgn, grain=0.035, creases=(2, 3), crease_depth=0.26, stripes=(5,), stripe_color=(190, 194, 200))
        mid_up = tuple((np.array(shoulder) + np.array(elbow)) / 2.0 + np.array([0.012 * sgn, 0.0, 0.0]))
        mid_lo = tuple((np.array(elbow) + np.array(wrist)) / 2.0 + np.array([0.01 * sgn, 0.012, 0.0]))
        tube_along(scene, [shoulder, mid_up, elbow, mid_lo, tuple(np.array(elbow) + (np.array(wrist) - np.array(elbow)) * 0.8)],
                   [0.066, 0.062, 0.056, 0.05, 0.043], JACKET, layer + 1, n=16, shade=sleeve, caps=(False, False))
        joint(scene, elbow, 0.058, _tone(JACKET, 1.05), layer + 1, 12, 8)
        cuff_a = np.array(elbow) + (np.array(wrist) - np.array(elbow)) * 0.78
        tube_along(scene, [tuple(cuff_a), wrist], [0.046, 0.044], (30, 30, 34), layer + 1, n=16, shade=fabric((30, 30, 34), seed=41, grain=0.05, stripes=(0, 8), stripe_color=(206, 210, 216)), caps=(False, True))   # an elastic cuff with a reflective tape
        glove(scene, sgn, layer + 2)
    rider_leg(scene, -1, layer)
    rider_leg(scene, 1, layer)


def helmet(scene, head, layer, visor_i=7, back_y=None):
    """The pink helmet: a glossy shell with a pale stripe, a dark visor on one side (index `visor_i` of the
    28 ring points: 7 faces +z, 21 faces -z), a decal at each ear, a vent opposite the visor and a black
    rubber rim round the bottom edge. Marks are painted on the shell so each stays on its own side."""
    n = 28
    vent_i = (visor_i + 14) % n

    def near(i, centre, spread):
        return abs((i - centre + n // 2) % n - n // 2) <= spread

    def helmet_shade(k, i):
        if near(i, 0, 0) or near(i, 14, 0):
            if 6 <= k <= 9:
                return (255, 238, 247)
        if near(i, visor_i, 2) and 6 <= k <= 9 and not (near(i, visor_i, 2) and k in (6, 9) and not near(i, visor_i, 1)):
            return (22, 26, 40) if k != 6 else (60, 70, 96)   # a dark visor with a lighter glint along its top edge
        if near(i, vent_i, 1) and 7 <= k <= 8:
            return (40, 20, 30)
        if (near(i, visor_i - 7 + 14, 0) or near(i, visor_i - 7, 0) or near(i, visor_i - 7 + 1, 0)) and 2 <= k <= 11:
            return (255, 238, 247)   # the stripe over the top
        return None

    hx, hy, hz = head
    ellipsoid(scene, head, (0.158, 0.172, 0.19), PINK, layer, n=n, m=16, e=0.95, shade=helmet_shade)
    ellipsoid(scene, (hx, hy - 0.115, hz - 0.01), (0.152, 0.02, 0.172), (20, 20, 22), layer, n=n, m=4, e=0.9)   # the rubber rim at the bottom edge
    front = 1 if visor_i == 7 else -1
    ellipsoid(scene, (hx, hy - 0.09, hz + front * 0.15), (0.095, 0.07, 0.07), PINK, layer, n=18, m=8, e=0.85)   # the chin guard


def hanging_helmet(scene, loop, layer=8):
    """The helmet hung on the mirror by its straps: a loop of strap round the stalk, two straps down to the
    shell, a small buckle, the visor turned towards the camera behind the bike."""
    lx, ly, lz = loop
    head = (lx - 0.1, ly - 0.3, lz - 0.02)
    helmet(scene, head, layer, visor_i=21)
    for sgn in (-1, 1):
        top = (lx, ly, lz)
        side = (head[0] + sgn * 0.14, head[1] + 0.02, head[2] - 0.02)
        curve_tube(scene, bezier(top, ((top[0] + side[0]) / 2, (top[1] + side[1]) / 2 + 0.03, top[2] - 0.02), side, 6), 0.007, (24, 24, 28), layer, 6)
    ellipsoid(scene, (lx, ly - 0.02, lz - 0.01), (0.014, 0.014, 0.014), (200, 204, 210), layer, n=8, m=4)   # the buckle on the stalk


def glove(scene, sgn, layer):
    """A black glove closed round the grip: a fist, four fingers, a thumb and a pink knuckle pad."""
    gx, gy, gz = sgn * 0.435, 1.238, -0.69
    ellipsoid(scene, (gx, gy + 0.008, gz), (0.045, 0.036, 0.05), (22, 22, 26), layer, n=14, m=8, e=0.8)
    for i in range(4):
        fz = gz + 0.036 + 0.0
        fy = gy + 0.022 - i * 0.019
        limb(scene, (gx - 0.03, fy, fz + 0.005), (gx + 0.03, fy, fz + 0.005), 0.0105, 0.0105, (30, 30, 34), layer, n=8, bulge=1.0)
    limb(scene, (gx - sgn * 0.03, gy + 0.025, gz + 0.02), (gx - sgn * 0.005, gy + 0.02, gz + 0.045), 0.011, 0.01, (34, 34, 38), layer, n=8)
    ellipsoid(scene, (gx, gy + 0.042, gz - 0.005), (0.032, 0.008, 0.036), PINK, layer + 1, n=10, m=6, e=0.7)


def rear_end(scene, P, side, near, far):
    """What the rear wheel needs: a chain sprocket, a black swingarm, a shock with a silver spring, and a black
    mudguard over the back of the tyre."""
    for sgn in (1, -1):
        layer = near if sgn == side else far
        ring(scene, P, 0.15, sgn * 0.046, 0.05, sgn * 0.06, (150, 154, 160), layer, 40)
    # The sprocket on the right, with a dark toothed edge.
    ring(scene, P, 0.085, 0.06, 0.07, 0.062, (40, 40, 46), near if side == 1 else far, 24, alt=(2, (90, 94, 100)))
    limb(scene, P(side * 0.1, 0, 0), P(side * 0.1, 0.05, 0.6), 0.04, 0.05, (26, 26, 30), near + 1, n=12)   # swingarm
    top = P(side * 0.13, 0.32, 0.12)
    bottom = P(side * 0.13, 0.02, -0.03)
    limb(scene, bottom, top, 0.014, 0.014, (190, 194, 200), near + 1, n=8)
    for i in range(8):   # the spring round the shock
        t0, t1 = i / 8, (i + 0.6) / 8
        a_ = np.array(bottom) + (np.array(top) - np.array(bottom)) * t0
        b_ = np.array(bottom) + (np.array(top) - np.array(bottom)) * t1
        limb(scene, a_, b_, 0.03, 0.03, (206, 210, 216), near + 1, n=10, bulge=1.0)
    steps = 26
    for i in range(steps):
        t0, t1 = -1.5 + 1.75 * i / steps, -1.5 + 1.75 * (i + 1) / steps
        r = 0.345
        sheet = [P(-0.07, r * math.cos(t0), r * math.sin(t0)), P(0.07, r * math.cos(t0), r * math.sin(t0)),
                 P(0.07, r * math.cos(t1), r * math.sin(t1)), P(-0.07, r * math.cos(t1), r * math.sin(t1))]
        scene.face(sheet, (24, 24, 28), layer=near + 1, two_sided=True)


def ring(scene, P, r0, lx0, r1, lx1, color, layer, count=40, alt=None):
    for i in range(count):
        t0, t1 = 2 * math.pi * i / count, 2 * math.pi * (i + 1) / count
        pts = [P(lx0, r0 * math.cos(t0), r0 * math.sin(t0)), P(lx0, r0 * math.cos(t1), r0 * math.sin(t1)),
               P(lx1, r1 * math.cos(t1), r1 * math.sin(t1)), P(lx1, r1 * math.cos(t0), r1 * math.sin(t0))]
        c = color if alt is None or i % alt[0] else alt[1]
        scene.face(pts, c, layer=layer, two_sided=True)
