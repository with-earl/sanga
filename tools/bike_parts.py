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

PINK = (232, 70, 140)
PINK_DARK = (190, 48, 112)
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
    """The front wheel standing at (cx, cz): a tyre with a ribbed tread, a black twin-spoke alloy rim with
    silver edges, a drilled disc, red caliper and hose on the right-hand side, the fork with rubber
    boots and chrome tubes, and the pink mudguard. `side` is +1 when the camera is on the right of the bike
    and -1 on the left, so the near face is drawn over the far one."""
    R = WHEEL_R
    near, far = 3, 1

    def P(lx, ly, lz):
        return (cx + lx, R + ly, cz + lz)

    def ring(r0, lx0, r1, lx1, color, layer, alt=None, count=n):
        for i in range(count):
            t0, t1 = 2 * math.pi * i / count, 2 * math.pi * (i + 1) / count
            pts = [P(lx0, r0 * math.cos(t0), r0 * math.sin(t0)), P(lx0, r0 * math.cos(t1), r0 * math.sin(t1)),
                   P(lx1, r1 * math.cos(t1), r1 * math.sin(t1)), P(lx1, r1 * math.cos(t0), r1 * math.sin(t0))]
            c = color if alt is None or i % alt[0] else alt[1]
            scene.face(pts, c, layer=layer, two_sided=True)

    rubber, groove = (36, 36, 39), (22, 22, 24)
    for sgn in (1, -1):
        layer = near if sgn == side else far
        # Tread: blocks that alternate across the crown, rounded shoulders, then the sidewall.
        ring(0.31, sgn * 0.0, 0.31, sgn * 0.03, groove, 2, alt=(3, (50, 50, 54)))
        ring(0.31, sgn * 0.03, 0.305, sgn * 0.046, groove, 2, alt=(2, (46, 46, 50)))
        ring(0.305, sgn * 0.046, 0.296, sgn * 0.054, rubber, 2)
        ring(0.296, sgn * 0.054, 0.27, sgn * 0.058, rubber, layer)
        ring(0.27, sgn * 0.058, 0.215, sgn * 0.05, (40, 40, 44), layer)
        ring(0.26, sgn * 0.0585, 0.252, sgn * 0.0575, (92, 92, 96), layer)   # the printed ring on the sidewall
        ring(0.215, sgn * 0.05, 0.2, sgn * 0.05, (34, 34, 38), layer)
        ring(0.2, sgn * 0.05, 0.19, sgn * 0.044, (206, 210, 216), layer)   # the machined rim lip
        ring(0.196, sgn * 0.044, 0.196, 0.0, (74, 76, 82), far)            # the barrel inside the rim
    # Twin-spoke alloy: five pairs of spokes that flare at the rim, black with a silver edge.
    for sgn in (1, -1):
        layer = near if sgn == side else far
        for k in range(5):
            phi = 2 * math.pi * k / 5 + 0.3
            for off in (-0.1, 0.1):
                for width_in, width_out, tone, dz in ((0.2, 0.17, (34, 34, 40), 0.034), (0.07, 0.06, (178, 182, 190), 0.038)):
                    pts = [P(sgn * dz, r * math.cos(phi + off * (1 - 0.35 * (r - 0.05) / 0.14) + s * wd), r * math.sin(phi + off * (1 - 0.35 * (r - 0.05) / 0.14) + s * wd))
                           for r, wd, s in ((0.05, width_in * 0.5, -1), (0.19, width_out * 0.5, -1), (0.19, width_out * 0.5, 1), (0.05, width_in * 0.5, 1))]
                    scene.face(pts, tone, layer=layer, two_sided=True)
        ring(0.052, sgn * 0.044, 0.026, sgn * 0.05, (200, 204, 210), layer, count=20)
        ring(0.026, sgn * 0.05, 0.0, sgn * 0.052, (150, 154, 160), layer, count=20)
    if not front:
        rear_end(scene, P, side, near, far)
        return
    # The valve stem on the rim.
    limb(scene, P(side * 0.046, 0.185 * math.cos(0.9), 0.185 * math.sin(0.9)), P(side * 0.07, 0.15 * math.cos(0.9), 0.15 * math.sin(0.9)), 0.006, 0.005, (190, 194, 200), near + 1, n=6)
    # The disc on the right: a ring with a hub carrier and drilled holes.
    disc_layer = near if side == 1 else far
    ring(0.155, 0.024, 0.088, 0.024, (186, 190, 198), disc_layer, alt=(1, (176, 180, 188)), count=60)
    ring(0.088, 0.024, 0.052, 0.027, (54, 54, 60), disc_layer, count=24)
    for i in range(12):
        t = 2 * math.pi * i / 12
        for rr in (0.108, 0.136):
            hole = [P(0.0245, rr * math.cos(t + dt) + dy, rr * math.sin(t + dt) + dz) for dt, dy, dz in ((0, 0, 0), (0.07, 0, 0), (0.07, 0.006, 0.006), (0, 0.006, 0.006))]
            scene.face(hole, (60, 60, 66), layer=disc_layer, two_sided=True)
    # Caliper, bolts, and the brake hose running up the fork.
    caliper = [(0.012, -0.034, -0.16), (0.05, -0.034, -0.16), (0.05, 0.05, -0.16), (0.012, 0.05, -0.16)]
    ellipsoid(scene, P(0.034, 0.008, -0.125), (0.026, 0.044, 0.04), (156, 28, 32), disc_layer + 1, n=14, m=8, e=0.7)
    joint(scene, P(0.057, 0.03, -0.14), 0.007, (200, 204, 210), disc_layer + 1, 8, 4)
    joint(scene, P(0.057, -0.012, -0.14), 0.007, (200, 204, 210), disc_layer + 1, 8, 4)
    # The fork: rubber boots over polished stanchions, black sliders, a fork crown, the axle.
    for sgn in (1, -1):
        layer = near + 1 if sgn == side else far
        axle_end = P(sgn * 0.088, 0, 0)
        lower_top = P(sgn * 0.088, 0.22, -0.1)
        boot_top = P(sgn * 0.088, 0.42, -0.2)
        crown = P(sgn * 0.088, 0.78, -0.37)
        limb(scene, axle_end, lower_top, 0.034, 0.032, (24, 24, 28), layer, n=14)
        limb(scene, lower_top, boot_top, 0.026, 0.03, (206, 210, 216), layer, n=14)   # the chrome stanchion
        for i in range(6):   # rubber bellows
            t0, t1 = 0.12 + 0.13 * i, 0.12 + 0.13 * (i + 0.6)
            a = np.array(lower_top) + (np.array(boot_top) - np.array(lower_top)) * 0.0
            q0 = np.array(boot_top) + (np.array(crown) - np.array(boot_top)) * t0
            q1 = np.array(boot_top) + (np.array(crown) - np.array(boot_top)) * t1
            limb(scene, q0, q1, 0.036, 0.036, (20, 20, 23), layer, n=14, bulge=1.1)
            q2 = np.array(boot_top) + (np.array(crown) - np.array(boot_top)) * (t1 + 0.012)
            limb(scene, q1, q2, 0.032, 0.032, (36, 36, 40), layer, n=14, bulge=1.0)
    limb(scene, P(-0.13, 0, 0), P(0.13, 0, 0), 0.016, 0.016, (120, 124, 130), near + 1, n=10)
    joint(scene, P(side * 0.125, 0.0, 0.0), 0.024, (176, 180, 186), near + 1, 12, 6)
    # The mudguard: a smooth pink arc over the tyre with flanges and a raised rib.
    steps = 36
    for i in range(steps):
        t0, t1 = -0.95 + 2.25 * i / steps, -0.95 + 2.25 * (i + 1) / steps
        r = 0.338 + 0.012 * math.sin(math.pi * i / steps)
        sheet = [P(-0.075, r * math.cos(t0), r * math.sin(t0)), P(0.075, r * math.cos(t0), r * math.sin(t0)),
                 P(0.075, r * math.cos(t1), r * math.sin(t1)), P(-0.075, r * math.cos(t1), r * math.sin(t1))]
        scene.face(sheet, PINK, layer=near + 1, two_sided=True)
        rib = [P(-0.012, (r + 0.004) * math.cos(t0), (r + 0.004) * math.sin(t0)), P(0.012, (r + 0.004) * math.cos(t0), (r + 0.004) * math.sin(t0)),
               P(0.012, (r + 0.004) * math.cos(t1), (r + 0.004) * math.sin(t1)), P(-0.012, (r + 0.004) * math.cos(t1), (r + 0.004) * math.sin(t1))]
        scene.face(rib, (255, 186, 220), layer=near + 1, two_sided=True)
        for sgn in (1, -1):
            flange = [P(sgn * 0.075, r * math.cos(t0), r * math.sin(t0)), P(sgn * 0.075, r * math.cos(t1), r * math.sin(t1)),
                      P(sgn * 0.075, (r - 0.034) * math.cos(t1), (r - 0.034) * math.sin(t1)), P(sgn * 0.075, (r - 0.034) * math.cos(t0), (r - 0.034) * math.sin(t0))]
            scene.face(flange, PINK_DARK, layer=near + 1 if sgn == side else far, two_sided=True)


