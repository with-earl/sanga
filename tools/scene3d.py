"""A very small 3D drawing kit for the cutscene stand-ins, so places and objects drawn in code have a
true camera angle, perspective and light, like the telephone in draw_props.py.

Everything is built from flat faces in metres (x to the right, y up, z away from the camera). Faces
are lit by a dim night sky and by point lights (street lamps, a lit doorway, a police light bar),
then drawn back to front. A face can carry a picture (a texture), stretched across it in true
perspective, for things like a building's windows or the writing on a car.
"""

import math

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter


def perspective_coeffs(source, target):
    """Coefficients for Image.transform(PERSPECTIVE) mapping `target` corners back to `source`."""
    rows = []
    for (x, y), (u, v) in zip(target, source):
        rows.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        rows.append([0, 0, 0, x, y, 1, -v * x, -v * y])
    return np.linalg.solve(np.array(rows, float), np.array(source, float).reshape(8)).tolist()


class Camera:
    """A camera at `position`, turned `yaw` degrees to the right and `pitch` degrees up, seeing
    `fov` degrees from the top of the picture to the bottom."""

    def __init__(self, position, yaw, pitch, fov, size):
        self.position = np.array(position, float)
        self.yaw, self.pitch = math.radians(yaw), math.radians(pitch)
        self.size = size
        self.focal = (size[1] / 2) / math.tan(math.radians(fov) / 2)

    def view(self, point):
        x, y, z = np.array(point, float) - self.position
        cy, sy = math.cos(self.yaw), math.sin(self.yaw)
        x, z = x * cy - z * sy, x * sy + z * cy
        cp, sp = math.cos(self.pitch), math.sin(self.pitch)
        y, z = y * cp - z * sp, y * sp + z * cp
        return x, y, z

    def project(self, point):
        """Where a point lands on the picture, and how far away it is."""
        x, y, z = self.view(point)
        z = max(z, 0.05)
        return (self.size[0] / 2 + x * self.focal / z, self.size[1] / 2 - y * self.focal / z, z)

    def pixels_for(self, height: float, distance: float) -> float:
        """How tall something `height` metres tall looks at `distance` metres."""
        return height * self.focal / distance


class Light:
    def __init__(self, position, color, strength, reach=None):
        self.position = np.array(position, float)
        self.color = np.array(color, float) / 255.0
        self.strength = strength
        self.reach = reach


