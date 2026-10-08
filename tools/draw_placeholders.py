"""Draws stand-in cutscene pictures for scenes whose final art is not painted yet.

Each stand-in is put together from the game's own art: a place's
background (cropped, blurred or recoloured for the moment: night, dawn, police lights, a
flashback), the characters' full-body pictures placed in it (their sad pictures where it fits,
dark silhouettes for someone not yet revealed), and props (the keys, the telephone, the toy guns
cut from the market stall). Simple effects finish the mood: a gunshot's flash, motion blur for
running, a confessional grille, a television, a bus window. There is no text on them, so they read
as part of the game until the real paintings arrive.

Replace a stand-in by saving the real painting under the same name and removing its line from
assets/cutscenes/PLACEHOLDERS.txt. Pictures not listed there are never touched.

Run: python tools/draw_placeholders.py [name ...]   (needs Pillow and numpy)
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import object_scenes  # noqa: E402  (beside this file)
import street_scene  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CUTSCENES = ROOT / "assets" / "cutscenes"
BACKGROUNDS = ROOT / "assets" / "backgrounds"
PORTRAITS = ROOT / "assets" / "portraits"
CHARACTERS = ROOT / "assets" / "characters"
PROPS = ROOT / "assets" / "props"
SIZE = (1672, 941)
W, H = SIZE
## Stand-ins are saved at the game's own size with 256 finely dithered colours: next to the full
## picture the difference is hard to see (and the game softens pictures anyway), and each file is a
## quarter of the size, which matters for the web build loading on a phone.
SAVE_SIZE = (1280, 720)
SAVE_COLORS = 256
## The list of pictures that are stand-ins, so real paintings are never drawn over.
LIST_FILE = CUTSCENES / "PLACEHOLDERS.txt"

## Each character's picture, and whether it looks to the right (see DialogueBox.faces_right).
PEOPLE = {
    "peter": ("peter_1", True), "gwen": ("gwen_1", True), "gwen_sad": ("gwen_2", False),
    "ben": ("ben_1", True), "eli": ("father_eli", True), "kulas": ("kulas_1", False),
    "mercy": ("mercy_1", False), "gloria": ("gloria_1", True), "gloria_sad": ("gloria_2", False),
    "batista": ("batista_1", False), "batista_sad": ("batista_2", True),
}
## Toy guns in their shop bags, cut from the market background (in its own pixels).
GUN_BOXES = {"real_gun": (1450, 509, 1641, 692), "water_gun": (1293, 509, 1453, 692)}


# ---------------------------------------------------------------- loading


def background(name: str, crop=None, blur: float = 0.0) -> Image.Image:
    """A place's background at the cutscene size; `crop` is (x, y, width, height) in shares."""
    image = Image.open(BACKGROUNDS / f"{name}.png").convert("RGB").resize(SIZE, Image.LANCZOS)
    if crop:
        x, y, w, h = crop
        image = image.crop((int(x * W), int(y * H), int((x + w) * W), int((y + h) * H))).resize(SIZE, Image.LANCZOS)
    if blur:
        image = image.filter(ImageFilter.GaussianBlur(blur))
    return image.convert("RGBA")


def person(who: str, face_right: bool | None = None) -> Image.Image:
    """A character's full picture, turned to look the way asked (None keeps it as drawn)."""
    file, looks_right = PEOPLE[who]
    image = Image.open(PORTRAITS / f"{file}.png").convert("RGBA")
    if face_right is not None and face_right != looks_right:
        image = image.transpose(Image.FLIP_LEFT_RIGHT)
    return image


def bust(name: str, flip: bool = False) -> Image.Image:
    image = Image.open(CHARACTERS / f"{name}.png").convert("RGBA")
    return image.transpose(Image.FLIP_LEFT_RIGHT) if flip else image


def prop(name: str) -> Image.Image:
    if name in GUN_BOXES:
        market = Image.open(BACKGROUNDS / "public_market.png").convert("RGBA")
        return market.crop(GUN_BOXES[name])
    return Image.open(PROPS / f"{name}.png").convert("RGBA")


# ---------------------------------------------------------------- placing


def scaled(image: Image.Image, height: float) -> Image.Image:
    """Scales to a height given as a share of the picture's height."""
    h = max(int(height * H), 1)
    return image.resize((max(int(image.width * h / image.height), 1), h), Image.LANCZOS)