# ---------------------------------------------------------------- steering and the front of the body


def steering(scene, layer=6, glass=None, cluster=None, phone=None):
    """The handlebar end: the pink headlight and cowl, stem, swept bar with ribbed grips, levers with ball
    ends, switch pods, brake hose, mirrors on stalks, dashboard housing, and (optionally) phone."""
    # Headlight with a lit lens, indicators, and the apron below it.
    ellipsoid(scene, (0, 1.03, -0.3), (0.14, 0.1, 0.1), PINK, layer - 2, n=22, m=12, e=0.8)
    ellipsoid(scene, (0, 1.03, -0.205), (0.1, 0.075, 0.03), (255, 244, 214), layer - 2, n=18, m=8, emissive=True)
    for sgn in (-1, 1):
        ellipsoid(scene, (sgn * 0.16, 0.99, -0.32), (0.032, 0.026, 0.04), (255, 160, 40), layer - 2, n=10, m=6)
    rings = [ring_points((0, y, z), (1, 0, 0), (0, 0, 1), rx, rz, 20, 0.75) for y, z, rx, rz in
             ((1.0, -0.42, 0.14, 0.1), (0.8, -0.46, 0.17, 0.09), (0.58, -0.52, 0.19, 0.075), (0.38, -0.56, 0.21, 0.07))]
    loft(scene, rings, PINK, layer - 3, caps=(False, False))
    # Stem, fork crown plate, bar clamp.
    limb(scene, (0, 1.06, -0.36), (0, 1.2, -0.47), 0.034, 0.03, (62, 62, 68), layer - 1, n=14)
    ellipsoid(scene, (0, 1.2, -0.47), (0.07, 0.03, 0.05), (36, 36, 40), layer, n=14, m=6)
    # The bar: swept back, slightly bent where it meets the grips.
    for sgn in (-1, 1):
        limb(scene, (0, 1.205, -0.47), (sgn * 0.3, 1.235, -0.6), 0.013, 0.012, SILVER, layer, n=10)
        limb(scene, (sgn * 0.3, 1.235, -0.6), (sgn * 0.37, 1.238, -0.665), 0.012, 0.012, SILVER, layer, n=10)
        for gi in range(7):   # ribbed rubber grip
            t0, t1 = gi / 7, (gi + 1) / 7
            p0 = (sgn * (0.37 + 0.07 * t0), 1.238, -0.665 - 0.03 * t0)
            p1 = (sgn * (0.37 + 0.07 * t1), 1.238, -0.665 - 0.03 * t1)
            limb(scene, p0, p1, 0.021 if gi % 2 == 0 else 0.018, 0.021 if gi % 2 == 0 else 0.018, RUBBER if gi % 2 == 0 else (40, 40, 44), layer, n=12, bulge=1.0)
        joint(scene, (sgn * 0.445, 1.238, -0.7), 0.02, (22, 22, 26), layer, 10, 5)   # the bar end
        # Switch pod with little buttons, and the brake lever with a ball end.
        ellipsoid(scene, (sgn * 0.27, 1.225, -0.605), (0.04, 0.026, 0.035), (22, 22, 26), layer, n=14, m=6, e=0.7)
        for bi, bc in enumerate(((60, 200, 90), (230, 60, 50), (240, 200, 60))):
            joint(scene, (sgn * (0.255 + 0.015 * bi), 1.248, -0.58), 0.006, bc, layer + 1, 6, 3)
        lever = bezier((sgn * 0.345, 1.222, -0.63), (sgn * 0.4, 1.19, -0.57), (sgn * 0.405, 1.2, -0.5), 6)
        curve_tube(scene, lever, 0.007, (206, 210, 216), layer, 6)
        joint(scene, lever[-1], 0.011, (206, 210, 216), layer, 8, 4)
        # Mirror stalk, housing and glass.
        stalk = bezier((sgn * 0.3, 1.25, -0.62), (sgn * 0.36, 1.4, -0.6), (sgn * 0.44, 1.45, -0.54), 6)
        curve_tube(scene, stalk, 0.008, (120, 124, 130), layer, 6)
        ellipsoid(scene, (sgn * 0.46, 1.47, -0.52), (0.08, 0.052, 0.022), (24, 24, 28), layer, n=18, m=8, e=0.7)
        scene.face([(sgn * 0.46 - 0.068, 1.49, -0.538), (sgn * 0.46 + 0.068, 1.49, -0.538), (sgn * 0.46 + 0.068, 1.445, -0.538), (sgn * 0.46 - 0.068, 1.445, -0.538)],
                   (150, 190, 226), texture=glass or mirror_texture(), layer=layer + 1, two_sided=True, emissive=True)
    # The brake hose from the right lever down to the caliper.
    hose = bezier((0.4, 1.2, -0.52), (0.36, 0.8, -0.36), (0.07, 0.4, -0.1), 14)
    curve_tube(scene, hose, 0.0065, (16, 16, 18), layer - 1, 6)
    # The dashboard housing on the stem, with its screen facing the rider.
    ellipsoid(scene, (0, 1.265, -0.43), (0.125, 0.045, 0.07), (24, 24, 28), layer, n=22, m=8, e=0.55)
    if cluster is not None:
        scene.face([(-0.105, 1.3, -0.5), (0.105, 1.3, -0.5), (0.105, 1.235, -0.5), (-0.105, 1.235, -0.5)], (10, 14, 20),
                   texture=cluster, layer=layer + 1, two_sided=True, emissive=True)
    if phone is not None:
        limb(scene, (-0.2, 1.215, -0.55), (-0.215, 1.255, -0.55), 0.008, 0.008, (30, 30, 34), layer, n=8)
        ellipsoid(scene, (-0.215, 1.34, -0.555), (0.052, 0.09, 0.012), (24, 24, 28), layer, n=14, m=8, e=0.5)
        scene.face([(-0.262, 1.425, -0.569), (-0.168, 1.425, -0.569), (-0.168, 1.255, -0.569), (-0.262, 1.255, -0.569)], (30, 30, 34),
                   texture=phone, layer=layer + 1, two_sided=True, emissive=True)


