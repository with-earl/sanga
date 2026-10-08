# SANGA

**Every session: read [HANDOFF.md](HANDOFF.md) first. It holds the conversation so far, where work
stopped, open questions and the next tasks. Before ending a session, update HANDOFF.md.**

SANGA is a 2D psychological, decision-based horror game wrapped in a cozy look. Every decision makes
a new branch. It is one story, told in a fixed story time through three stories (Tokhang, Kumpisal,
Padala), playable from three starting points. Text is in English and Filipino.

## Engine and platforms

- **Godot 4.7.2 stable**, GDScript only. The renderer is GL Compatibility everywhere.
- Viewport 1280x720, stretch mode `canvas_items`, landscape.
- The targets are Android (the main platform) and Web, for playtesting on iPhone.
  - [export_presets.cfg](export_presets.cfg) holds only the **Web** preset: threads off, so it
    runs on GitHub Pages without special headers. Its `html/head_include` script turns the game
    sideways on a phone or tablet held upright (canvas rotated 90°, `canvas_resize_policy=0` so
    the page sets the canvas size, touch and mouse positions turned before the game reads them).
  - It also holds the **Android** preset: package `com.withearl.sanga`, arm64 and armv7,
    immersive, the vibrate permission (for `Settings.vibrate`), no Gradle build. Building it needs
    the Android export templates, the Android SDK in Editor Settings, and a release keystore
    (left empty in the preset, never commit one). Raise `version/code` for every Play upload.
    Keep the Web preset as it is. Phones turn the game to either landscape side
    (`display/window/handheld/orientation=4`, sensor landscape).
  - Every push to `main` builds the Web export and deploys it to GitHub Pages
    ([.github/workflows/web.yml](.github/workflows/web.yml)).
- Platform-specific behaviour is guarded with `OS.has_feature()`: vibration only on
  `android`/`ios` (not `web`), Quit is hidden on `web`, and the web build has "Tap to start" in
  [scripts/boot.gd](scripts/boot.gd) to unlock audio on iOS.

## Commands

The Godot binary is `godot` in the cloud (install with `bash tools/cloud_setup.sh`). On the original
Windows machine it is
`C:/Users/Jnorlynne/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`.

```bash
godot --headless --path . --import                                   # import assets (after adding files)
godot --headless --path . -s res://tests/smoke_test.gd               # smoke test: must print SMOKE TEST PASSED
godot --headless --path . -s res://tests/playthrough.gd              # full playthrough, every ending: must print PLAYTHROUGH PASSED
godot --headless --path . --export-release "Web" build/web/index.html  # web build
python tools/compose_music.py [name]                                 # regenerate music (numpy, scipy)
python tools/compose_sounds.py                                       # regenerate sound effects
python tools/draw_props.py                                           # redraw props, telephone, HUD icons (gear, terminal, book, clipboard) (needs Pillow, numpy)
python tools/draw_placeholders.py                                    # stand-in cutscenes (composed from the game art) for art not painted yet
tools/next_version.sh                                                # next version from the commits
```

To check a change visually, run a temporary SceneTree script in a window (not `--headless`) that
saves `root.get_texture().get_image().save_png(...)` to a scratch folder, then look at the
picture. Delete the temporary script afterwards. The `--headless` runs print RID and ObjectDB
"leaked at exit" warnings; they are harmless.

## Layout