def place(canvas: Image.Image, image: Image.Image, x: float, bottom: float, height: float,
          shadow: bool = True, rotate: float = 0.0) -> None:
    """Puts `image` with its bottom centre at (x, bottom), shares of the picture, `height` tall."""
    image = scaled(image, height)
    if rotate:
        image = image.rotate(rotate, expand=True, resample=Image.BICUBIC)
    left = int(x * W - image.width / 2)
    top = int(bottom * H - image.height)
    if shadow:
        shade = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        ImageDraw.Draw(shade).ellipse((left + image.width * 0.1, bottom * H - 14, left + image.width * 0.9, bottom * H + 14), fill=(20, 10, 5, 110))
        canvas.alpha_composite(shade.filter(ImageFilter.GaussianBlur(10)))
    canvas.alpha_composite(image, (left, top))


def lying(image: Image.Image) -> Image.Image:
    """Someone fallen: the picture turned on its side."""
    return image.rotate(90, expand=True, resample=Image.BICUBIC)


def silhouette(image: Image.Image, color=(12, 8, 10), keep: float = 0.0) -> Image.Image:
    """A dark shape of the picture; `keep` lets a little of the picture show through."""
    shape = Image.new("RGBA", image.size, color + (255,))
    shape.putalpha(image.getchannel("A"))
    return Image.blend(shape, image, keep) if keep else shape


def tinted(image: Image.Image, color, amount: float) -> Image.Image:
    """Bathes a picture (people included) in coloured light."""
    flat = Image.new("RGBA", image.size, color + (255,))
    mixed = ImageChops.multiply(image, flat)
    out = Image.blend(image, mixed, amount)
    out.putalpha(image.getchannel("A"))
    return out


def motion(image: Image.Image, reach: int = 24) -> Image.Image:
    """Blurs sideways, for someone running."""
    pixels = np.asarray(image).astype(np.float32)
    total = np.zeros_like(pixels)
    for shift in range(-reach, reach + 1, 4):
        total += np.roll(pixels, shift, axis=1)
    total /= len(range(-reach, reach + 1, 4))
    return Image.fromarray(total.astype(np.uint8), "RGBA")


# ---------------------------------------------------------------- mood


def grade(canvas: Image.Image, brightness=1.0, saturation=1.0, tint=None, tint_amount=0.0, contrast=1.0) -> Image.Image:
    rgb = canvas.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(brightness)
    rgb = ImageEnhance.Color(rgb).enhance(saturation)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    if tint:
        rgb = Image.blend(rgb, ImageChops.multiply(rgb, Image.new("RGB", SIZE, tint)), tint_amount)
    return rgb.convert("RGBA")


def night(canvas: Image.Image) -> Image.Image:
    return grade(canvas, brightness=0.42, saturation=0.55, tint=(110, 140, 220), tint_amount=0.7)


def dawn(canvas: Image.Image) -> Image.Image:
    out = grade(canvas, brightness=0.9, saturation=0.85, tint=(255, 190, 170), tint_amount=0.45)
    return glow(out, (0.5, 0.0), (255, 170, 120), 0.35, 0.9)


def morning(canvas: Image.Image) -> Image.Image:
    out = grade(canvas, brightness=1.08, saturation=0.95, tint=(255, 240, 215), tint_amount=0.3)
    return glow(out, (0.15, 0.1), (255, 236, 200), 0.3, 0.8)


def sepia(canvas: Image.Image) -> Image.Image:
    out = grade(canvas, saturation=0.2, tint=(255, 215, 160), tint_amount=0.8, contrast=0.9)
    return vignette(out, 0.6, (60, 40, 20))


def glow(canvas: Image.Image, center, color, strength: float, reach: float) -> Image.Image:
    """Soft light added around `center` (shares), fading out by `reach` (share of the width)."""
    ys, xs = np.mgrid[0:H, 0:W]
    d = np.hypot((xs - center[0] * W) / W, (ys - center[1] * H) / W)
    weight = np.clip(1.0 - d / reach, 0, 1) ** 2 * strength
    pixels = np.asarray(canvas.convert("RGB")).astype(np.float32)
    pixels += weight[..., None] * np.array(color, np.float32)
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).convert("RGBA")