def scooter_body(scene, show_leg=True, layer=5):
    """The body behind the front wheel: a smooth floorboard with a rubber mat and chrome edges, a rounded pink
    body shell with a pale stripe and a dark skirt, the seat with stitching, and (when asked) Peter's right
    leg with its boot, as seen from the right side."""
    # Floorboard: a flat tray with a ribbed mat and chrome lip.
    mat = [(-0.21, 0.31, -0.5), (0.21, 0.31, -0.5), (0.21, 0.31, -1.2), (-0.21, 0.31, -1.2)]
    scene.face(mat, (44, 44, 48), layer=layer, two_sided=True)
    for gz in np.arange(-0.52, -1.18, -0.06):
        scene.face([(-0.18, 0.312, gz), (0.18, 0.312, gz), (0.18, 0.312, gz - 0.018), (-0.18, 0.312, gz - 0.018)], (28, 28, 32), layer=layer, two_sided=True)
    # The body shell: rings along the bike, a rounded pink belly with a swelling at the seat.
    stations = ((-0.5, 0.5, 0.17, 0.17), (-0.7, 0.52, 0.19, 0.19), (-0.95, 0.55, 0.2, 0.2), (-1.2, 0.57, 0.19, 0.2), (-1.42, 0.6, 0.15, 0.17))
    rings = [ring_points((0, y, z), (1, 0, 0), (0, 1, 0), rx, ry, 22, 0.75) for z, y, rx, ry in stations]

    def shade(k, i):
        # A pale stripe along the flank and a dark skirt under it.
        ang = i / 22
        if 0.0 <= ang < 0.05 or ang > 0.96:
            return (255, 236, 246)
        if 0.62 < ang < 0.9:
            return (42, 42, 46)
        return None

    loft(scene, rings, PINK, layer, caps=(False, False), shade=shade)
    # The seat: a rounded black cushion with a stitched edge.
    seat_rings = [ring_points((0, 0.89 + dy, z), (1, 0, 0), (0, 1, 0), rx, ry, 20, 0.6)
                  for z, rx, ry, dy in ((-0.86, 0.1, 0.03, -0.115), (-1.0, 0.13, 0.04, -0.105), (-1.25, 0.14, 0.045, -0.1), (-1.46, 0.11, 0.03, -0.105))]
    loft(scene, seat_rings, (28, 28, 32), layer + 1, caps=(True, True),
         shade=lambda k, i: (66, 66, 72) if i in (4, 5, 15, 16) else None)
    if show_leg:
        rider_leg(scene, 1, layer + 2)