| Path | What |
|---|---|
| `autoload/` | Global singletons (order in `project.godot`): GameState (saves, flags, undo history), Settings (volumes, vibration, `settings.cfg`), SceneRouter, StoryDirector (story order and starting points, endings), SaveNote, RetroText, MenuVideo (main-screen video, audio muted), SceneVignette, AssetPreloader, StoryCard (title and ending cards, scene fades), Cutscene, MusicDirector (music per scene, crossfades), Sfx (button click, objective strike) |
| `scenes/` | `boot`, `main_menu`, the four locations (`public_market`, `church_nave`, `confessional`, `apartment_room`), `run_recap` ("Ang Nangyari": the run just finished, written in the book, with no hint of other branches; then "Ayusin ayon sa oras", the same run in true time order with red threads from cause to effect, `scripts/time_threads.gd` and `story/threads.json`). The start screen is a script, `scripts/start_screen.gd`, not a scene. `components/` holds `dialogue_box`, `game_menu`, `objectives_panel`. In a place the HUD is: gear, terminal, place name at the top left; the old open book (memories) and the blue clipboard (objectives) at the top right, opening `scripts/journal_modal.gd`. The objectives list itself stays off screen |
| `scripts/` | `location.gd` is the base of every playable place (objectives route, conversations, hints). `alaala.gd` is the memory system: lines, cutscene steps and choice options with `needs` / `needs_not` / `if_flag` / `unless_flag` show only when allowed, Alaala choices get a ✦, and a `choices` entry can sit inside any lines. Echoes (bible R9): a line with `"echo": true` and an `if_flag` set by an earlier ordinary choice; it is logged to the recap, never changes an ending. Each story has its own subclass: `tokhang.gd`, `church_nave.gd`/`confessional.gd` (with `kumpisal_story.gd`), `padala.gd`. `stage_life.gd` is the 2.5D staging every place gets: a slow drifting camera with depth, breathing people (and portraits), and living light (`shaders/stage_light.gdshader`: flickering candles, dust, steam, cloud shadows; positions per place in `StageLife.LIGHTS`). `start_screen.gd` (class `StartScreen`) is the screen a save opens on: the Continue card, then the three starting-point story cards |
| `story/*.json` | All story text, conversations and choices. `alaala.json` lists the Alaala (memories) and the endings that give them; `prologue.json` is the confession that opens every run |
| `docs/STORY_BIBLE.md` | The design (the Alaala mechanic, rules R1-R10), the hidden truth, and every line of the script. It wins over the story files when they disagree |
| `assets/` | Art (see `assets/README.md`), `music/`, `sounds/`, `fonts/Lora.ttf` (and DejaVu Sans Mono for the developer tools), `videos/main_screen.ogv` |
| `tools/` | `next_version.sh`, `compose_music.py`, `compose_sounds.py`, `draw_props.py`, `draw_placeholders.py` (with `scene3d.py`, a tiny 3D drawing kit lit pixel by pixel, `street_scene.py`, the night street with the police car, and `object_scenes.py`: the TV news, the jeepney, Batista's badge, the visiting booth, the prologue confessional, the suitcase), `cloud_setup.sh`. Has a `.gdignore`, so Godot skips it |
| `tests/smoke_test.gd` | Headless smoke test |
| `tests/playthrough.gd` | Plays a fresh save through 6 runs that reach every ending, the true ending second (about a minute). Set `PLAYTHROUGH_TRANSCRIPT=<file>` to write out every line and choice. Run it after any story or scene change |

## Conventions

- **Code style:** tabs, LF line endings, typed GDScript (`var x := ...`, `-> void`). Every
  script, constant and non-obvious function has a `##` doc comment in plain, friendly English
  that explains *why*, written for a reader who is not a programmer. Match the comment density
  of the surrounding code. Constants go at the top, in UPPER_CASE.
- **UI text style:** gameplay text (HUD, dialogue, in-game menu) is golden ochre `#D9A441` with
  a brown outline `#4A2A12`. The main menu's own buttons stay cream with a blue outline.
- **Audio:** music and sounds are original and synthesised by the Python tools. Never add
  copyrighted music or arrangements of existing songs. Music plays on the `Music` bus at
  `MusicDirector.VOLUME_DB` (-24 dB) and must stay subtle. Effects play on the `Sound` bus at
  `Sfx.VOLUME_DB` (-10 dB).
- **Debug-only features** are gated by `OS.is_debug_build()`, for example "Skip story (debug)".
  The "Developer tools" window (`scripts/dev_tools.gd`, points in `scripts/dev_jump.gd`, plus
  the endings) opens from the terminal icon beside the gear, on the main screen and in every
  place. It shows in every build during development (`DevTools.SHOW_IN_ALL_BUILDS`); set it to
  false before release. It follows Apple's design language in black, white and greys: a rounded
  sheet with "Developer Tools" and "Done", grouped rounded lists with dividers and chevrons, grey
  section titles and footnote, in DejaVu Sans Mono (crisp: the `crisp_text` group skips the retro
  blur). Never style it like the game's own windows.
- **Versioning:** follow [VERSIONING.md](VERSIONING.md).
  1. Make **every change** a Conventional Commit (`feat`, `fix`, `style`, `docs`, `chore`, …,
     with `!` or a `BREAKING CHANGE:` footer when something breaks).
  2. Run `tools/next_version.sh`, then make an annotated tag `vX.Y.Z` with a one-line summary.
     Before 1.0, a breaking change bumps MINOR and the tag message says `BREAKING:`.
  3. Push with `git push origin main --follow-tags`.
  4. End commit messages with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  5. The git email for this repo is `301193008+earl-gh@users.noreply.github.com`. The account
     blocks pushes that would expose its private email.
- Never rewrite pushed history, and don't force-push.