def vignette(canvas: Image.Image, strength: float = 0.55, color=(0, 0, 0)) -> Image.Image:
    ys, xs = np.mgrid[0:H, 0:W]
    d = np.hypot((xs - W / 2) / (W / 2), (ys - H / 2) / (H / 2)) / 1.414
    weight = np.clip((d - 0.35) / 0.65, 0, 1) ** 1.6 * strength
    pixels = np.asarray(canvas.convert("RGB")).astype(np.float32)
    pixels = pixels * (1 - weight[..., None]) + np.array(color, np.float32) * weight[..., None]
    return Image.fromarray(pixels.astype(np.uint8)).convert("RGBA")


def police_lights(canvas: Image.Image, strength: float = 0.5) -> Image.Image:
    out = glow(canvas, (0.0, 0.3), (230, 40, 40), strength, 0.7)
    return glow(out, (1.0, 0.3), (40, 80, 255), strength, 0.7)


def flash(canvas: Image.Image, center=(0.5, 0.45)) -> Image.Image:
    """A gunshot: a hard white burst fading to red at the edges."""
    out = vignette(canvas, 0.7, (90, 0, 0))
    return glow(out, center, (255, 240, 220), 0.9, 0.35)


def grille(canvas: Image.Image, spacing: int = 46, width: int = 9, color=(28, 16, 10, 235)) -> Image.Image:
    """A confessional's lattice in front of everything."""
    layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k in range(-H, W + H, spacing):
        d.line((k, 0, k + H, H), fill=color, width=width)
        d.line((k, H, k + H, 0), fill=color, width=width)
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.2)))
    return canvas


def grain(canvas: Image.Image, amount: float = 6.0) -> Image.Image:
    rng = np.random.default_rng(7)
    pixels = np.asarray(canvas.convert("RGB")).astype(np.float32)
    pixels += rng.normal(0, amount, pixels.shape[:2])[..., None]
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).convert("RGBA")


def frame_around(inner: Image.Image, box, outer: Image.Image, border=(18, 16, 18), width: int = 26, radius: int = 22) -> Image.Image:
    """Shows `inner` inside a rounded frame at `box` (shares) over `outer`: a TV, a window."""
    x0, y0, x1, y1 = int(box[0] * W), int(box[1] * H), int(box[2] * W), int(box[3] * H)
    canvas = outer.copy()
    ImageDraw.Draw(canvas).rounded_rectangle((x0 - width, y0 - width, x1 + width, y1 + width), radius + width, fill=border + (255,))
    screen = inner.resize((x1 - x0, y1 - y0), Image.LANCZOS)
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, screen.width - 1, screen.height - 1), radius, fill=255)
    canvas.paste(screen, (x0, y0), mask)
    return canvas


# ---------------------------------------------------------------- the shots


def tokhang_rider() -> Image.Image:
    """The opening picture: Peter, the rider, with his motorbike, on the blurred market behind
    him. He is the same drawing as in the dialogue and in every other scene."""
    c = background("public_market", blur=9)
    place(c, person("peter", True), 0.3, 1.03, 0.84)
    place(c, prop("motor"), 0.7, 1.0, 0.5)
    return vignette(grade(c, 1.0, 1.05), 0.35)


def shot_market_holding(buyer: str) -> Image.Image:
    c = background("public_market", blur=1.5)
    place(c, person("gloria", True), 0.2, 0.98, 0.62)
    place(c, person(buyer, False), 0.6, 1.04, 0.86)
    place(c, prop("real_gun"), 0.5, 0.66, 0.2, shadow=False)
    return vignette(grade(c, 0.95, 0.9, (255, 200, 180), 0.25), 0.5)


def shot_market_down(who: str) -> Image.Image:
    c = background("public_market", blur=3)
    place(c, silhouette(person("batista", False), keep=0.15), 0.88, 0.96, 0.8)
    place(c, tinted(lying(person(who)), (200, 120, 110), 0.5), 0.42, 0.98, 0.24, shadow=False)
    place(c, prop("real_gun"), 0.66, 0.97, 0.11, shadow=False, rotate=-25)
    return grain(vignette(grade(c, 0.6, 0.35, (200, 70, 60), 0.35), 0.75, (40, 0, 0)))


def tokhang_flashback_ben() -> Image.Image:
    c = background("church_nave", crop=(0.2, 0.08, 0.6, 0.6), blur=2)
    place(c, person("ben", True), 0.36, 0.98, 0.5)
    place(c, person("batista", False), 0.66, 1.06, 0.92)
    return grain(sepia(c), 9)


