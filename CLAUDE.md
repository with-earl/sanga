# SANGA

**Every session: read [HANDOFF.md](HANDOFF.md) first. It holds the conversation so far, where work
stopped, open questions and the next tasks. Before ending a session, update HANDOFF.md.**

SANGA is a 2D psychological, decision-based horror game wrapped in a cozy look. Every decision makes
a new branch. It has three stories (Tokhang, Kumpisal, Padala), played in different orders on
different timelines. Text is in English and Filipino.

## Engine and platforms

- **Godot 4.7.2 stable**, GDScript only. The renderer is GL Compatibility everywhere.
- Viewport 1280x720, stretch mode `canvas_items`, landscape.
- The targets are Android (the main platform) and Web, for playtesting on iPhone.
  - [export_presets.cfg](export_presets.cfg) holds only the **Web** preset: threads off, so it
    runs on GitHub Pages without special headers. There is no Android preset in the repo yet. If
    one is added, keep the Web preset as it is.
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
godot --headless --path . --export-release "Web" build/web/index.html  # web build
python tools/compose_music.py [name]                                 # regenerate music (numpy, scipy)
python tools/compose_sounds.py                                       # regenerate sound effects
python tools/draw_props.py                                           # redraw props, telephone, terminal icon (needs Pillow, numpy)
tools/next_version.sh                                                # next version from the commits
```

To check a change visually, run a temporary SceneTree script in a window (not `--headless`) that
saves `root.get_texture().get_image().save_png(...)` to a scratch folder, then look at the
picture. Delete the temporary script afterwards. The `--headless` runs print RID and ObjectDB
"leaked at exit" warnings; they are harmless.

## Layout

| Path | What |
|---|---|
| `autoload/` | Global singletons (order in `project.godot`): GameState (saves, flags, undo history), Settings (volumes, vibration, `settings.cfg`), SceneRouter, StoryDirector (story and timeline order, endings), SaveNote, RetroText, MenuVideo (main-screen video, audio muted), SceneVignette, AssetPreloader, StoryCard (title, ending and time-order cards), Cutscene, MusicDirector (music per scene, crossfades), Sfx (button click, objective strike) |
| `scenes/` | `boot`, `main_menu`, the four locations (`public_market`, `church_nave`, `confessional`, `apartment_room`), `timeline_reveal`. `components/` holds `dialogue_box`, `game_menu`, `objectives_panel` |
| `scripts/` | `location.gd` is the base of every playable place (objectives route, conversations, hints). Each story has its own subclass: `tokhang.gd`, `church_nave.gd`/`confessional.gd` (with `kumpisal_story.gd`), `padala.gd` |
| `story/*.json` | All story text, conversations and choices. `timelines.json` is the timelines chart: cards, sections and realities |
| `assets/` | Art (see `assets/README.md`), `music/`, `sounds/`, `fonts/Lora.ttf` (and DejaVu Sans Mono for the developer tools), `videos/main_screen.ogv` |
| `tools/` | `next_version.sh`, `compose_music.py`, `compose_sounds.py`, `draw_props.py`, `cloud_setup.sh`. Has a `.gdignore`, so Godot skips it |
| `tests/smoke_test.gd` | Headless smoke test |

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
  false before release. It looks like a plain black and white terminal (DejaVu Sans Mono,
  crisp: the `crisp_text` group skips the retro blur), never like the game's own windows.
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
