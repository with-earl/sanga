# SANGA art drop-in guide

Every image slot in the game shows a labeled placeholder box until a PNG with the right name exists.
Drop the file into the folder below and the placeholder is replaced. No code or scene changes are needed.

Names are lowercase with underscores. Transparent PNGs work best for characters and props.
Backgrounds are stretched to the full 1280 x 720 screen. Characters and props are scaled to fit their
slot (keeping their proportions) and sit on the bottom edge of it.

## assets/backgrounds/

| File | Used in |
| --- | --- |
| `main_screen.png` | Boot screen, main screen (fallback under the video) |
| `church_nave.png` | Church nave |
| `confessional.png` | Confessional interior |
| `apartment_room.png` | Apartment room |
| `apartment_room_bath.png` | Apartment room while the man is in the bath (Padala) |
| `public_market.png` | Public market |

## assets/characters/

| File | Appears in |
| --- | --- |
| `gloria_praying.png` | Church nave |
| `mercy_praying.png` | Church nave |
| `batista_praying.png` | Church nave |
| `ben_praying.png` | Church nave |
| `gwen_praying.png` | Church nave |
| `kulas_praying.png` | Church nave |
| `gloria_market.png` | Public market (Tokhang) |
| `gloria.png`, `gwen.png`, `batista.png`, `kulas.png` | Confessional and public market (not added yet) |

## assets/props/

| File | Used in |
| --- | --- |
| `keys.png` | Apartment room: the five keys, seen from a low side angle (drawn by `tools/draw_props.py`) |
| `door.png` | Apartment room |
| `police_poster.png` | Apartment room: the police emergency poster on the left wall, in that wall's perspective (drawn by `tools/draw_props.py`) |
| `food_delivery_card.png` | The food delivery card's own picture (drawn for the game) |
| `food_delivery_card_floor.png` | Apartment room, Padala timeline only: the flyer lying slightly crumpled on the floor beside the bed (made from the card picture by `tools/draw_props.py`) |
| `telephone.png` | Apartment room |
| `confessional_booth.png` | Church nave (cutout above the background) |
| `nave_vase.png` | Church nave (cutout above the booth) |
| `pink_toy_gun.png` | Public market |
| `water_gun.png` | Public market |
| `realistic_toy_gun.png` | Public market |
| `motor.png` | Public market (decoration only, not tappable) |

## assets/portraits/

The characters shown beside the dialogue box. The character you tap appears on the right, and in the
church nave Father Eli always stands on the left. Name them `<character>_1.png` for the main picture,
and `_2`, `_3` and so on for other expressions. `_2` is the sad expression, shown while a character confesses. Standing full-length pictures work best.

| File | Used for |
| --- | --- |
| `father_eli_1.png` | Father Eli, on the left in the church nave |
| `gloria_1.png`, `gloria_2.png` | Gloria |
| `mercy_1.png` | Mercy |
| `batista_1.png`, `batista_2.png` | Batista |
| `gwen_1.png`, `gwen_2.png` | Gwen |
| `ben_1.png` | Ben |
| `kulas_1.png` | Kulas |
| `peter_1.png` | Peter (not used yet) |

## assets/cutscenes/

Full-screen pictures for cutscenes (16:9, 1672 x 941 or larger). Every one except `padala_bath.png` is a stand-in that `tools/draw_placeholders.py` composes from the game's own art
(listed in `PLACEHOLDERS.txt`). Replace it with the real picture under the same filename, and remove its
name from `PLACEHOLDERS.txt` so the tool never draws over it.

| File | Shows |
| --- | --- |
| `tokhang_skyway.png` | Intro frame 1: Peter on his scooter on the skyway, seen low from the side, Manila ahead (`tools/intro_frames.py`) |
| `tokhang_tv_news.png` | Intro frame 2: TV news report about Tokhang |
| `tokhang_market_arrival.png` | Intro frame 3: over Peter's left shoulder as he rolls into the market street (`tools/intro_frames.py`) |
| `tokhang_peter_holding.png`, `tokhang_peter_shot.png` | Peter with the toy gun, and the shooting |
| `tokhang_gwen_holding.png`, `tokhang_gwen_shot.png` | Gwen with the toy gun, and the shooting |
| `tokhang_kulas_runs.png`, `tokhang_kulas_shot.png` | Kulas running, and the shooting |
| `tokhang_flashback_ben.png` | Ben seeing Batista's real gun at the church |
| `padala_bath.png` | The man in the bath (real art: the steamy bedroom) |
| `padala_gloria_mercy.png`, `padala_luggage.png`, `padala_beaten.png` | Padala's opening |
| `padala_phone_call.png`, `padala_eyes_widen.png`, `padala_luggage_closed.png`, `padala_police_car.png` | Police card ending |
| `padala_dressing.png`, `padala_reveal_eli.png` | The man dresses, asks forgiveness, and is revealed as Father Eli |
| `padala_escape.png` | Mercy gets out with the right key |
| `padala_still_manila.png`, `padala_run.png`, `padala_run_shot.png`, `padala_jeep.png`, `padala_police_laugh.png` | Kumpisal timeline: Run and Ride Jeep |
| `padala_eli_attacks.png`, `padala_police_car_leaves.png` | Padala timeline, police card: Father Eli attacks Mercy, and the police car drives away |
| `padala_peter_arrives.png`, `padala_peter_fights.png`, `padala_peter_stabbed.png` | Padala timeline, food delivery card: Peter arrives, fights Father Eli, and is stabbed |
| `tokhang_trade.png` | Padala timeline: Father Eli tells Batista where Kulas is, in exchange for Mercy |
| `kumpisal_gunshot.png`, `kumpisal_eli_hears.png` | Main timeline: the gunshot outside, and Father Eli in the confessional |
| `kumpisal_eli_forgiveness.png` | Father Eli asks God for forgiveness |
| `kumpisal_eli_sacrifice.png` | Sacrifice ending: Father Eli dies |

The words of each story are in `story/` (for example `story/tokhang.json`), separate from the code.

## assets/montage/

Full-screen pictures for a story's montage, shown after its title card. Each is drawn about 25%
larger than the screen and pans across it, so a 16:9 image (such as 1672 x 941) works best.

| File | Used in |
| --- | --- |
| `kumpisal_1.png`, `kumpisal_2.png`, `kumpisal_3.png` | Kumpisal montage, in this order |


The list for each story is `MONTAGES` in `autoload/story_card.gd`. The ending frames are listed in `ending_frames` on the confessional scene.

## assets/ui/

Empty for now. The title is expected to be part of the main screen background.

## Adjusting a slot

Open the scene in the editor and select the slot node. Move or resize it like any Control node.
The placeholder box shows in the editor too, so you can line things up before the art exists.

## Touch controls

The game is touch only. Interactive characters and props light up while pressed and react when the
finger lifts inside them. The Android back button goes back one screen, or leaves the app from the
main screen.