def tokhang_kulas_runs() -> Image.Image:
    c = background("public_market", blur=6)
    place(c, motion(person("kulas", False), 30), 0.45, 1.02, 0.86, rotate=-6)
    place(c, silhouette(person("batista", False), keep=0.2), 0.9, 0.98, 0.72)
    return vignette(grade(c, 0.85, 0.8, (255, 200, 170), 0.3), 0.55)


def tokhang_trade() -> Image.Image:
    c = background("church_nave", crop=(0.15, 0.05, 0.7, 0.75))
    place(c, person("eli", True), 0.33, 1.05, 0.95)
    place(c, person("batista", False), 0.7, 1.05, 0.95)
    return vignette(night(c), 0.7)


def tokhang_safe_market() -> Image.Image:
    c = background("public_market")
    place(c, person("peter", True), 0.18, 1.03, 0.82)
    place(c, person("gloria", False), 0.86, 1.0, 0.7)
    place(c, person("batista", False), 0.55, 1.04, 0.9)
    place(c, prop("water_gun"), 0.47, 0.42, 0.22, shadow=False, rotate=12)
    return vignette(grade(c, 1.05, 1.05), 0.35)


def tokhang_safe_home() -> Image.Image:
    c = background("apartment_room")
    place(c, person("ben", True), 0.24, 0.98, 0.52)
    place(c, prop("water_gun"), 0.33, 0.62, 0.15, shadow=False, rotate=-8)
    place(c, person("peter", False), 0.55, 1.03, 0.86)
    place(c, person("gwen", False), 0.8, 1.02, 0.8)
    return vignette(morning(c), 0.35)


def kumpisal_eli_hears() -> Image.Image:
    c = background("confessional", crop=(0.0, 0.0, 0.7, 0.7))
    place(c, tinted(person("eli", True), (90, 60, 40), 0.55), 0.38, 1.12, 1.02, shadow=False)
    return grille(vignette(grade(c, 0.45, 0.6), 0.75), color=(20, 12, 8, 150))


def kumpisal_gunshot() -> Image.Image:
    c = background("church_nave", crop=(0.3, 0.2, 0.4, 0.5))
    return grain(flash(grade(c, 0.7, 0.6), (0.5, 0.45)))


def kumpisal_eli_kulas_walk() -> Image.Image:
    c = background("church_nave", crop=(0.2, 0.08, 0.6, 0.6))
    place(c, silhouette(person("batista", True), keep=0.25), 0.2, 0.86, 0.7)
    place(c, silhouette(person("batista_sad", False), keep=0.2), 0.8, 0.86, 0.7)
    place(c, person("eli", False), 0.44, 1.04, 0.86)
    place(c, person("kulas", False), 0.6, 1.04, 0.84)
    return vignette(grade(c, 0.8, 0.85, (255, 210, 170), 0.3), 0.55)


def kumpisal_eli_penitent() -> Image.Image:
    c = background("confessional")
    place(c, person("eli", True), 0.62, 1.62, 1.2, shadow=False)
    c = grade(c, 0.7, 0.75, (255, 200, 150), 0.35)
    return vignette(glow(c, (0.62, 0.3), (255, 190, 120), 0.25, 0.4), 0.7)


def kumpisal_eli_forgiveness() -> Image.Image:
    c = background("church_nave", crop=(0.2, 0.08, 0.6, 0.6))
    place(c, person("eli", True), 0.5, 0.9, 0.6)
    c = grade(c, 0.6, 0.7, (255, 170, 120), 0.45)
    return vignette(glow(c, (0.5, 0.3), (255, 200, 140), 0.3, 0.5), 0.7)


def kumpisal_eli_sacrifice() -> Image.Image:
    c = background("church_nave", crop=(0.2, 0.08, 0.6, 0.6), blur=2)
    place(c, person("kulas", True), 0.28, 1.02, 0.84)
    place(c, silhouette(person("batista", False), keep=0.3), 0.86, 1.04, 0.86)
    place(c, tinted(lying(person("eli")), (200, 110, 100), 0.5), 0.55, 1.0, 0.22, shadow=False)
    return grain(vignette(grade(c, 0.6, 0.4, (200, 80, 70), 0.35), 0.75, (40, 0, 0)))