def rider_leg(scene, sgn, layer):
    """Peter's leg: jeans thigh and shin, a knee, and a boot with a sole, laces and a heel."""
    x = sgn * 0.2
    hip, knee, ankle = (x - sgn * 0.02, 0.96, -1.06), (x, 1.0, -0.64), (x, 0.47, -0.7)
    limb(scene, hip, knee, 0.088, 0.066, JEANS, layer, n=16)
    joint(scene, knee, 0.068, JEANS, layer, 14, 8)
    limb(scene, knee, ankle, 0.064, 0.048, JEANS, layer, n=16)
    # The boot: a rounded shoe with a darker sole and a pale lace strip.
    ellipsoid(scene, (x, 0.4, -0.76), (0.065, 0.06, 0.15), BOOT, layer, n=16, m=10, e=0.85)
    ellipsoid(scene, (x, 0.35, -0.78), (0.07, 0.025, 0.16), (14, 14, 16), layer, n=16, m=6, e=0.7)
    for lz in np.arange(-0.69, -0.86, -0.035):
        scene.face([(x - 0.02, 0.455, lz), (x + 0.02, 0.455, lz), (x + 0.02, 0.455, lz - 0.012), (x - 0.02, 0.455, lz - 0.012)], (200, 200, 204), layer=layer + 1, two_sided=True)
    limb(scene, (x, 0.5, -0.7), (x, 0.44, -0.71), 0.052, 0.058, (36, 36, 40), layer, n=14, bulge=1.0)   # the boot cuff


