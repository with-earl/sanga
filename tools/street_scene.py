"""The street outside Mercy's apartment at night, built in 3D with scene3d.py, for the Padala
cutscenes where the police come (padala_police_car.png) and leave (padala_police_car_leaves.png).

A narrow Manila street: Mercy's apartment building on the right (pale green concrete, window
grilles, a few lit windows, store shutters, the lit doorway), low houses across the street, electric poles with their sagging wires, a sodium street
lamp, and wet asphalt. A police car in Philippine National Police white and blue is parked at the
kerb, its light bar washing the walls and the road in red and blue.
"""

import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import scene3d as s3

FONT_BLACK = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
PX = 60  # texture pixels per metre
RED = (255, 40, 50)
BLUE = (40, 90, 255)
LAMP = (255, 170, 90)
DOOR = (255, 196, 130)


# ---------------------------------------------------------------- textures


def noise(w: int, h: int, scale: float, seed: int) -> np.ndarray:
    """Smooth random blotches between 0 and 1, `scale` pixels across."""
    rng = np.random.default_rng(seed)
    small = rng.random((max(int(h / scale), 2), max(int(w / scale), 2))).astype(np.float32)
    return np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float32) / 255.0


def stained(w: int, h: int, color, seed: int, dirt: float = 0.18) -> Image.Image:
    """A painted concrete wall with soft stains and rain streaks."""
    blotch = noise(w, h, 90, seed) * 0.6 + noise(w, h, 22, seed + 1) * 0.4
    streak = noise(w, h // 40 + 2, 14, seed + 2)
    streak = np.asarray(Image.fromarray((streak * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float32) / 255
    shade = 1.0 - dirt * (blotch * 0.7 + streak * 0.5)
    rgb = np.array(color, np.float32)[None, None, :] * shade[..., None]
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert("RGBA")


def facade_texture(length_m: float, height_m: float, door_z: float):
    """Mercy's building, seen from the street, far end on the left. Returns the wall and the
    light of its lit windows and doorway."""
    w, h = int(length_m * PX), int(height_m * PX)
    wall = stained(w, h, (150, 176, 160), 3)
    light = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d, g = ImageDraw.Draw(wall), ImageDraw.Draw(light)
    rng = np.random.default_rng(11)
    # Floor bands, like concrete slabs showing on the face of the building.
    for floor in range(1, 4):
        y = h - int(floor * 3.2 * PX)
        d.rectangle((0, y - 10, w, y + 8), fill=(126, 148, 136, 255))
        d.line((0, y + 8, w, y + 8), fill=(80, 96, 88, 255), width=4)
    # Windows on the upper floors, with white iron grilles; some lit behind thin curtains.
    for floor in range(1, 4):
        top = h - int((floor * 3.2 + 2.4) * PX)
        for i in range(int(length_m / 3.4)):
            x0 = int((0.9 + i * 3.4) * PX)
            x1, y1 = x0 + int(1.5 * PX), top + int(1.4 * PX)
            lit = rng.random() < 0.3
            d.rectangle((x0 - 8, top - 8, x1 + 8, y1 + 14), fill=(110, 128, 118, 255))
            d.rectangle((x0, top, x1, y1), fill=(30, 34, 44, 255))
            if lit:
                warm = (255, 190 + int(rng.random() * 40), 120, 255)
                g.rectangle((x0, top, x1, y1), fill=warm)
                g.rectangle((x0 + 6, top + 4, x0 + (x1 - x0) // 3, y1), fill=(230, 150, 90, 255))
            for k in range(1, 6):
                x = x0 + k * (x1 - x0) // 6
                d.line((x, top, x, y1), fill=(220, 224, 226, 255), width=4)
                g.line((x, top, x, y1), fill=(0, 0, 0, 0), width=4)
            for k in (1, 2):
                y = top + k * (y1 - top) // 3
                d.line((x0, y, x1, y), fill=(220, 224, 226, 255), width=4)
                g.line((x0, y, x1, y), fill=(0, 0, 0, 0), width=4)
            # An air-conditioner box under some windows.
            if rng.random() < 0.35:
                d.rectangle((x1 - 50, y1 + 22, x1 + 10, y1 + 70), fill=(196, 200, 196, 255))
                d.rectangle((x1 - 46, y1 + 26, x1 + 6, y1 + 66), outline=(150, 154, 150, 255), width=3)
    # The ground floor: store shutters, and the building's doorway, lit from inside.
    ground = h - int(3.0 * PX)
    door_x = int((length_m - door_z) * PX)
    for i in range(int(length_m / 5.0)):
        x0 = int((0.6 + i * 5.0) * PX)
        if abs(x0 - door_x) < 4 * PX:
            continue
        x1 = x0 + int(3.6 * PX)
        d.rectangle((x0, ground + 30, x1, h), fill=(120, 124, 128, 255))
        for y in range(ground + 40, h, 14):
            d.line((x0, y, x1, y), fill=(92, 96, 100, 255), width=3)
    dw = int(1.3 * PX)
    d.rectangle((door_x - dw // 2 - 14, h - int(2.5 * PX) - 14, door_x + dw // 2 + 14, h), fill=(96, 70, 52, 255))
    g.rectangle((door_x - dw // 2, h - int(2.5 * PX), door_x + dw // 2, h), fill=DOOR + (255,))
    # A stairwell inside the doorway, darker toward the top.
    for k in range(6):
        y = h - int((0.2 + k * 0.35) * PX)
        g.line((door_x - dw // 2, y, door_x + dw // 2, y - 20), fill=(200, 140, 90, 255), width=6)
    return wall, light


def road_texture(width_m: float, length_m: float) -> Image.Image:
    """Wet asphalt with a dashed centre line, far end at the top."""
    w, h = int(width_m * 40), int(length_m * 40)
    base = noise(w, h, 6, 21) * 0.5 + noise(w, h, 60, 22) * 0.5
    rgb = np.stack([38 + base * 18, 40 + base * 18, 46 + base * 20], axis=-1)
    road = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(road)
    centre = int(w * 0.5)
    for y in range(0, h, 240):
        d.rectangle((centre - 5, y, centre + 5, y + 120), fill=(196, 190, 170, 255))
    # Puddles: darker, smoother patches.
    wet = noise(w, h, 80, 23)
    mask = Image.fromarray((np.clip((wet - 0.62) * 6, 0, 1) * 120).astype(np.uint8))
    road.paste(Image.new("RGBA", (w, h), (24, 26, 32, 255)), (0, 0), mask)
    return road


def pavement_texture(width_m: float, length_m: float) -> Image.Image:
    w, h = int(width_m * 40), int(length_m * 40)
    base = noise(w, h, 5, 31)
    rgb = np.stack([96 + base * 20, 96 + base * 20, 98 + base * 22], axis=-1)
    tile = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(tile)
    for y in range(0, h, 40):
        d.line((0, y, w, y), fill=(70, 70, 74, 255), width=2)
    return tile


def car_side_texture(flip: bool) -> Image.Image:
    """A police car's side, front on the left: white, a blue band with a thin red line, and
    POLICE on the doors."""
    w, h = int(4.6 * 120), int(0.7 * 120)
    side = Image.new("RGBA", (w, h), (236, 238, 240, 255))
    d = ImageDraw.Draw(side)
    d.rectangle((0, int(h * 0.42), w, int(h * 0.7)), fill=(26, 60, 160, 255))
    d.rectangle((0, int(h * 0.7), w, int(h * 0.76)), fill=(200, 30, 40, 255))
    text = "POLICE"
    font = ImageFont.truetype(FONT_BLACK, int(h * 0.24))
    tw = d.textlength(text, font=font)
    d.text((w * 0.47 - tw / 2, int(h * 0.44)), text, font=font, fill=(255, 255, 255, 255))
    # A dark rubbing strip low down, and the shadowed wheel arches.
    d.rectangle((0, int(h * 0.86), w, h), fill=(60, 62, 68, 255))
    for x in (0.18, 0.8):
        d.ellipse((w * x - 58, h * 0.52, w * x + 58, h * 1.6), fill=(30, 30, 34, 255))
    # Door seams and handles.
    for x in (0.33, 0.6):
        d.line((w * x, 0, w * x, h), fill=(150, 154, 160, 255), width=3)
        d.rectangle((w * x + 28, h * 0.22, w * x + 64, h * 0.3), fill=(120, 124, 130, 255))
    return side.transpose(Image.FLIP_LEFT_RIGHT) if flip else side


def glass_texture(w: int, h: int) -> Image.Image:
    """Dark car glass with a soft reflection."""
    g = Image.new("RGBA", (w, h), (24, 28, 40, 255))
    d = ImageDraw.Draw(g)
    d.polygon([(w * 0.15, 0), (w * 0.4, 0), (w * 0.2, h), (w * 0.0, h)], fill=(52, 60, 82, 255))
    return g.filter(ImageFilter.GaussianBlur(3))


# ---------------------------------------------------------------- the car


class Car:
    """A sedan in the car's own space: x across (left negative), y up, z along (front negative),
    placed into the street by a position and a turn."""

    LENGTH, WIDTH = 4.5, 1.76

    def __init__(self, scene: s3.Scene, position, yaw_degrees: float):
        self.scene = scene
        self.position = np.array(position, float)
        self.yaw = math.radians(yaw_degrees)

    def world(self, p):
        x, y, z = p
        c, s = math.cos(self.yaw), math.sin(self.yaw)
        return (self.position[0] + x * c + z * s, self.position[1] + y, self.position[2] - x * s + z * c)

    def face(self, points, color, **kwargs):
        """A face given in the car's space, turned to face outward from the car's middle."""
        keep_order = kwargs.pop("keep_order", False)
        pts = [np.array(self.world(p)) for p in points]
        middle = np.array(self.world((0, 0.75, 0)))
        normal = np.cross(pts[1] - pts[0], pts[2] - pts[0])
        center = sum(pts) / len(pts)
        if np.dot(normal, center - middle) < 0 and not keep_order:
            pts = pts[::-1]
        self.scene.face(pts, color, **kwargs)

    def prism(self, profile, half_width, color, side_texture=None, top_color=None, skip_sides=False, layer=2):
        """A shape drawn from the side (`profile`: (z, y) points going round) and pushed out to
        both sides, `half_width` from the middle."""
        n = len(profile)
        for i in range(n):
            (z0, y0), (z1, y1) = profile[i], profile[(i + 1) % n]
            c = top_color if (top_color and y0 > 0.8 and y1 > 0.8) else color
            self.face([(-half_width, y0, z0), (half_width, y0, z0), (half_width, y1, z1), (-half_width, y1, z1)], c, layer=layer)
        if skip_sides:
            return
        for x in (-half_width, half_width):
            self.face([(x, y, z) for z, y in profile], color, layer=layer)

    def build(self, side_texture: Image.Image, bar_on: bool = True) -> None:
        white, dark = (236, 238, 240), (24, 24, 28)
        hw = self.WIDTH / 2
        # The body: bumper, bonnet, the belt line along the sides, boot and rear bumper.
        body = [(-2.25, 0.3), (-2.3, 0.58), (-2.18, 0.8), (-0.9, 0.9), (1.05, 0.92), (2.18, 0.88),
                (2.27, 0.6), (2.22, 0.3)]
        self.prism(body, hw, white, skip_sides=True)
        # The body's sides carry the livery, stretched over the side's bounding box.
        # The livery is the same both sides (the writing is never mirrored). Corners go top left,
        # top right, bottom right, bottom left as seen from outside each side.
        sides = (
            (-hw, [(-hw, 1.0, 2.3), (-hw, 1.0, -2.3), (-hw, 0.3, -2.3), (-hw, 0.3, 2.3)], side_texture),
            (hw, [(hw, 1.0, -2.3), (hw, 1.0, 2.3), (hw, 0.3, 2.3), (hw, 0.3, -2.3)], side_texture),
        )
        for x, corners, texture in sides:
            pts = [np.array(self.world(p)) for p in corners]
            outline = [np.array(self.world((x, y, z))) for z, y in body]
            self._textured_side(pts, outline, texture)
        # The cabin, narrower, with dark glass all round.
        cabin = [(-0.9, 0.9), (-0.3, 1.42), (0.62, 1.44), (1.05, 0.92)]
        cw = hw - 0.1
        for i in range(3):
            (z0, y0), (z1, y1) = cabin[i], cabin[i + 1]
            color = white if i == 1 else (30, 34, 46)
            self.face([(-cw, y0, z0), (cw, y0, z0), (cw, y1, z1), (-cw, y1, z1)], color, layer=2)
        for x in (-cw, cw):
            self.face([(x, y, z) for z, y in cabin], (30, 34, 46), layer=2)
            # Door pillars over the glass.
            self.face([(x * 1.01, 0.92, 0.12), (x * 1.01, 1.43, 0.12), (x * 1.01, 1.43, 0.22), (x * 1.01, 0.92, 0.22)], white, layer=3, two_sided=True)
        # The light bar on the roof: red on the left, blue on the right.
        self.box_local(-0.62, 0.0, 1.44, 1.56, 0.05, 0.32, RED if bar_on else (120, 30, 34), emissive=bar_on)
        self.box_local(0.0, 0.62, 1.44, 1.56, 0.05, 0.32, BLUE if bar_on else (30, 46, 120), emissive=bar_on)
        # Wheels: dark tyres with a grey rim, turned to show their faces on the near side.
        for z in (-1.42, 1.38):
            for x in (-hw + 0.02, hw - 0.02):
                self.wheel(x, z)
        # Headlights, grille and number plate on the front; tail lights on the back.
        for x in (-0.62, 0.62):
            self.face([(x - 0.2, 0.74, -2.2), (x + 0.2, 0.74, -2.2), (x + 0.2, 0.64, -2.24), (x - 0.2, 0.64, -2.24)], (255, 250, 230), layer=3, emissive=True)
            self.face([(x - 0.22, 0.74, 2.2), (x + 0.22, 0.74, 2.2), (x + 0.22, 0.62, 2.24), (x - 0.22, 0.62, 2.24)], (220, 30, 30), layer=3, emissive=True)
        self.face([(-0.38, 0.6, -2.29), (0.38, 0.6, -2.29), (0.38, 0.5, -2.29), (-0.38, 0.5, -2.29)], dark, layer=3)
        self.face([(-0.26, 0.45, -2.31), (0.26, 0.45, -2.31), (0.26, 0.36, -2.31), (-0.26, 0.36, -2.31)], (230, 230, 220), layer=3)

    def _textured_side(self, corners, outline, texture) -> None:
        """A side panel: the livery picture over its box, trimmed to the body's outline."""
        middle = np.array(self.world((0, 0.75, 0)))
        normal = np.cross(corners[1] - corners[0], corners[2] - corners[0])
        center = sum(corners) / 4
        if np.dot(normal, center - middle) < 0:
            return
        self.scene.face(corners, (236, 238, 240), texture=texture, layer=2, clip=outline)

    def box_local(self, x0, x1, y0, y1, z0, z1, color, emissive=False):
        sides = [
            [(x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (x0, y0, z0)],
            [(x1, y1, z1), (x0, y1, z1), (x0, y0, z1), (x1, y0, z1)],
            [(x0, y1, z1), (x0, y1, z0), (x0, y0, z0), (x0, y0, z1)],
            [(x1, y1, z0), (x1, y1, z1), (x1, y0, z1), (x1, y0, z0)],
            [(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)],
        ]
        for points in sides:
            self.face(points, color, layer=3, emissive=emissive)

    def wheel(self, x, z, radius=0.33, width=0.24) -> None:
        inner = x - math.copysign(width, x)
        ring = [(math.sin(a) * radius, 0.33 + math.cos(a) * radius) for a in np.linspace(0, 2 * math.pi, 16, endpoint=False)]
        for i in range(16):
            (dz0, y0), (dz1, y1) = ring[i], ring[(i + 1) % 16]
            self.face([(x, y0, z + dz0), (x, y1, z + dz1), (inner, y1, z + dz1), (inner, y0, z + dz0)], (20, 20, 22), layer=1)
        self.face([(x, y, z + dz) for dz, y in ring], (22, 22, 24), layer=3)
        rim = [(dz * 0.6, 0.33 + (y - 0.33) * 0.6) for dz, y in ring]
        self.face([(x * 1.005, y, z + dz) for dz, y in rim], (150, 154, 160), layer=3)
        hub = [(dz * 0.2, 0.33 + (y - 0.33) * 0.2) for dz, y in ring]
        self.face([(x * 1.01, y, z + dz) for dz, y in hub], (90, 92, 96), layer=3)

    def top_point(self, x):
        return self.world((x, 1.56, 0.18))


# ---------------------------------------------------------------- the street


def draw(size, car_at=(2.15, 0.0, 9.4), car_yaw=-14.0, leaving=False, people=None, bar_on=True) -> Image.Image:
    """The night street with the police car. `leaving` drives it away down the street, its tail
    lights toward us. `people` is a list of (picture, x, z, height in metres) to stand on the
    pavement as dark shapes against the light."""
    w, h = size
    camera = s3.Camera((-0.6, 1.45, 0.0), 14.0, -2.0, 44.0, size)
    scene = s3.Scene(camera, ambient=(70, 82, 130))
    # Sky: deep blue at the top, a faint orange city glow at the horizon.
    ys = np.linspace(0, 1, h)[:, None]
    sky = np.concatenate([np.repeat(ys * 0, w, 1)[..., None]] * 3, axis=2)
    top, bottom = np.array([8, 12, 30]), np.array([60, 46, 60])
    sky = (top + (bottom - top) * ys[..., None] ** 1.6) * np.ones((h, w, 1))
    canvas = Image.fromarray(sky.astype(np.uint8)).convert("RGBA")

    building_far, building_near, door_z = 70.0, 2.0, 7.4
    facade, facade_light = facade_texture(building_far - building_near, 13.0, door_z - building_near)
    scene.face([(4.8, 13, building_far), (4.8, 13, building_near), (4.8, 0, building_near), (4.8, 0, building_far)],
               (150, 176, 160), texture=facade, glow=facade_light, layer=0)
    # The roof edge of Mercy's building against the sky.
    scene.face([(4.8, 13.4, building_far), (4.8, 13.4, building_near), (4.8, 13.0, building_near), (4.8, 13.0, building_far)], (90, 100, 96), layer=0)
    # Across the street: low houses.
    houses, houses_light = facade_texture(16.0, 6.5, 8.0)
    scene.face([(-9.0, 6.5, 23.0), (-9.0, 6.5, 39.0), (-9.0, 0, 39.0), (-9.0, 0, 23.0)], (120, 110, 100), texture=houses.transpose(Image.FLIP_LEFT_RIGHT), glow=houses_light.transpose(Image.FLIP_LEFT_RIGHT), layer=0)
    # Pavements, kerbs and the road.
    scene.face([(-7.0, 0, 120), (3.2, 0, 120), (3.2, 0, 2), (-7.0, 0, 2)], (44, 46, 52), texture=road_texture(10.2, 118), layer=0)
    scene.face([(3.2, 0.15, 120), (4.8, 0.15, 120), (4.8, 0.15, 1), (3.2, 0.15, 1)], (100, 100, 104), texture=pavement_texture(1.6, 118), layer=0)
    scene.face([(3.2, 0.15, 2), (3.2, 0.15, 120), (3.2, 0, 120), (3.2, 0, 2)], (130, 130, 128), layer=0, two_sided=True)
    scene.face([(-10.5, 0.15, 120), (-7.0, 0.15, 120), (-7.0, 0.15, 2), (-10.5, 0.15, 2)], (90, 90, 94), layer=0)
    # Far away down the street: dark blocks of the city.
    rng = np.random.default_rng(5)
    for i in range(12):
        x0 = -16 + i * 3.2
        top = 6 + rng.random() * 14
        scene.face([(x0, top, 118), (x0 + 3.0, top, 118), (x0 + 3.0, 0, 118), (x0, 0, 118)], (34, 34, 46), layer=0)
    # Electric poles along the pavement, and the street lamp.
    poles = [11.5, 27.0, 43.0, 59.0]
    for z in poles:
        scene.box(3.35, 3.6, 0.15, 9.5, z, z + 0.25, (110, 104, 96), layer=1)
        scene.box(2.2, 4.4, 8.6, 8.8, z, z + 0.25, (90, 86, 80), layer=1)
    scene.box(3.4, 3.58, 0.15, 6.8, 17.0, 17.18, (90, 92, 96), layer=1)
    scene.box(2.0, 3.5, 6.6, 6.74, 17.0, 17.18, (90, 92, 96), layer=1)
    scene.box(1.9, 2.5, 6.42, 6.6, 16.94, 17.24, (255, 214, 150), layer=1, emissive=True)
    scene.light((2.2, 6.3, 17.1), LAMP, 22.0, reach=30)
    scene.light((4.6, 1.6, door_z), DOOR, 3.0, reach=8)

    car = Car(scene, car_at, car_yaw if not leaving else 180 + car_yaw)
    car.build(car_side_texture(False), bar_on)
    bar_red, bar_blue = car.top_point(-0.4), car.top_point(0.4)
    if bar_on:
        scene.light(bar_red, RED, 7.0, reach=26)
        scene.light(bar_blue, BLUE, 7.0, reach=26)

    # People on the pavement: flat cut-outs facing us, dark against the doorway's light. They
    # stand in the scene, so the car hides whoever is behind it.
    for picture, x, z, height in people or []:
        half = height * picture.width / picture.height / 2
        shape = Image.new("RGBA", picture.size, (16, 12, 16, 255))
        shape.putalpha(picture.getchannel("A"))
        # Turned square to the camera, so nobody looks thin.
        look = np.array([x, z]) - camera.position[[0, 2]]
        across = np.array([look[1], -look[0]]) / np.linalg.norm(look) * half
        left, right = np.array([x, z]) - across, np.array([x, z]) + across
        scene.face([(left[0], 0.15 + height, left[1]), (right[0], 0.15 + height, right[1]),
                    (right[0], 0.15, right[1]), (left[0], 0.15, left[1])], (16, 12, 16),
                   texture=shape, layer=1, emissive=True, two_sided=True)

    canvas = scene.render(canvas)

    # Wires between the poles, sagging, and to the building.
    wires = Image.new("RGBA", size, (0, 0, 0, 0))
    wd = ImageDraw.Draw(wires)
    for k, (dx, dy) in enumerate(((2.3, 8.7), (3.0, 8.7), (4.3, 8.7), (3.5, 9.4))):
        for a, b in zip(poles, poles[1:]):
            pts = []
            for t in np.linspace(0, 1, 24):
                z = a + (b - a) * t + 0.12
                y = dy - 0.9 * 4 * t * (1 - t) - k * 0.05
                pts.append(camera.project((dx, y, z))[:2])
            wd.line(pts, fill=(14, 14, 20, 255), width=max(int(w / 900), 2))
        pts = [camera.project((dx, dy - 0.2, 6.6))[:2], camera.project((-1.0, 7.5, 2.0))[:2]]
        wd.line(pts, fill=(14, 14, 20, 255), width=max(int(w / 700), 2))
    canvas.alpha_composite(wires)

    # Light in the air: the lamp's cone, the light bar's glow, reflections on the wet road.
    lamp = camera.project((2.2, 6.3, 17.1))
    cone = Image.new("RGBA", size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(cone)
    floor_l, floor_r = camera.project((0.0, 0, 17.1)), camera.project((4.6, 0.15, 17.1))
    cd.polygon([lamp[:2], floor_l[:2], floor_r[:2]], fill=LAMP + (46,))
    canvas = s3.add_light_layer(canvas, cone, w / 60)
    canvas = s3.add_glow(canvas, lamp[:2], LAMP, w / 40, 0.9)
    reflections = Image.new("RGBA", size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(reflections)
    for point, color in ([(bar_red, RED), (bar_blue, BLUE)] if bar_on else []) + [((2.2, 6.3, 17.1), LAMP)]:
        top = camera.project((point[0], 0.0, point[2]))
        drop = camera.project((point[0], 0.0, point[2] - 4.0))
        width = w / 90
        rd.rectangle((top[0] - width, top[1], top[0] + width, drop[1]), fill=color + (90,))
    canvas = s3.add_light_layer(canvas, reflections, w / 160)
    for point, color in ((bar_red, RED), (bar_blue, BLUE)) if bar_on else ():
        p = camera.project(point)
        canvas = s3.add_glow(canvas, p[:2], color, w / 8, 0.22)
        canvas = s3.add_glow(canvas, p[:2], color, w / 40, 0.7)
        canvas = s3.add_glow(canvas, p[:2], (255, 255, 255), w / 200, 0.8)
    if not leaving:
        for x in (-0.62, 0.62):
            p = camera.project(car.world((x, 0.69, -2.25)))
            canvas = s3.add_glow(canvas, p[:2], (255, 246, 220), w / 90, 0.6)
    else:
        for x in (-0.62, 0.62):
            p = camera.project(car.world((x, 0.68, 2.25)))
            canvas = s3.add_glow(canvas, p[:2], (255, 40, 40), w / 70, 0.7)
    return finish(canvas)


def finish(canvas: Image.Image) -> Image.Image:
    """Makes the clean 3D drawing look painted and filmed: lights bloom, the distance hazes
    over, edges soften a little, and a fine grain sits over it all."""
    w, h = canvas.size
    pixels = np.asarray(canvas.convert("RGB")).astype(np.float32)
    bright = np.clip(pixels - 150, 0, 255)
    bloom = np.asarray(Image.fromarray(bright.astype(np.uint8)).filter(ImageFilter.GaussianBlur(w / 70))).astype(np.float32)
    pixels += bloom * 0.9
    # City haze near the horizon, warm, as if the night air held the street lights.
    ys = np.linspace(0, 1, h)[:, None]
    haze = np.exp(-((ys - 0.47) / 0.12) ** 2) * 26
    pixels += haze[..., None] * np.array([1.0, 0.75, 0.8])[None, None, :]
    image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.9))
    pixels = np.asarray(image).astype(np.float32)
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)) / 1.414
    pixels *= (1 - np.clip((edge - 0.4) / 0.6, 0, 1) ** 1.5 * 0.55)[..., None]
    pixels += np.random.default_rng(3).normal(0, 4.5, (h, w))[..., None]
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).convert("RGBA")