def padala_gloria_mercy() -> Image.Image:
    c = background("public_market", blur=3)
    place(c, person("gloria", True), 0.34, 1.04, 0.88)
    place(c, person("mercy", False), 0.66, 1.04, 0.84)
    return vignette(grade(c, 1.0, 0.95, (255, 225, 190), 0.25), 0.4)


def padala_beaten() -> Image.Image:
    c = background("apartment_room", blur=4)
    place(c, tinted(person("mercy", True), (160, 110, 110), 0.45), 0.35, 1.25, 0.95, shadow=False)
    place(c, silhouette(person("eli", False)), 0.62, 1.05, 1.0)
    return grain(vignette(grade(c, 0.45, 0.45, (200, 90, 80), 0.4), 0.8, (30, 0, 0)))


def padala_dressing() -> Image.Image:
    c = background("apartment_room_bath")
    place(c, silhouette(person("eli", False), (20, 24, 28), keep=0.05), 0.86, 0.9, 0.62)
    return vignette(grade(c, 0.6, 0.6, (170, 180, 210), 0.35), 0.65)


def padala_eyes_widen() -> Image.Image:
    face = Image.open(PORTRAITS / "mercy_1.png").convert("RGBA")
    face = face.crop((0, 0, face.width, int(face.width * 0.9)))
    c = grade(background("apartment_room", blur=14), 0.3, 0.4)
    place(c, face, 0.5, 1.0, 1.0, shadow=False)
    return grain(vignette(grade(c, 0.85, 0.7, (170, 190, 230), 0.35), 0.75))


def padala_phone_call() -> Image.Image:
    c = background("apartment_room", crop=(0.5, 0.3, 0.5, 0.5))
    place(c, person("mercy", True), 0.3, 1.45, 1.25, shadow=False)
    place(c, prop("telephone"), 0.78, 0.9, 0.32, shadow=False)
    return vignette(night(c), 0.6)


def padala_police_car() -> Image.Image:
    """The police arrive at night: the car at the kerb under its flashing lights, and in the lit
    doorway, Batista meeting the man who lives there (drawn in 3D, see street_scene.py)."""
    people = [(person("batista", True), 3.75, 8.3, 1.74), (person("eli", False), 4.6, 7.4, 1.8)]
    return street_scene.draw(SIZE, people=people)


def padala_police_car_leaves() -> Image.Image:
    """The police car drives away down the street, lights off; the man watches from his doorway."""
    people = [(person("eli", False), 4.6, 7.4, 1.8)]
    return street_scene.draw(SIZE, car_at=(-0.8, 0.0, 30.0), car_yaw=4.0, leaving=True, people=people, bar_on=False)


def padala_eli_attacks() -> Image.Image:
    c = background("apartment_room", blur=3)
    place(c, tinted(person("mercy", False), (150, 110, 110), 0.4), 0.78, 1.02, 0.66)
    place(c, person("eli", True), 0.4, 1.12, 1.08)
    return grain(vignette(grade(c, 0.5, 0.5, (200, 70, 60), 0.45), 0.8, (40, 0, 0)))


def padala_reveal_eli() -> Image.Image:
    c = background("apartment_room_bath")
    place(c, person("eli", False), 0.84, 0.92, 0.66)
    return vignette(grade(c, 0.75, 0.75, (200, 205, 230), 0.3), 0.6)


def padala_escape() -> Image.Image:
    c = background("apartment_room")
    place(c, motion(person("mercy", False), 14), 0.17, 1.0, 0.8)
    place(c, prop("keys"), 0.28, 0.6, 0.06, shadow=False)
    return vignette(glow(c, (0.1, 0.5), (255, 240, 210), 0.35, 0.4), 0.45)


def padala_still_manila() -> Image.Image:
    c = background("public_market", blur=5)
    place(c, person("mercy", True), 0.5, 1.02, 0.7)
    return vignette(night(c), 0.65)


def padala_run() -> Image.Image:
    c = background("public_market", blur=7)
    place(c, motion(person("mercy", False), 26), 0.42, 1.02, 0.82, rotate=-5)
    place(c, person("kulas", True), 0.72, 1.02, 0.84)
    return vignette(night(c), 0.65)