class Scene:
    """Faces to draw, with the sky light and point lights that light them."""

    def __init__(self, camera: Camera, ambient=(60, 70, 110), sky_dir=(-0.3, 1.0, -0.2)):
        self.camera = camera
        self.faces = []
        self.lights = []
        self.ambient = np.array(ambient, float) / 255.0
        sky = np.array(sky_dir, float)
        self.sky_dir = sky / np.linalg.norm(sky)
        self.fog = None      # (colour, density): distant things fade towards the colour, 1 - exp(-density * metres)
        self.depth = None    # set by track_depth(): metres from the camera for every pixel, filled in by render()

    def track_depth(self, size):
        """Asks render() to keep a per-pixel distance map in `self.depth` (infinite where nothing was drawn), for
        depth-of-field and other effects done on the finished picture."""
        self.depth = np.full((size[1], size[0]), np.inf, np.float32)

    def light(self, *args, **kwargs) -> Light:
        light = Light(*args, **kwargs)
        self.lights.append(light)
        return light

    def face(self, points, color=(200, 200, 200), texture=None, glow=None, layer: int = 1,
             emissive: bool = False, two_sided: bool = False, clip=None):
        """A flat face. `texture` is stretched over its first four corners, in order: top left,
        top right, bottom right, bottom left. `glow` is a picture of the same size whose light
        (lit windows, lamps) is added on top, unaffected by the light around it. An emissive
        face glows with its own colour."""
        self.faces.append({"points": [np.array(p, float) for p in points], "color": np.array(color, float),
                           "texture": texture, "glow": glow, "layer": layer, "emissive": emissive,
                           "two_sided": two_sided, "clip": clip})

    def box(self, x0, x1, y0, y1, z0, z1, color, layer=1, emissive=False, skip=()):
        """A box from corner to corner; `skip` leaves out sides, by name."""
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
                self.face(points, color, layer=layer, emissive=emissive)

    def _normal(self, points):
        a, b, c = points[0], points[1], points[2]
        n = np.cross(b - a, c - a)
        return n / (np.linalg.norm(n) + 1e-9)

    def _normal_toward_camera(self, face):
        points = face["points"]
        center = sum(points) / len(points)
        normal = self._normal(points)
        if np.dot(normal, self.camera.position - center) < 0:
            normal = -normal
        return normal, center

    def _ray(self, xs, ys):
        """The direction from the camera through each picture position, in the scene's space."""
        c = self.camera
        vx = (xs - c.size[0] / 2) / c.focal
        vy = -(ys - c.size[1] / 2) / c.focal
        vz = np.ones_like(vx)
        cp, sp = math.cos(c.pitch), math.sin(c.pitch)
        vy, vz = vy * cp + vz * sp, -vy * sp + vz * cp
        cy, sy = math.cos(c.yaw), math.sin(c.yaw)
        vx, vz = vx * cy + vz * sy, -vx * sy + vz * cy
        return np.stack([vx, vy, vz], axis=-1)

    def _distance(self, face, box):
        """How far the face is from the camera, in metres, at every pixel of `box`."""
        normal, center = self._normal_toward_camera(face)
        x0, y0, x1, y1 = box
        ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32) + 0.5
        rays = self._ray(xs, ys)
        denom = rays @ normal
        denom = np.where(np.abs(denom) < 1e-6, 1e-6, denom)
        t = np.dot(center - self.camera.position, normal) / denom
        return np.abs(t) * np.linalg.norm(rays, axis=-1)

    def _light_map(self, face, box):
        """How much light reaches each pixel of a face inside `box`: the sky, plus every lamp, by
        how far the lamp is from that very spot. Lamps right on top of a face (the light bar on
        the car's own roof) do not light it, as they shine outward."""
        normal, center = self._normal_toward_camera(face)
        x0, y0, x1, y1 = box
        ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32) + 0.5
        rays = self._ray(xs, ys)
        denom = rays @ normal
        denom = np.where(np.abs(denom) < 1e-6, 1e-6, denom)
        t = np.dot(center - self.camera.position, normal) / denom
        spots = self.camera.position + rays * t[..., None]
        sky = self.ambient * (0.55 + 0.45 * max(np.dot(normal, self.sky_dir), 0.0))
        light = np.broadcast_to(sky, spots.shape).copy()
        for lamp in self.lights:
            if np.linalg.norm(lamp.position - center) < 1.2 and face["layer"] >= 2:
                continue
            to = lamp.position - spots
            d = np.linalg.norm(to, axis=-1)
            facing = np.clip((to @ normal) / np.maximum(d, 1e-6), 0, 1) * 0.8 + 0.2
            fall = lamp.strength / (1.0 + d * d)
            if lamp.reach:
                fall = fall * np.clip(1.0 - d / lamp.reach, 0, 1)
            light += (fall * facing)[..., None] * lamp.color
        return light

    def render(self, background: Image.Image) -> Image.Image:
        """Draws every face over `background`, back to front within each layer, lit pixel by
        pixel."""
        canvas = background.convert("RGBA")
        size = canvas.size
        prepared = []
        for face in self.faces:
            projected = [self.camera.project(p) for p in face["points"]]
            if min(z for _, _, z in projected) <= 0.06:
                continue
            flat = [(x, y) for x, y, _ in projected]
            area = sum(flat[i][0] * flat[(i + 1) % len(flat)][1] - flat[(i + 1) % len(flat)][0] * flat[i][1]
                       for i in range(len(flat)))
            if area <= 0 and not face["two_sided"]:
                continue
            depth = max(z for _, _, z in projected)
            prepared.append((face["layer"], -depth, flat, face))
        prepared.sort(key=lambda item: (item[0], item[1]))
        out = np.asarray(canvas).astype(np.float32)
        for _, _, flat, face in prepared:
            outline = flat if face["clip"] is None else [self.camera.project(p)[:2] for p in face["clip"]]
            xs = [x for x, _ in outline]
            ys = [y for _, y in outline]
            box = (max(int(min(xs)) - 1, 0), max(int(min(ys)) - 1, 0), min(int(max(xs)) + 2, size[0]), min(int(max(ys)) + 2, size[1]))
            if box[2] <= box[0] or box[3] <= box[1]:
                continue
            mask_img = Image.new("L", size, 0)
            ImageDraw.Draw(mask_img).polygon(outline, fill=255)
            if face["texture"] is not None:
                texture = face["texture"]
                tw, th = texture.size
                coeffs = perspective_coeffs([(0, 0), (tw, 0), (tw, th), (0, th)], flat[:4])
                warped = texture.transform(size, Image.PERSPECTIVE, coeffs, Image.BICUBIC).crop(box)
                mask_img = ImageChops.multiply(mask_img, texture.transform(size, Image.PERSPECTIVE, coeffs, Image.BICUBIC).getchannel("A"))
                base = np.asarray(warped).astype(np.float32)[..., :3] / 255.0
            else:
                base = np.broadcast_to(face["color"] / 255.0, (box[3] - box[1], box[2] - box[0], 3))
            mask = np.asarray(mask_img.crop(box)).astype(np.float32)[..., None] / 255.0
            if face["emissive"]:
                color = base
            else:
                light = self._light_map(face, box)
                # Very bright light rolls off gently instead of turning everything white.
                light = np.where(light > 0.8, 0.8 + (light - 0.8) / (1.0 + (light - 0.8) * 1.6), light)
                color = base * light
            if self.fog is not None or self.depth is not None:
                dist = self._distance(face, box)
                if self.fog is not None:
                    fog_color, density = self.fog
                    amount = np.clip(1.0 - np.exp(-density * dist), 0, 0.92)[..., None]
                    color = np.asarray(color) * (1 - amount) + (np.array(fog_color, np.float32) / 255.0) * amount
                if self.depth is not None:
                    view = self.depth[box[1]:box[3], box[0]:box[2]]
                    view[:] = np.where(mask[..., 0] > 0.5, dist, view)
            region = out[box[1]:box[3], box[0]:box[2], :3]
            out[box[1]:box[3], box[0]:box[2], :3] = region * (1 - mask) + np.clip(color, 0, 1) * 255 * mask
            if face["glow"] is not None:
                glow = face["glow"].transform(size, Image.PERSPECTIVE, coeffs, Image.BICUBIC).crop(box)
                g = np.asarray(glow).astype(np.float32)
                out[box[1]:box[3], box[0]:box[2], :3] += g[..., :3] * (g[..., 3:4] / 255.0) * mask
        return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------- light on the picture


def add_glow(canvas: Image.Image, center, color, radius: float, strength: float) -> Image.Image:
    """Soft light added around a point of the picture (in pixels)."""
    w, h = canvas.size
    ys, xs = np.mgrid[0:h, 0:w]
    d = np.hypot(xs - center[0], ys - center[1]) / radius
    weight = np.exp(-d * d) * strength
    pixels = np.asarray(canvas.convert("RGB")).astype(np.float32)
    pixels += weight[..., None] * np.array(color, np.float32)
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).convert("RGBA")


def add_light_layer(canvas: Image.Image, layer: Image.Image, blur: float) -> Image.Image:
    """Adds a drawn light (beams, reflections) softly on top, brightening what is under it."""
    soft = layer.filter(ImageFilter.GaussianBlur(blur)) if blur else layer
    pixels = np.asarray(canvas.convert("RGB")).astype(np.float32)
    add = np.asarray(soft).astype(np.float32)
    pixels += add[..., :3] * (add[..., 3:4] / 255.0)
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).convert("RGBA")
