"""Draws placeholder cutscene pictures for scenes whose final art is not painted yet.

Each placeholder is the place's background, blurred and darkened, with "Placeholder", a short
description of the shot to paint, and the file name, so the story can be played end to end
and the artist knows exactly what to make. Replace a placeholder by saving the real picture
under the same name. Pictures that already exist and are not placeholders are never touched.

Run: python tools/draw_placeholders.py   (needs Pillow)
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CUTSCENES = ROOT / "assets" / "cutscenes"
BACKGROUNDS = ROOT / "assets" / "backgrounds"
SIZE = (1672, 941)
FONT = "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf"
CREAM = (246, 238, 222)
GREY = (190, 182, 170)
## A small file next to the pictures listing which ones are still placeholders.
LIST_FILE = CUTSCENES / "PLACEHOLDERS.txt"

## file name, background it stands on, the shot to paint (see docs/STORY_BIBLE.md, section 11).
SHOTS = [
    ("prologue_booth.png", "confessional.png", "The confessional's small door, in near darkness"),
    ("tokhang_safe_market.png", "public_market.png", "Batista at Gloria's stall, holding up the water gun"),
    ("tokhang_safe_home.png", "public_market.png", "Ben squirting Peter with the water gun at the door, Gwen laughing"),
    ("kumpisal_eli_kulas_walk.png", "church_nave.png", "Father Eli walking Kulas out past Batista's men at the gate"),
    ("kumpisal_eli_penitent.png", "confessional.png", "Father Eli kneeling on the penitent's side of his own booth"),
    ("padala_tanod.png", "apartment_room.png", "Peter at the door with two barangay tanods, Father Eli in the hallway"),
    ("padala_hide_dawn.png", "public_market.png", "Mercy at a jeepney terminal at dawn, phone to her ear"),
    ("padala_eli_unlocks.png", "apartment_room.png", "The door open, Father Eli kneeling in the doorway with the keys"),
    ("true_morning_family.png", "public_market.png", "Peter, Gwen and Ben at a carinderia, morning light"),
    ("true_morning_kulas.png", "church_nave.png", "Kulas outside a rehab center, holding a rosary"),
    ("true_morning_mercy.png", "public_market.png", "Mercy on a bus home, looking out the window"),
    ("true_morning_batista.png", "church_nave.png", "Batista's badge on a desk, his hands open beside it"),
    ("true_visiting.png", "confessional.png", "A prison visiting booth: Father Eli behind glass and a small grille, facing the camera"),
]


def wrap(draw: ImageDraw.ImageDraw, text: str, font, width: int) -> list[str]:
    words, lines, line = text.split(), [], ""
    for word in words:
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=font) <= width:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def centered(draw: ImageDraw.ImageDraw, y: int, text: str, font, fill) -> int:
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    draw.text(((SIZE[0] - (right - left)) // 2, y), text, font=font, fill=fill)
    return bottom - top


def draw(name: str, background: str, shot: str) -> None:
    base = Image.open(BACKGROUNDS / background).convert("RGB").resize(SIZE)
    base = base.filter(ImageFilter.GaussianBlur(18))
    base = ImageEnhance.Brightness(base).enhance(0.38)
    d = ImageDraw.Draw(base)
    small, big = ImageFont.truetype(FONT, 34), ImageFont.truetype(FONT, 60)
    lines = wrap(d, shot, big, 1300)
    y = SIZE[1] // 2 - (len(lines) * 74) // 2 - 40
    centered(d, y, "Placeholder", small, GREY)
    y += 70
    for line in lines:
        centered(d, y, line, big, CREAM)
        y += 74
    centered(d, y + 12, "assets/cutscenes/" + name, small, GREY)
    base.save(CUTSCENES / name)


def main() -> None:
    placeholders = set(LIST_FILE.read_text().split()) if LIST_FILE.exists() else set()
    made = []
    for name, background, shot in SHOTS:
        # A real painting saved under this name is never drawn over.
        if (CUTSCENES / name).exists() and name not in placeholders:
            continue
        draw(name, background, shot)
        made.append(name)
    LIST_FILE.write_text("\n".join(sorted(placeholders | set(made))) + "\n")
    print("Drew %d placeholders: %s" % (len(made), ", ".join(made) or "none"))


if __name__ == "__main__":
    main()