def padala_run_shot() -> Image.Image:
    c = background("public_market", blur=5)
    place(c, silhouette(person("batista", False), keep=0.2), 0.86, 1.0, 0.8)
    place(c, tinted(lying(person("mercy")), (200, 120, 120), 0.5), 0.42, 0.98, 0.22, shadow=False)
    return grain(vignette(night(c), 0.8, (30, 0, 0)))


def padala_police_laugh() -> Image.Image:
    c = night(background("public_market", blur=12))
    c = glow(c, (0.3, 0.1), (230, 235, 255), 0.3, 0.45)
    place(c, tinted(person("batista", True), (150, 160, 200), 0.35), 0.28, 1.06, 0.9)
    place(c, tinted(person("mercy", False), (150, 160, 200), 0.4), 0.74, 1.04, 0.8)
    return vignette(c, 0.6)


def padala_peter_arrives() -> Image.Image:
    c = background("apartment_room")
    place(c, person("peter", True), 0.16, 1.0, 0.76)
    return vignette(grade(c, 0.7, 0.8, (220, 210, 230), 0.25), 0.55)


def padala_peter_fights() -> Image.Image:
    c = background("apartment_room", blur=4)
    place(c, motion(person("peter", True), 16), 0.4, 1.06, 0.92, rotate=4)
    place(c, motion(person("eli", False), 16), 0.62, 1.06, 0.94, rotate=-4)
    return grain(vignette(grade(c, 0.55, 0.6, (210, 90, 80), 0.4), 0.75, (40, 0, 0)))


def padala_peter_stabbed() -> Image.Image:
    c = background("apartment_room", blur=4)
    place(c, silhouette(person("eli", False), keep=0.1), 0.8, 1.02, 0.86)
    place(c, tinted(lying(person("peter")), (200, 110, 100), 0.5), 0.42, 0.99, 0.26, shadow=False)
    return grain(vignette(grade(c, 0.45, 0.4, (200, 70, 60), 0.45), 0.8, (40, 0, 0)))


def padala_tanod() -> Image.Image:
    c = background("apartment_room")
    place(c, person("peter", True), 0.13, 1.0, 0.74)
    place(c, silhouette(person("kulas", True), (30, 32, 40), keep=0.12), 0.26, 1.0, 0.76)
    place(c, silhouette(person("batista_sad", True), (30, 32, 40), keep=0.12), 0.38, 1.0, 0.76)
    place(c, person("eli", False), 0.72, 0.98, 0.7)
    return vignette(grade(c, 0.8, 0.85), 0.5)


def padala_hide_dawn() -> Image.Image:
    c = background("public_market", blur=4)
    place(c, person("mercy", True), 0.5, 1.02, 0.78)
    return vignette(dawn(c), 0.45)


def padala_eli_unlocks() -> Image.Image:
    c = background("apartment_room")
    place(c, person("eli", True), 0.22, 1.3, 0.95, shadow=False)
    place(c, prop("keys"), 0.33, 0.66, 0.07, shadow=False)
    place(c, tinted(person("mercy", False), (190, 180, 190), 0.3), 0.72, 1.02, 0.76)
    return vignette(grade(c, 0.75, 0.75, (230, 220, 210), 0.25), 0.55)