# ---------------------------------------------------------------- Peter, seen from behind and above

def rider(scene, layer=7, left_only=False):
    """Peter seated on the scooter: pink helmet with a stripe and a rubber rim, black jacket with reflective
    bands, the pink delivery backpack, the arms reaching the grips in gloves, the legs and boots. Built for a
    camera behind him and to his left."""
    lean = 0.16   # how far the chest leans forward per metre of height
    def back(y):
        return -1.12 + lean * (y - 0.95)
    # Torso: a V-tapered jacket, wider at the shoulders, with collar and hem.
    stations = ((0.93, 0.19, 0.13), (1.06, 0.2, 0.14), (1.2, 0.225, 0.15), (1.33, 0.255, 0.145), (1.41, 0.235, 0.12), (1.45, 0.13, 0.1))
    rings = [ring_points((0, y, back(y)), (1, 0, 0), (0, 0, 1), rx, rz, 24, 0.85) for y, rx, rz in stations]

    def shade(k, i):
        if k == 1:   # a reflective band round the lower back
            return (196, 200, 206)
        if k == 0 and i % 3 == 0:
            return (18, 18, 20)
        return None

    loft(scene, rings, JACKET, layer, caps=(True, False), shade=shade)
    # The collar and the neck.
    limb(scene, (0, 1.44, back(1.44)), (0, 1.52, back(1.52) - 0.01), 0.08, 0.07, (32, 32, 36), layer, n=18)
    limb(scene, (0, 1.5, back(1.5)), (0, 1.56, back(1.56) - 0.01), 0.052, 0.05, SKIN, layer, n=14)
    # The delivery backpack: a rounded pink box with a darker lid line, reflective patch and straps.
    bag_c = (0, 1.2, back(1.2) - 0.21)
    ellipsoid(scene, bag_c, (0.2, 0.215, 0.15), PINK, layer + 1, n=26, m=14, e=0.42,
              shade=lambda k, i: (255, 236, 246) if k in (7, 8) and 14 < i < 24 else (PINK_DARK if k == 4 else None))
    for sgn in (-1, 1):
        strap = bezier((sgn * 0.17, 1.43, back(1.43) - 0.02), (sgn * 0.2, 1.3, back(1.3) - 0.07), (sgn * 0.19, 1.14, back(1.14) - 0.1), 8)
        curve_tube(scene, strap, 0.014, (18, 18, 20), layer + 2, 8)
    # Helmet: a glossy pink shell, a pale racing stripe, a black rubber rim and a rear vent.
    head = (0, 1.66, back(1.66) - 0.01)
    def helmet_shade(k, i):
        # Painted on the shell so each mark stays on its own side: a stripe over the top, a dark visor at
        # the front, a white decal at each side and a vent at the back.
        if i in (0, 1, 13, 14, 27) and 2 <= k <= 11 and not (i in (0, 14) and 6 <= k <= 9):
            return (255, 238, 247)
        if 6 <= i <= 9 and 7 <= k <= 8:
            return (22, 26, 40)
        if i in (0, 14) and 6 <= k <= 9:
            return (255, 238, 247)
        if i in (20, 21, 22) and 7 <= k <= 8:
            return (40, 20, 30)
        return None

    ellipsoid(scene, head, (0.158, 0.172, 0.19), PINK, layer + 2, n=28, m=16, e=0.95, shade=helmet_shade)
    ellipsoid(scene, (0, 1.545, back(1.545) - 0.02), (0.152, 0.02, 0.172), (20, 20, 22), layer + 2, n=28, m=4, e=0.9)   # the rubber rim at the bottom edge
    # Arms: shoulder joints, sleeves with elbow bends and a reflective cuff, and gloves on the grips.
    for sgn in (-1, 1):
        shoulder = (sgn * 0.255, 1.36, back(1.36) + 0.0)
        elbow = (sgn * 0.37, 1.12, -0.9)
        wrist = (sgn * 0.435, 1.225, -0.72)
        joint(scene, shoulder, 0.07, JACKET, layer + 1, 14, 8)
        limb(scene, shoulder, elbow, 0.064, 0.052, JACKET, layer + 1, n=16)
        joint(scene, elbow, 0.052, JACKET, layer + 1, 12, 8)
        limb(scene, elbow, wrist, 0.05, 0.04, JACKET, layer + 1, n=16)
        cuff_a = np.array(elbow) + (np.array(wrist) - np.array(elbow)) * 0.82
        limb(scene, cuff_a, wrist, 0.043, 0.043, (206, 210, 216), layer + 1, n=16, bulge=1.0)
        glove(scene, sgn, layer + 2)
    rider_leg(scene, -1, layer)
    rider_leg(scene, 1, layer)


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
    """What the rear wheel needs instead of a fork: a drum cover, a swingarm, a shock with a spring, a black
    mudguard over the back of the tyre, a tail light."""
    R = WHEEL_R
    for sgn in (1, -1):
        layer = near if sgn == side else far
        ring(scene, P, 0.15, sgn * 0.046, 0.05, sgn * 0.06, (150, 154, 160), layer, 40)
    limb(scene, P(side * 0.1, 0, 0), P(side * 0.1, 0.05, 0.6), 0.04, 0.05, (26, 26, 30), near + 1, n=12)   # swingarm
    top = P(side * 0.13, 0.2, 0.16)
    bottom = P(side * 0.13, 0.02, 0.0)
    limb(scene, bottom, top, 0.014, 0.014, (190, 194, 200), near + 1, n=8)
    for i in range(7):   # the spring round the shock
        t0, t1 = i / 7, (i + 0.6) / 7
        a = np.array(bottom) + (np.array(top) - np.array(bottom)) * t0
        b = np.array(bottom) + (np.array(top) - np.array(bottom)) * t1
        limb(scene, a, b, 0.03, 0.03, (214, 40, 46), near + 1, n=10, bulge=1.0)
    steps = 26
    for i in range(steps):
        t0, t1 = -1.5 + 1.75 * i / steps, -1.5 + 1.75 * (i + 1) / steps
        r = 0.345
        sheet = [P(-0.07, r * math.cos(t0), r * math.sin(t0)), P(0.07, r * math.cos(t0), r * math.sin(t0)),
                 P(0.07, r * math.cos(t1), r * math.sin(t1)), P(-0.07, r * math.cos(t1), r * math.sin(t1))]
        scene.face(sheet, (30, 30, 34), layer=near + 1, two_sided=True)
    ellipsoid(scene, P(0, 0.12, -0.38), (0.07, 0.025, 0.02), (214, 30, 36), near + 2, n=14, m=6, e=0.6)   # tail light


def ring(scene, P, r0, lx0, r1, lx1, color, layer, count=40):
    for i in range(count):
        t0, t1 = 2 * math.pi * i / count, 2 * math.pi * (i + 1) / count
        pts = [P(lx0, r0 * math.cos(t0), r0 * math.sin(t0)), P(lx0, r0 * math.cos(t1), r0 * math.sin(t1)),
               P(lx1, r1 * math.cos(t1), r1 * math.sin(t1)), P(lx1, r1 * math.cos(t0), r1 * math.sin(t0))]
        scene.face(pts, color, layer=layer, two_sided=True)