def clerical_shirt(width: int) -> Image.Image:
    """A priest's black short-sleeved shirt on a wire hanger, drawn in code: soft folds, a darker
    side away from the light, and the white collar tab at the throat."""
    k = 4
    w, h = width * k, int(width * 1.25) * k
    shirt = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(shirt)
    cx = w / 2
    # The hanger: a hook and a thin bar the shoulders rest on.
    d.arc((cx - w * 0.06, 0, cx + w * 0.06, h * 0.1), 180, 20, fill=(150, 150, 156, 255), width=3 * k)
    d.line((cx, h * 0.09, cx - w * 0.36, h * 0.2), fill=(150, 150, 156, 255), width=3 * k)
    d.line((cx, h * 0.09, cx + w * 0.36, h * 0.2), fill=(150, 150, 156, 255), width=3 * k)
    # The shirt: shoulders, short sleeves hanging down, and the body narrowing a little.
    body = [(cx - w * 0.2, h * 0.12), (cx - w * 0.38, h * 0.19), (cx - w * 0.47, h * 0.4), (cx - w * 0.36, h * 0.43),
            (cx - w * 0.33, h * 0.33), (cx - w * 0.34, h * 0.98), (cx + w * 0.34, h * 0.98), (cx + w * 0.33, h * 0.33),
            (cx + w * 0.36, h * 0.43), (cx + w * 0.47, h * 0.4), (cx + w * 0.38, h * 0.19), (cx + w * 0.2, h * 0.12)]
    d.polygon(body, fill=(30, 30, 36, 255))
    # Light from the room on the left side, the right side falling into shadow.
    shade = Image.new("L", (w, h), 0)
    sd = ImageDraw.Draw(shade)
    for i in range(40):
        x = cx - w * 0.36 + i * w * 0.018
        sd.line((x, 0, x, h), fill=int(150 * max(0.0, 1 - i / 22)), width=int(w * 0.02) + 1)
    light = Image.new("RGBA", (w, h), (120, 118, 130, 255))
    mask = Image.composite(shade, Image.new("L", (w, h), 0), shirt.getchannel("A"))
    shirt.paste(light, (0, 0), mask.filter(ImageFilter.GaussianBlur(6 * k)))
    # Soft folds down the body.
    for fx, top in ((-0.16, 0.45), (0.06, 0.5), (0.2, 0.42)):
        d.line((cx + w * fx, h * top, cx + w * (fx + 0.02), h * 0.96), fill=(18, 18, 22, 255), width=2 * k)
    # The button placket, and the collar band with its white tab.
    d.line((cx, h * 0.2, cx, h * 0.97), fill=(18, 18, 22, 255), width=2 * k)
    d.polygon([(cx - w * 0.2, h * 0.12), (cx, h * 0.2), (cx + w * 0.2, h * 0.12), (cx + w * 0.14, h * 0.1), (cx, h * 0.15), (cx - w * 0.14, h * 0.1)], fill=(20, 20, 26, 255))
    d.rectangle((cx - w * 0.045, h * 0.135, cx + w * 0.045, h * 0.185), fill=(244, 244, 238, 255))
    shirt = shirt.filter(ImageFilter.GaussianBlur(k * 0.6))
    return shirt.resize((width, h // k), Image.LANCZOS)


def padala_collar() -> Image.Image:
    """Mercy's last look back: on the bathroom door hangs a priest's shirt."""
    c = background("apartment_room_bath", crop=(0.58, 0.08, 0.42, 0.42))
    c = grade(c, 0.8, 0.85, (230, 225, 235), 0.2)
    shirt = clerical_shirt(300)
    x, top, tall = 0.64, 0.16, 0.56
    # A nail in the wall beside the bathroom door, and the shirt's soft shadow on the wall.
    nail = ImageDraw.Draw(c)
    nx, ny = x * W, top * H
    nail.ellipse((nx - 7, ny - 7, nx + 7, ny + 7), fill=(60, 52, 46, 255))
    shadow = silhouette(scaled(shirt, tall), (10, 20, 16)).filter(ImageFilter.GaussianBlur(14))
    shadow.putalpha(shadow.getchannel("A").point(lambda a: int(a * 0.45)))
    c.alpha_composite(shadow, (int(nx - shadow.width / 2 + 26), int(ny + 18)))
    place(c, shirt, x, top + tall, tall, shadow=False)
    c = glow(c, (0.62, 0.25), (255, 250, 240), 0.15, 0.3)
    return vignette(c, 0.6)


def true_morning_family() -> Image.Image:
    c = background("public_market", blur=3)
    place(c, person("peter", True), 0.36, 1.03, 0.84)
    place(c, person("gwen", False), 0.6, 1.03, 0.8)
    place(c, person("ben", True), 0.8, 1.0, 0.5)
    return vignette(morning(c), 0.35)


def true_morning_kulas() -> Image.Image:
    c = background("church_nave", crop=(0.3, 0.25, 0.4, 0.45), blur=3)
    place(c, person("kulas", True), 0.5, 1.06, 0.92)
    return vignette(morning(c), 0.4)


def true_morning_mercy() -> Image.Image:
    sky = background("main_screen", crop=(0.0, 0.28, 0.5, 0.5), blur=2)
    wall = Image.new("RGBA", SIZE, (54, 50, 58, 255))
    c = frame_around(morning(sky), (0.06, 0.1, 0.94, 0.72), wall, border=(70, 68, 76), width=18, radius=30)
    place(c, bust("mercy_praying", flip=True), 0.36, 1.0, 0.6, shadow=False)
    return vignette(c, 0.45)


SHOTS = {
    "tokhang_rider.png": tokhang_rider,
    "tokhang_tv_news.png": lambda: object_scenes.tokhang_tv_news(SIZE),
    "tokhang_peter_holding.png": lambda: shot_market_holding("peter"),
    "tokhang_peter_shot.png": lambda: shot_market_down("peter"),
    "tokhang_gwen_holding.png": lambda: shot_market_holding("gwen"),
    "tokhang_gwen_shot.png": lambda: shot_market_down("gwen"),
    "tokhang_flashback_ben.png": tokhang_flashback_ben,
    "tokhang_kulas_runs.png": tokhang_kulas_runs,
    "tokhang_kulas_shot.png": lambda: shot_market_down("kulas"),
    "tokhang_trade.png": tokhang_trade,
    "tokhang_safe_market.png": tokhang_safe_market,
    "tokhang_safe_home.png": tokhang_safe_home,
    "kumpisal_eli_hears.png": kumpisal_eli_hears,
    "kumpisal_gunshot.png": kumpisal_gunshot,
    "kumpisal_eli_kulas_walk.png": kumpisal_eli_kulas_walk,
    "kumpisal_eli_penitent.png": kumpisal_eli_penitent,
    "kumpisal_eli_forgiveness.png": kumpisal_eli_forgiveness,
    "kumpisal_eli_sacrifice.png": kumpisal_eli_sacrifice,
    "padala_gloria_mercy.png": padala_gloria_mercy,
    "padala_luggage.png": lambda: object_scenes.padala_luggage(SIZE),
    "padala_luggage_closed.png": lambda: object_scenes.padala_luggage(SIZE, closed=True),
    "padala_beaten.png": padala_beaten,
    "padala_dressing.png": padala_dressing,
    "padala_eyes_widen.png": padala_eyes_widen,
    "padala_phone_call.png": padala_phone_call,
    "padala_police_car.png": padala_police_car,
    "padala_police_car_leaves.png": padala_police_car_leaves,
    "padala_eli_attacks.png": padala_eli_attacks,
    "padala_reveal_eli.png": padala_reveal_eli,
    "padala_escape.png": padala_escape,
    "padala_still_manila.png": padala_still_manila,
    "padala_run.png": padala_run,
    "padala_run_shot.png": padala_run_shot,
    "padala_jeep.png": lambda: object_scenes.padala_jeep(SIZE, person("mercy", True)),
    "padala_police_laugh.png": padala_police_laugh,
    "padala_peter_arrives.png": padala_peter_arrives,
    "padala_peter_fights.png": padala_peter_fights,
    "padala_peter_stabbed.png": padala_peter_stabbed,
    "padala_tanod.png": padala_tanod,
    "padala_hide_dawn.png": padala_hide_dawn,
    "padala_eli_unlocks.png": padala_eli_unlocks,
    "prologue_booth.png": lambda: object_scenes.prologue_booth(SIZE, person("eli")),
    "padala_collar.png": padala_collar,
    "true_morning_family.png": true_morning_family,
    "true_morning_kulas.png": true_morning_kulas,
    "true_morning_mercy.png": true_morning_mercy,
    "true_morning_batista.png": lambda: object_scenes.true_morning_batista(SIZE),
    "true_visiting.png": lambda: object_scenes.true_visiting(SIZE, object_scenes.in_jail_orange(person("eli"), 112, (150, 115, 195, 150))),
}


def main() -> None:
    placeholders = set(LIST_FILE.read_text().split()) if LIST_FILE.exists() else set()
    wanted = [n if n.endswith(".png") else n + ".png" for n in sys.argv[1:]] or list(SHOTS)
    made = []
    for name in wanted:
        # A real painting saved under this name is never drawn over.
        if (CUTSCENES / name).exists() and name not in placeholders:
            continue
        picture = SHOTS[name]().convert("RGB").resize(SAVE_SIZE, Image.LANCZOS)
        picture = picture.quantize(SAVE_COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
        picture.save(CUTSCENES / name, optimize=True)
        made.append(name)
    LIST_FILE.write_text("\n".join(sorted(placeholders | set(made))) + "\n")
    print("Drew %d stand-ins: %s" % (len(made), ", ".join(made) or "none"))


if __name__ == "__main__":
    main()
