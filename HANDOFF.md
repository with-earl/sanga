# Handoff

This is a briefing from the previous Claude session to the next one. It was written on
2026-10-07, at the end of a long desktop session (Windows, Claude desktop app, Godot editor open
locally), when the user moved to a Claude Code cloud session on their iPhone. Read
[CLAUDE.md](CLAUDE.md) for the permanent project facts. This file is the conversation: what was
asked, what was decided and why, where we stopped, and what comes next.

**Keep this file current.** Before ending a session, update "Where we stopped", "Open questions"
and "Next tasks", and add anything new to "Decisions" and "Preferences".

## First steps in a new cloud session

1. Install the tools: `bash tools/cloud_setup.sh`. This installs Godot 4.7.2 and the web export
   templates; it is skipped if the environment setup script already did it.
2. Set the git identity. Repo-local git config does not travel with a clone:
   ```bash
   git config user.name "earl-gh"
   git config user.email "301193008+earl-gh@users.noreply.github.com"
   ```
   The GitHub account blocks pushes that would expose its private email, and a push with the wrong
   email is rejected (GH007).
3. Check that the project imports and passes the smoke test:
   ```bash
   godot --headless --path . --import
   godot --headless --path . -s res://tests/smoke_test.gd
   ```
4. Check the latest **Web build** run under the repo's Actions tab. See "Open questions" about
   Pages.

## The user

- GitHub `earl-gh` pushes to the repo `with-earl/sanga`, which is private; `earl-gh` is a
  collaborator. They write short, direct requests, often several in one message, and sometimes
  interrupt to clarify (for example "endings means timeline endings, not story endings"). Read
  every sentence of a request as a checklist item.
- They playtest by running the game (F5 in Godot) and judging by eye and ear. They now want to
  playtest on an **iPhone** through the GitHub Pages web build.

## Preferences picked up

- **Push every change** with proper semantic versioning and tags. Use the
  `VERSIONING.md` + `tools/next_version.sh` process: evaluate the label, don't guess. When one
  release has several changes, the highest label applies, once. They asked for this explicitly
  and want it followed every time.
- **Visible checking.** Before reporting, verify UI changes with real screenshots from a windowed
  Godot run. This caught real bugs, for example the black timeline screen.
- **Quiet audio.** They asked for lower music volume **twice**. Music must be slow, subtle piano,
  and quiet. When in doubt, quieter.
- **Original content only.** They asked for a piano version of "Fruitcake" by Eraserheads. We
  explained that it is copyrighted and wrote an **original** theme in that whimsical, nostalgic
  90s OPM spirit instead. They accepted. Don't arrange or quote copyrighted songs.
- **Free, in-code assets** over paid AI generation. They chose "composed in code" for music, so
  the sounds are synthesised in Python too.
- **No spoilers in player-facing text.** The content warning must stay general: no who-does-what.
- **Exact colours they chose:** gameplay text is golden ochre with a brown outline. They rejected
  white text with an ochre outline: "it must be golden ochre then brown outline".
- **Built in Godot, not images.** They wanted the timeline diagram "made on Godot" (nodes) and
  sharp. They thought it was an image, because blur shaders made it look like one.
- **Simple settings.** Sound and Music are on/off switches, not volume steps.

## Decisions, and why (in order)

Each is a tagged release on `main`. `git log --oneline` and `git tag -l` show them all.

1. **v0.1.0** baseline: the repo as it was before tagging began. The local folder was a ZIP
   download, so the existing GitHub history was attached and nothing was force-pushed.
2. **v0.2.0 Settings on the main screen.** The user asked for a gear button at the top left that
   opens the sound settings. It reuses the in-game `GameMenu` with `main_screen = true`, which
   hides Main Menu, the debug skip and the place name, and is titled "Settings". The user then
   asked for a **Settings text row** after Load Game as well, so both exist. We offered to remove
   the gear and got no answer, so it is still there.
3. **v0.3.0 Undo.** The user wanted "go back for part without back button" and picked **"Undo last
   step"** from options (rather than previous place or both). `GameState.history` holds a
   checkpoint after each finished step, and is saved in the save file.
   - Undo first discards partial progress since the last checkpoint (`changed_since_checkpoint`),
     otherwise it steps back one checkpoint, then reloads `location`.
   - History restarts (`checkpoint(true)`) at each story's start and again once its opening is
     over (Tokhang's phone call and choice, the Kumpisal opening, Padala's intro). That way undo
     never replays an opening or crosses into the previous story. As a result, Tokhang's opening
     choice cannot be undone.
   - The button is a `BackLink` labelled "Undo", made by `Location._build_undo_button()`.
4. **v0.3.1 Colours.** Golden ochre `#D9A441` text with a brown `#4A2A12` outline for all gameplay
   text, the strike line and the plain icons. The main menu's own buttons and the story title
   cards are unchanged.
5. **v0.3.2 Versioning.** `VERSIONING.md` defines the game's "public API" (save files, story
   progress and outcomes, player-facing features and settings, platform requirements), ordered
   questions for MAJOR, MINOR and PATCH, edge cases, how several changes combine, and the rule
   before 1.0. `tools/next_version.sh` applies it.
   - Getting the first push through needed a history rewrite to the noreply email. The user
     approved it.
   - Claude Code's auto-mode safety check blocked the rewrite and a push once, and the user pushed
     manually. Later pushes worked.
6. **v0.3.3 Timeline ending screen fixed and rebuilt.**
   *SUPERSEDED by one-truth rework: the timelines chart and its ending screen were deleted.*
   - **Bug:** the close-up phase of `timeline_reveal` was black. The diagram was a zero-size
     `Control`, and a Control is culled when its own rect leaves the screen. It is now a `Node2D`.
   - **Rebuilt from nodes:** Panels with `StyleBoxFlat`, Labels and `Line2D`. Text is laid out
     3.4x larger and scaled down with mipmaps. The retro blur shader is gone, and
     `SceneVignette.SHARP_SCENES` excludes this screen.
   - Shown timelines are stacked, with no gap for unfinished ones.
   - **Debug menu:** the main screen's left menu became **Stories** (Tokhang, Kumpisal, Padala)
     and **Endings** (Main, Alternate 1-5). `TimelineMap.endings()` takes one reality per final
     card of the chart, in chart order:

     | Name | Timeline | Ends on |
     |---|---|---|
     | Main | main | Key |
     | Alternate 1 | main | Police Poster (was Police Card) |
     | Alternate 2 | kumpisal | Run |
     | Alternate 3 | kumpisal | Ride Jeep |
     | Alternate 4 | padala | Trade |
     | Alternate 5 | padala | Sacrifice |

     The user has **not confirmed** this numbering.
7. **v0.4.0 Music** (first version, per-scene synth tracks). Superseded by 8.
8. **v0.5.0 Slow piano, and on/off switches.**
   - One original 16-bar waltz theme (`THEME`/`HARMONY` in `tools/compose_music.py`) arranged per
     scene: menu C major, market G major, church D minor, confessional A minor fragments,
     apartment A minor with the piano drifting out of tune.
   - Sound and Music became on/off switches (`ToggleSwitch`): on means 75%, off means 0. The
     volume steps were removed, which is marked BREAKING.
9. **v0.6.0 Where audio plays.**
   - **Music only in:** main (title/boot, main screen, story ending card, timeline ending),
     church nave (from the Kumpisal title card and intro montage), confessional, apartment room
     and public market. `StoryCard.start()` switches to the destination scene's music, and the
     ending cards call `MusicDirector.play_main()`.
   - **Removed:** the separate reveal track and the main-screen video's own audio.
   - **New sounds:** a soft button click on every BaseButton (`Sfx`), and a pencil stroke with a
     faint chime when an objective is struck through.
   - **Content warning** made general.
   - **Portraits** beside the dialogue moved 64 px in from the edges. The dialogue box keeps
     24 px; the user said not to change the box.
   - Slip: deleting `reveal.wav` landed in the `feat(audio)` commit, not the music commit. It was
     left as is, because rewriting history wasn't worth it.
10. **v0.6.1** the sound effects play 10 dB quieter (-10 dB). **v0.6.2** the music plays at -24 dB,
    measured at about -43 dBFS RMS on the main screen.
11. **This handoff release (v0.7.0)** adds iPhone playtesting:
    - The Web export preset: threads off, `renderer/rendering_method.web` set to Compatibility.
    - `OS.has_feature` guards: no vibration or Vibration switch except on android/ios, and no
      Quit on web.
    - A web-only **"Tap to start"** after loading, which unlocks iOS audio.
    - The GitHub Actions workflow that deploys the web build to Pages.
    - `tools/cloud_setup.sh`, plus `CLAUDE.md` and this file.
    - The web build was exported and played locally in a browser before pushing: Tap to start,
      then the content warning, then the main screen. No Quit, no debug menu (it is a release
      build), no console errors.
12. **Cloud session, 2026-10-07 (not yet on `main`, see "Where we stopped").** The Pages deploy
    failed once because the repo was still private. The user made it public and set the Pages
    source, and the re-run deployed. Then four commits, which together are **v0.8.0** (MINOR):
    - `style(ui)`: every button uses one cream text `#FFF3D6` with a dark brown outline `#2A1608`
      (`UiSkin.BUTTON_TEXT`/`BUTTON_OUTLINE`). The user asked for "a uniform color and outline
      color that gives best readability" with the font kept. Labels stay golden ochre.
    - The user asked for a GUI/HUD plan "for retro 90s anime softness", then said "pick best
      choices then start". Choices made: **warm plum-brown windows**, **typewriter text on**,
      **wide phones show the art uncut with a blurred fill at the sides** (never crops props).
    - `feat(ui)` phone fit: stretch aspect `expand`; every place keeps a centred 1280x720 stage
      (`Location._fit_stage`), with a dim blurred copy of the background behind it
      (`ScreenFit`, `SideFill` layer). Cutscenes, montage, menu video and still cover the screen.
      Notch insets on android/ios only. Sizes: dialogue 26, speaker 24, HUD 23, headings 26,
      buttons 24, buttons at least 64 tall, menu icon tap area 64x64. "Objective/s" is now
      "Objectives".
    - `feat(ui)` windows: `SoftWindow` (shader `soft_window.gdshader`) is the one window look for
      the dialogue box, choices, game menu and every themed button: rounded, see-through plum
      gradient, cream outer line, ochre inner line, soft shadow. Name plate on the box's top
      edge, typewriter text at 42 letters/s (a tap finishes the line), a bobbing ▼, choices fade
      in one by one with a ▶ cursor on press, ochre/cream switches.
    - `feat(ui)` HUD: soft top shade behind the HUD, place name fades in, new objectives glow.

## Where we stopped

- **Tokhang intro is three frames (branch claude/tokhang-intro-frames):** 1 `tokhang_skyway.png` (low side
  shot of Peter riding the pink scooter on the skyway, exit gantry, hazy Manila with a church spire), 2 the TV
  news, 3 `tokhang_market_arrival.png` (a chase view over Peter's left shoulder into the palengke street,
  handlebar dashboard and phone showing Gwen's text). Both new frames are drawn from nothing in 3D by
  `tools/intro_frames.py`; the scooter, wheels and Peter are lofted shapes in `tools/bike_parts.py`
  (`loft`, `ellipsoid`, `limb`; no game art). `tokhang_rider.png` and its drawing function are gone. Frame 3
  has no line and holds 3.5 s. Stand-ins, listed in `PLACEHOLDERS.txt`. Frame 1's camera is super near the front wheel
  (about 0.9 m away, low) with the legshield, headlight, rider's knee and boot, floorboard and handlebar still in view; frame 3's is close behind Peter and the street is a full palengke
  filled by `tools/market_parts.py` (vendors and shoppers, veg/fish/meat/fruit/rice/isaw stalls with price
  cards and sign boards, tarpaulin roofs, tangled wires, a parked jeepney, crates and litter). Frame 3's camera is at waist level, with fog
  (`Scene.fog`), a depth map (`Scene.track_depth`) for depth of field, coloured bounce lights under the tarps,
  glowing bulbs, tarp shadows on the floor and beams of sun. It takes about 70 seconds to render.
- **TV shop cards:** the HouseCredit promo and the BCash / Loro payment signs are now small horizontal
  acrylic cards hung inside the shop from suction-cup hooks, in a row high on the glass above the sets so
  the news stays the focus. `tools/tv_store.py` (`acrylic_card`).
- **TV shop glass copy:** the HouseCredit offer is now one tall promo notice (0% interest, up to 12 months,
  no down payment, valid ID, fine print); beside it a "Tanggap dito ang:" strip with BCash (blue) and Loro
  (black, green) stickers, each with a QR and a line of Filipino copy. `tools/tv_store.py` (`build`).
- **TV news pole and glass:** the pole is thinner (radius 0.22); its posters are septic siphoning, job
  hiring (call Gloria), election, drug watchlist, police and food delivery flyers (`poster_image`). Three
  payment stickers sit beside the 0% promo notice: BCash (blue), HouseCredit (red), Loro (black, green text).
- **TV news pole:** the pole now stands right at the shop front (x 1.72, z -0.42) so nearly all of its
  width shows, round and covered in posters.
- **TV news scene, nearer (same branch):** camera moved to z -1.45 so the shop fills the picture, Peter is
  nearer still (z -1.0) and blurred, the pole has 56 facets so it reads round.
- **TV news scene, focus shot (same branch):** Peter is pushed to the left edge as a shoulder view and
  blurred (gaussian, premultiplied) so the lens focuses on the news; two shelves of three bigger sets
  (`crt_set(..., k=1.5)`) instead of three rows of five.
- **TV news scene, super close (branch claude/tv-store-closeup, on claude/tv-store-shoulder):** the camera
  is right at the glass; the rider is seen from head to chest only, large at the left; the tube sets, the
  double door with its OPEN sign and the posted pole fill the rest. `tools/tv_store.py` (`build`).
- **TV news scene, over the shoulder (branch claude/tv-store-shoulder, on claude/tv-store):** the picture
  is taken over the rider's shoulder, with him standing near the glass at the left so the news is clear;
  a thick wooden pole pasted with posters at the right; three rows of five identical tube sets side by
  side; a double glass door with push bars and an OPEN sign; the shops next door are sharp (no blur); no
  motorbike. The rider's anatomy (sloping shoulders, V-taper torso, thigh shape, rim light) was improved
  only where he is seen. `tools/tv_store.py`, `tools/rider_back.py`.
- **TV news scene redone (branch claude/tv-store):** `tokhang_tv_news.png` is now a daylight TV shop
  seen through its glass front from an oblique angle (`tools/tv_store.py`): 14 sets of every size
  showing drug-war headlines, reflections and sun glare on the glass, the sign, awning, shutter, and
  a parked delivery bike; in the foreground a rider seen from behind (`tools/rider_back.py`, drawn
  from scratch: pink helmet, black jacket, pink delivery bag, soft-lit solids, not the game's Peter).
  Rendering takes about 75 seconds (the street footage is cached in /tmp). Still a stand-in.

- **One Peter (branch claude/intro-peter):** the intro picture `tokhang_rider.png` was its own
  drawing of Peter, unlike the portrait every other scene uses. It was deleted and redrawn by
  `tools/draw_placeholders.py` from the portrait (`peter_1.png`), the market and the motor prop, and
  is now in `PLACEHOLDERS.txt` like the other stand-ins. A real painting should replace it later.

- **Main screen and saves GUI (branch claude/menu-polish):** the menu words are plain text centred
  under the logo, gold when pressed; Continue and New Game open `scripts/save_slots.gd`, a
  left-aligned list of rows (4:3 picture of the place the save stopped in, details beside it),
  tap a row to select, Load and Delete buttons at the right bottom-aligned with Back, each with a
  confirmation window; empty slots are a grey void; the "Tap outside to close" note now
  sits right under the open modal (settings, book, clipboard, dev tools, the questions).

- **First-run spine (branch claude/first-run-spine, stacked on calm/text menu):** Tokhang's errand now
  has two ways to say yes on the first run (both send Peter); in Padala on a save's first run the key
  ends with Eli catching Mercy (`padala_caught`, gives Si Father Eli), and the food ending shows the
  man's face, so every first-run way out shows the reveal. Bible rule R11.

- **Calm scenes (branch claude/calm-scenes, stacked on one-truth-story):** the camera drift, the
  breathing of people and portraits, the 21 Hz flame flutter and the turning of the hint glint were
  removed because on a phone they read as everything vibrating. `stage_life.gd` now only adds the
  living light (slow candle glow, dust, steam, clouds). The room, props and people are still.

### One-truth story rework (branch claude/one-truth-story, not merged yet)

- **What changed:** the game is now ONE story in one fixed story time, not three stories on many timelines with a timelines chart. Kumpisal is Saturday afternoon, Padala Saturday night, Tokhang Sunday afternoon.
- **Starting points:** a save can start from three places. A run plays all three stories going round the circle from the start: market = Tokhang, Kumpisal, Padala; church = Kumpisal, Padala, Tokhang; room = Padala, Tokhang, Kumpisal. The first run of a save always starts at the market.
- **Echoes and flags reach forward in story time:** Kulas alive (`run_kulas_safe`) warns the buyer in Tokhang and offers the water gun; Peter seen at Eli's door (`run_peter_seen`); Mercy shot running (news in Tokhang).
- **True ending** (`walang_namatay`: `kumpisal_sinamahan` + `padala_pinalaya` + `tokhang_safe`) plays an epilogue at the end of any run that earns it.
- **After a run:** "Ang Nangyari", then "Ayusin ayon sa oras", then the main screen. The timeline chart is deleted: `scenes/timeline_reveal.tscn`, `scripts/timeline_reveal.gd`, `scripts/timeline_map.gd`, `story/timelines.json`.
- **Start screen** (`scripts/start_screen.gd`, class `StartScreen`): opening a save shows a Continue card (3:4, upright), a hairline, then "Select your starting point" with three 3:4 story cards. The Kumpisal and Padala cards stay closed until the first run is finished.
- **Dev tools:** jump points are "Start Points" and "Later In A Run"; the Endings list has "First Run Ending" and "True Ending".
- **Removed:** the per-timeline music pitch and tint (`MusicDirector`, `StageLife`).
- **Tests:** `tests/playthrough.gd` plays 6 runs (was 12).
- **Story text:** fully rewritten in `story/*.json`.
- **Not merged.** The changes are still uncommitted in the working tree of `claude/one-truth-story`.
- **Remaining steps:**
  1. Rewrite `docs/STORY_BIBLE.md` to the new script (being done separately).
  2. Re-check the cutscene artwork (`assets/cutscenes`, `PLACEHOLDERS.txt`) against the new lines.
  3. Visual check of the start screen in a windowed run (screenshot), phone upright.

- **The cloud session cannot push to `main` or push tags** (HTTP 403). Work goes to a
  `claude/...` branch and a PR the user merges on GitHub. Decision 12 landed as PR #1, and Pages
  deployed it. The **v0.8.0 tag is not on GitHub**; the user can add it from Releases (tag
  `v0.8.0`, target the PR #1 merge commit `df91f23`).
- After playtesting v0.8.0 on the iPhone the user said the game "should be rendering its right
  ratio": they want the **16:9 shape kept, with black bars**, not the window growing to fill the
  phone. The `expand` stretch aspect was removed (v0.8.1), and they asked for **"Progress saved"
  at the top centre** (it was bottom right). Then they said "it should be fit to screen" and,
  asked, clarified: **"it fills the width of the screen while maintaining 16:9 ratio"**. So
  (v0.8.2) `expand` is back, each place is scaled by `ScreenFit.width_scale` (screen width /
  1280) about its centre, so on a wide phone a thin strip at the top and bottom is cut off; on a
  taller screen black bars show above and below. The blurred side fill was removed. The HUD and
  dialogue are laid out on the real screen. Don't change this fit again without asking.
- **Final fit (v0.9.2):** the user plays with the phone **upright (portrait)**. They want the whole game,
  buttons included, as one 16:9 box filling the phone's width. So `expand` is removed again
  (Godot's default `keep`): black bars above and below in portrait, at the sides on a wide
  landscape phone. `ScreenFit` width-fit code stays and is harmless at 1280x720.
- v0.9.0 (user's requests): the main screen's **Settings text row is removed** (the gear stays);
  **Stories/Endings show in every build** while in development; the market's **motorcycle is a
  large, out-of-focus foreground** at the bottom left, its top right in view (delivery box,
  rack, tail light and part of the seat; `ArtSlot.depth_blur` 5); **Gloria, Ben and Gwen's portraits are mirrored** in the
  Kumpisal scenes (`Location.flipped_portraits`). Tapping Ben or Gwen shows **both of them on the
  right for the whole talk** (Ben in front, Gwen behind; `DialogueBox` companion portrait), in
  script order, Ben first.
- Later in the same PR (#4), on the user's requests:
  - **Everyone faces each other** in dialogue: portraits are mirrored by side
    (`DialogueBox.PORTRAITS_FACING_RIGHT`), so left faces right and right faces left.
  - **Confessions start at once**; each confession's title shows at the top meanwhile.
  - **Objective hint** is now one fixed glint per target that breathes slowly (3.4 s), after
    8 s idle, God of War style (`Location._show_glints`).
  - **Dev "Jump to" window** (now "Developer tools") on the main screen (`scripts/dev_jump.gd`), replacing
    Stories/Endings: every story of every timeline, the confessions, the room after Padala's
    intro, and the endings. Unsaved runs, no confirmation.
  - **Police card is now a police emergency poster** on the wall ("Read the police emergency
    poster"; ending card "Police Poster"; ids unchanged). **Keys redrawn from a low side angle.**
    Both drawn by `tools/draw_props.py`, plus a floor-lying food delivery card.
  - **Props sit in the room**: `ArtSlot.grounding` (CONTACT or WALL shadow, room light, film look).
  - **GUI polish**: plate behind the scene title, soft window behind objectives and the title
    screen's lists, `TapHint` pill, `TitleOrnament` on title/ending cards, and a restyled,
    larger timeline ending (plum sky, window-coloured cards). Open question 4 (keep the gear) is answered.
- All 6 phases of the GUI plan are done. Phase 5: the retro text blur (`retro_text.gdshader`) is
  lighter (0.7, boost 1.2) and measured in the game's 1280x720 pixels (`screen_scale`, kept up to
  date by RetroText), so text is equally soft on a small window and a big phone screen; the
  title and ending cards already used the window palette's cream lettering and ornament. Phase 6:
  every fade uses the same gentle sine curve (only the typewriter, push-ins, pans, flash and
  shake stay steady), and every button sinks to 95% while held and springs back when let go
  (`UiSkin.add_press_bounce`, given by RetroText; the developer tools keep their plain look).
- **Coaches now have the Pages link.** So (PR after #9): the main screen's dev window is folded into
  one cool-blue "DEV · Developer tools" button (opens a window with a DEV badge, a note that the
  shortcuts are for testing and save nothing, and a Hide button), with a "DEVELOPMENT PREVIEW"
  note at the bottom left. Developer UI uses its own slate blue and mint (`SoftWindow.Look.DEV`,
  `main_menu.gd` `_dev_box`), never the game's warm colours, so it can't be mistaken for the game.
  **The in-game Undo button is removed** (GameState's undo history stays, unused by the HUD).
- **Telephone** in the apartment is now drawn by `tools/draw_props.py` as a tiny 3D model (wedge
  base, bevelled handset, textured keypad face) at the painting's angle, fitted to cover the
  painted phone exactly; the painted coiled cord stays.
- PR #8 (Continue picks the save slot, Load Game removed) was still open at this point.
- **Top left is now: gear, terminal icon, place name** (user's request). The terminal icon
  (`assets/ui/terminal.png`, drawn by `draw_props.py` in the gear's style) opens the centred
  **Developer tools** modal (`scripts/dev_tools.gd`, `DevTools`), on the main screen and in
  gameplay; it is a child of the gear so it fades and hides with it. Then (same PR #12, user's
  follow-up): the terminal icon is just a dark screen with a `>_` prompt (no grey frame), the
  same visual size as the gear; the disclaimer "# Continuous improvement in progress." lives
  inside the modal (nothing fixed at the bottom left any more); and the modal looks like a
  simple **black and white** terminal (the user rejected green text, prompts and folder names as
  too complicated): DejaVu Sans Mono, a title bar with "Close ✕", faint scan lines, a plain
  heading and note, and framed rows that turn white while held. Main screen lists now share one
  spacing (52 px rows, 12 px gaps, 24 px window margin top and bottom, centred text). The user disliked "not the final game" wording. Paddings were widened: settings modal (34 px, more row spacing), main screen windows,
  objectives window (moved in from the edge and level with the place name), place-name plate.
- PR #13 (user's requests): the **gear and terminal icons are twice as big** (64 px pictures in
  80 px buttons; the place name and the confessional's back link moved to match). Gameplay **no
  longer moves the HUD in for the phone's safe area** (`Location._keep_clear_of_notch` removed):
  the 16:9 box already sits inside the screen, and the extra side margins looked wrong next to
  the main screen. Developer tools layout: header "Developer tools" left, plain "Close" text
  right; body heading "Jump into specific parts", the rows, then a footer line "Developer Note:
  Continuous improvement in progress. Some parts may appear as placeholder."
- PR #14 (user's request: simpler black and white, rounded, strictly Apple design language,
  fewer jump buttons, better copy): the developer tools are now one Apple-style sheet with no
  drill-in. Title "Developer Tools" and "Done"; sections Main / Kumpisal / Padala Timeline and
  Endings on rounded cards (Apple dark greys, 50 px rows, inset dividers, grey chevrons); the
  footnote "This build is still in development, so some parts may use placeholder art or text."
  sits under the first section (the user had "Progress from these shortcuts isn't saved" removed). `DevJump.GROUPS` now
  holds only each story's start plus the Kumpisal confessions (the in-church, in-room and
  Peter/Gwen-buying points were removed).
- PR #15 (user's request): on a phone or tablet held upright, the web page **turns the game to
  landscape** by itself (browsers cannot lock orientation, iOS Safari above all). A script in the
  Web preset's `html/head_include` rotates the canvas 90°, sizes it to the long side
  (`canvas_resize_policy=0`), and rewrites each touch and mouse event's position before the
  game reads it (touch lists are swapped for turned copies, since a Touch's own position cannot
  be changed), so touches stay real touches. Checked in Playwright as a 390x844 touch phone:
  taps on Tap to start, Continue and the terminal icon land, and a finger drag scrolls the
  developer tools list. Not yet checked on a real iPhone.
- The **content warning** no longer lists kinds of content (the user felt that was a spoiler):
  "SANGA is a work of fiction intended for mature audiences. It explores dark themes and
  includes scenes some players may find disturbing. Please play at your own discretion, and take
  a break whenever you need one." (`boot.gd` `WARNING_TEXT`).
- **Main screen is Continue / New Game / Quit** (the user found Continue plus Load Game
  redundant; this replaces the never-merged PR #8). Continue lists the saves ("Choose a save",
  plus "Delete a Save"); picking one opens it with **Continue Progress** (only while a run is in
  progress) and **Choose Starting Point**. Choosing a story while a run is in progress asks
  "Start from Kumpisal?" with the note "Your current progress in Slot 1 will be lost." and
  "Start Over" / "Cancel". New Game over a used slot asks "Replace Slot 1?"; deleting asks
  "Delete Slot 1?" with "This can't be undone."
- **Confessions show the sad pictures** (`_2`: Gloria, Batista, Gwen) of whoever is confessing
  (`Location._sad_portrait_for`, `SAD_PORTRAIT_SUFFIX`). Kulas has no sad picture yet, so he
  keeps his usual one until `kulas_2.png` is added. The sad pictures of Gloria and Batista look
  the other way from their usual ones, so `DialogueBox` takes per-picture facing entries
  (`PORTRAITS_FACING_LEFT` = gloria_2 and gwen_2, `batista_2` in `PORTRAITS_FACING_RIGHT`); all four
  confessors were checked facing Father Eli.
- **Game direction for the PH national game dev competition (decided):** the **Alaala** mechanic.
  Every death the player sees becomes a permanent memory per save that unlocks one new choice
  elsewhere; three of them in one Main Timeline run give the true ending "Walang Namatay".
  The full design, hidden truth, rules R1-R8, every line of the new script (natural modern
  Tagalog, written by Claude at the user's request) and the new art list are in
  **docs/STORY_BIBLE.md**. Presentation stays 2D with 2.5D staging (layered parallax places,
  living cutscenes, breathing characters, light); no 3D rebuild. The user approved Father Eli
  confessing his own sin. Next: Phase 1 (Alaala system), then content, endings and art, map,
  playtest.
- **Alaala built (PR after #19), phases 1-3 of the plan in code:**
  - System: `GameState.alaala` (saved per slot, never reset), `scripts/alaala.gd`, awarded by
    `StoryDirector._remember` at every finished story or run (a card: name, memory line,
    "Hindi mo na ito makakalimutan."). Every run opens with the prologue (`story/prologue.json`).
    Developer tools have "Remember All Memories" / "Forget All Memories"; jumps keep memories.
  - Script: all of docs/STORY_BIBLE.md is in `story/tokhang.json`, `kumpisal.json`,
    `padala.json` (nave talks, confessions with choices, revelation lines, the five Alaala
    choices, endings Ligtas, Sinamahan, Pinalaya, Tanod, Nagtago and the true ending
    Walang Namatay). Run flags: `run_kulas_safe`, `run_eli_confessed`, `run_tanod`.
  - Art: 46 stand-in cutscenes from `tools/draw_placeholders.py`
    (`assets/cutscenes/PLACEHOLDERS.txt` lists them). Painting them is the main art task.
  - **Phase 4 done (timelines chart):** SUPERSEDED by one-truth rework: the chart and `story/timelines.json` were deleted. `story/timelines.json` has cards for every new ending
    (main: Ligtas, Sinamahan, Pinalaya, Walang Namatay; kumpisal: Nagtago, Pinalaya; padala:
    Tanod, Sinamahan) and 32 realities, each listing every outcome of its run. `TimelineMap
    .reality_for` matches exactly (same outcomes, no more, no fewer). Older saves' reality names
    are kept as `aliases`. The smoke test checks the chart. The developer tools' Endings list grew
    to match.
  - **No spoilers of what was not played** (user: "hide possible outcomes to player... plan
    first", then "keep the closing line, go ahead"). The chart shows only finished realities: no
    "???" cards, no faint lines, and rows are packed (`_pack_rows`) so unreached branches leave no
    gaps. The memory book lists only held memories, with no count ("Wala ka pang naaalala." when
    empty). Every run now ends with **"Ang Nangyari"** (`scenes/run_recap.tscn`,
    `scripts/run_recap.gd`): the run written into the open book: stories in played order, the
    player's own choices in quotes, each ending's line, memories gained, then "Ito ang nangyari.
    Hindi ito ang tanging maaaring mangyari." It turns pages by tap when long, then goes to the
    time-order card (main timeline) or the chart (other timelines). The record is
    `GameState.run_log` (saved per slot), filled by `StoryDirector._enter_chapter`,
    `DialogueBox.choose`, `Cutscene` ending cards (memory cards skipped) and
    `StoryDirector._remember`. The smoke test checks the recap.
  - **Phase 5 done (full playthrough):** SUPERSEDED by one-truth rework: the playthrough now plays 6 runs, not 12. `tests/playthrough.gd` plays the real game from a fresh
    save, tapping what the idle hint points at and choosing by a plan, through 12 runs that reach
    all 20 outcomes (12 of the 32 realities), with the true ending on run 2
    (right after a police-poster first run, as the bible says). Each run must finish, make the
    expected reality, give the expected memories, and show the recap; no placeholder line may
    show. All 5 memories and 12 realities end up on the save. It found one bug, now fixed: a
    quick second tap in Tokhang or Padala, in the moment after a dialogue closes, could act
    before the first tap finished (picking the realistic gun right after choosing the water gun
    lost the Ligtas ending; taking both Padala cards). Both scenes now ignore taps until the
    last one is handled (`_handling`). A read of the full transcript found no story problems.
  - **2.5D staging, the code part (story bible section 12):** `scripts/stage_life.gd`, added to
    every place by `Location._ready`. The camera drifts slowly (±6 px, up to 1.2% zoom, cycles
    of 23-37 s); people move 1.35× and blurred near things (market motor, a key) 1.9× as much as
    the room, so there is depth with the existing art; every layer is 1.4% larger so no edge
    shows. People and dialogue portraits breathe (0.7% taller, about 4 s, each on their own
    rhythm). `shaders/stage_light.gdshader` adds flickering altar candles and wall lamps in the
    church, dust in the sunlight, steam from the bathroom door, and slow cloud shadows. Cutscene
    pictures already pushed in. Checked in screenshots; smoke test and playthrough pass.
    **Left of section 12, needs art:** each place split into background / middle / foreground
    layers, and the key cutscene reveals split into layers.
  - **Stand-in cutscenes** (user: "better placeholder art", without Higgsfield): all 46 cutscenes
    that were grey "Placeholder" text cards (not only the 13 listed; only `padala_bath` and
    `tokhang_rider` are real paintings) are now composed by `tools/draw_placeholders.py` from the
    game's own art, the way `tokhang_rider.png` is: a background cropped and graded for the
    moment (night, dawn, police lights, sepia flashback, a gunshot's red flash), the characters'
    full pictures (sad ones where it fits, silhouettes for anyone not yet revealed or nameless,
    such as the tanods), props (keys, telephone, the toy guns cut from the market stall), motion
    blur, a confessional grille, a TV, bus and jeep windows. No text. Saved at 1280x720 in 256
    dithered colours (23.8 MB for all, less than the old cards); the web build shrank a little.
    Each shot is one small function, so a single picture is easy to adjust:
    `python tools/draw_placeholders.py <name>`. Real paintings still replace them (save under the
    same name, remove the name from PLACEHOLDERS.txt).
  - **Drawn in 3D with Pillow** (user asked why not new art with correct angle and perspective;
    I explained Pillow can build objects and places but not anime characters in new poses, and
    offered the shots whose subject is a thing; the user said draw the police car first):
    `padala_police_car` and `padala_police_car_leaves` are now a real night street built in 3D
    (`tools/scene3d.py`, `tools/street_scene.py`): Mercy's building with grilles and lit
    windows, the lit doorway, poles and sagging wires, a sodium lamp, wet asphalt, and a PNP-style
    white and blue police car (POLICE on the side) whose light bar washes the wall and road
    pixel by pixel. Batista and the man stand at the doorway as backlit cut-outs inside the 3D
    scene (the car hides what is behind it). Leaving: lights off, tail lights down the street,
    the man watching from the door. Offered next, same way: the jeepney inside, Batista's badge
    on a desk, the prison visiting booth, the TV news.
  - **Design audit and new plan (user approved "proceed"; dev tools stay).** Scores: first-run
    reveal 6, starting-point twist 5, causality 4, variation 6, choice weight 3, system
    interaction 5, replay friction 3, endings/goals 6, scope 8, theme 8, presentation 5, pacing 6.
    The plan, one PR per phase, smoke test and playthrough must pass, no new places, characters
    or endings:
    - **A. First-run reveal** (DONE): Gloria plants Father Eli in Tokhang's pay scene (Ben runs
      around the church; only Father Eli can calm him); the main key ending first shows
      `padala_collar.png` (a priest's shirt on a nail by the bathroom door) and Mercy's
      "...Pari?", so a key-ending first run leaves with the doubt, the police ending with the answer.
    - **B. Respect replays** (DONE): `GameState.seen_lines` (saved per slot, kept across runs)
      remembers every line shown. While a line seen before is on screen, a "Skip ▸▸" tab sits on
      the dialogue box's top right; tapping it races through seen lines and stops by itself at
      the first new line or choice. A line a memory added shows "✦" after the speaker's name. In
      the nave, once per visit, if every conversation there was heard before (one answer per
      choice is enough) and nothing in them changed, Father Eli is offered "Dumiretso sa
      kumpisalan." / "Kausapin muna sila." The playthrough takes the shortcut in two runs.
    - **C. Echoes** (DONE): bible rule R9 and table. Five Kumpisal choices (Mercy, Gloria,
      Batista's talk, Batista's and Gwen's confessions) set `run_echo_*` flags; nine echo lines
      (`"echo": true` + `if_flag`) come back in Padala's opening, the Police Poster ending, the Run
      ending and, only when the run starts in Padala, Tokhang's phone call. Echoes flow forward in
      story time only (the Tokhang haggle cannot echo into the past). DialogueBox logs them; the
      recap shows them as "↳ Speaker: line". The playthrough checks echo counts in three runs and
      picks the other answers in two Kumpisal-timeline runs.
    - **D. "Ayusin ayon sa oras"** (DONE, the signature): after the recap's last page the ink
      fades and the run is written again in time order ("Kumpisal · Nakaraan", "Padala ·
      Kasalukuyan", "Tokhang · Hinaharap"), keeping only linked moments and each story's ending;
      red threads draw down the page margins (or the gutter) in their own lanes, with a knot at each
      end. `scripts/time_threads.gd` finds them: a choice and its echo share a flag (Alaala.
      apply_option now writes the flag on the logged choice), plus `story/threads.json` (choice to
      outcome, outcome to outcome). Only threads whose two ends happened this run, only forward in
      time. The run log now also records `{"outcome": id}`. The old time-order card is removed
      (StoryCard.show_time_order); the main timeline goes back to the main screen after the book.
      Decided not to add cause lines to the chart: the threads already show causes.
    - **E. The priest's answer** (DONE): the main menu's "Choose Starting Point" list is gone. A
      save offers "Continue Progress" and "Start a New Run" (confirmation when a run is in
      progress). The first run still starts in the market; after it, a new run plays the prologue
      (`StoryDirector.begin_from_confession`): the voice asks "Saan po ako magsisimula, Padre?"
      and the player answers "Sa nakaraan / kasalukuyan / hinaharap, anak. Sa simbahan / kwarto
      / palengke." (a line choice setting `prologue_start`), the voice takes it up, and the run
      begins (`begin_with(story, false)`). After every ending but Walang Namatay, the recap ends
      with the voice over black: "Hindi pa po iyon ang buong kumpisal, Padre." The playthrough
      starts two runs this way.
    - **F. Feel** (DONE): SUPERSEDED in part by one-truth rework: the per-timeline tint and music pitch were removed. a `CanvasModulate` tint per timeline in StageLife (Kumpisal timeline
      candle-amber, Padala timeline cold blue; HUD untouched) and music pitch per timeline
      (`MusicDirector.TIMELINE_PITCH`, 0.97 / 0.94); taking a ✦ choice plays `memory.wav` (new in
      `compose_sounds.py`) and a golden ring across the screen (`Sfx.memory`,
      `shaders/memory_ripple.gdshader`); after two wrong keys Mercy says the worn key is used
      often and it catches the light; each memory in the book shows a faint "↳" hint
      (`alaala.json` "hint"); Kumpisal's opening gains one line per timeline (bible section 8).
    - **G. Playtest** with the checklist (revelation timing, causality, replay motivation). The
      user's to run.
    - **Art, object shots in 3D** (DONE for six): `tools/object_scenes.py` draws
      `tokhang_tv_news` (an old set in a dark room; on screen the police street from
      street_scene, a red bar "OPERASYON: 3 PATAY", LIVE, scan lines), `padala_jeep` (inside a
      jeepney from the back: red benches, chrome rails, painted ceiling, city lights streaking past
      the windows, a dark driver, Mercy seated looking out), `true_morning_batista` (morning sun
      through blinds on a desk: the badge, a generic gold "PULIS" shield, on a handwritten
      "Pagbibitiw" letter, and a cold coffee) and `true_visiting` (a visiting booth from the
      visitor's chair: counter, green partition, glass with reflections, a round speaking grille;
      Father Eli behind it in an inmate's orange shirt, made by recolouring his black clothes,
      `in_jail_orange`), `prologue_booth` (the priest's side of the confessional: dark wood, a
      lattice screen, a faint candle glow and the blurred shape of someone kneeling close) and
      `padala_luggage` / `padala_luggage_closed` (a hard suitcase on the tiled floor, open and
      empty with its lining crushed; then shut in the dark, a cold strip of light on its edge).
      Still stand-ins for real paintings.
    - **Art in parallel:** object shots in 3D (jeepney, badge, visiting booth, TV news); ~10 key
      character shots need an artist (or Higgsfield if the user allows).
    **Art:** paint the cutscenes for real (user or artist), most important first: the reveals
    (`padala_reveal_eli`, `tokhang_trade`, `true_visiting`) and the deaths.
- **No sound on iPhone** (user report). The game itself plays music (checked: player playing,
  buses not muted). Fix in the Web preset's `html/head_include`: it wraps `AudioContext` to keep
  every context the engine makes and resumes them on each `touchend`/`pointerup`/`click`
  (Safari only unlocks sound on those, not on `touchstart`), and sets
  `navigator.audioSession.type = 'playback'` so the iPhone's silent switch does not mute it.
  Not yet confirmed on a real iPhone.
- **The web build was completely silent** (measured: peak 0.0 at the browser's output, desktop
  Chromium too). Cause: the Sound and Music buses were only created at runtime by Settings, and
  Godot's web (sample) playback never routed them. Fix: `default_bus_layout.tres` defines both
  buses. Measured after: peak about 0.015 on the main screen (music at -24 dB is very quiet on a
  phone speaker; raise `MusicDirector.VOLUME_DB` if the user finds it too soft).
- **Every choice is one short line** (user's rule). All choices in the story files and the bible
  were shortened (for example "Sasamahan kita.", "Ipagdasal mo sila.", "Magsama po siya ng
  tanod."). The smoke test fails if any choice is wider than 560 px at size 26 with the ✦.
- **Script pass (user's rules, also in the bible):** choices never hint at their outcome (the
  water gun is now "Ito na lang ang bilhin ko." / "Titingin pa ako."); Father Eli speaks as a
  priest in every line and choice (only his secret calls and the door keep "pare", as the
  reveal); stage directions are Tagalog between asterisks (*Tumawa*). The Main Timeline has no
  prologue. Story time is Kumpisal (past), Padala (present), Tokhang (future); the Main Timeline
  already plays them future, past, present (Tokhang, Kumpisal, Padala).
- **Choices and objectives without boxes** (user: the boxes were too big for the layout).
  Choices are plain golden ochre text with an outline (`DialogueBox._style_choice`), with a small
  note above them: "Your choice may change the timeline." (`CHOICE_HINT`). The objectives list
  has no soft window behind it any more; the top shade keeps it readable.
- **Top-right HUD icons** (user's request): an old open book (opens the Alaala window: each
  memory held by name and line, the rest "???", with "2 / 5") and a blue clipboard (opens the
  objectives window, finished ones struck through). They replace the on-screen objectives list
  (`ObjectivesPanel.SHOWN_ON_SCREEN = false`; it still tracks objectives, plays the strike sound
  and feeds `GameMenu.set_objectives`). The clipboard swells briefly when objectives change.
  Then (user): the clipboard is a realistic brown hardboard one with a steel clip and rivets,
  and the gear was redrawn in the same detail (brushed steel, bevel, hub); `gear.png` is now made
  by `tools/draw_props.py` too. Each icon's `picture_size` is set so it covers the same area as
  the gear (gear 64, book 67, clipboard 59). Later (user): no ribbon on the book, and all three
  were redrawn with more depth: the gear's thickness and bevel, the book's leather cover, stacked
  page edges and gutter shadow, the clipboard's board thickness and lifted paper corner, plus a
  soft drop shadow on each (`_finish` in `draw_props.py`). The book is drawn as if seen more from
  above (`BOOK_HEIGHT` in `draw_props.py`) so it stands as tall as the clipboard on screen.
  Icons drawn by `tools/draw_props.py` (`assets/ui/book.png`, `clipboard.png`), window in
  `scripts/journal_modal.gd`. All HUD icons hide during dialogues (`GameMenu.get_hud_icons`).
- **Windows look like their opened icon** (user's request): the memories are written across an
  old open book (`assets/ui/book_spread.png`), the objectives are a checklist on the clipboard's
  ruled paper (`clipboard_board.png`, each line on a rule, ☑ and struck when done), and the
  settings sit on a dark riveted steel plate (`steel_plate.png`, a 9-slice `StyleBoxTexture`).
  All drawn by `tools/draw_props.py`. Text on paper is dark ink without outline. **No window has
  a close button any more** (settings ✕, journal ✕ and the developer tools' "Done" removed):
  tapping outside closes, and "Tap outside to close" sits at the bottom centre
  (`UiSkin.add_close_hint`).
- **Music volume:** the user still has not confirmed -24 dB sounds right.

## Open questions

1. **Pushing to `main` from the cloud** is refused (403). Ask the user how they want changes
   landed: PRs they merge, or granting the session push access to `main`. (Pages itself is
   solved: the repo is public and the source is GitHub Actions.)
2. **Is the music quiet enough now?** If not, lower `MusicDirector.VOLUME_DB` further.
3. SUPERSEDED by one-truth rework: there are no Alternate endings any more. **Alternate ending numbering** (table above) is an assumption. Ask if it matches what they
   mean by "Alternate 1 to 5".
4. **Keep the main-screen gear** now that a Settings text row exists? We offered to remove it and
   got no answer.
5. **Android preset:** the repo now has one (`preset.1`, package `com.withearl.sanga`). The user
   once said "keep the Android preset untouched", so they may have their own on their desktop.
   If so, theirs wins: replace `preset.1` with it and keep their package name and keystore.
6. ~~Ending lines in Filipino?~~ Done: the user chose to translate them. Every ending card's
   line (and so the recap book) is natural modern Filipino, e.g. "Namatay si Peter.", in the
   story files and the bible. Card titles stay as they were. The timelines chart's own card
   descriptions stay English, like the rest of the UI text.

## Known issues and notes

- On iPhone, the web build cannot vibrate (Safari has no vibration API), so the Vibration switch
  is hidden on web.
- The web build is about 78 MB (39 MB engine wasm + 39 MB pck), so the first load on a phone takes
  a while.
- In one early test, the main screen's Settings button did not open the modal. It was not
  reproduced in later runs and was most likely the test's timing. Keep an eye on it.
- Headless Godot runs print RID and ObjectDB "leaked at exit" warnings, which are harmless.
- The Godot MCP in the desktop app needed `GODOT_PATH` pointed at the exe *inside* the
  `Godot_v4.7.2-stable_win64.exe` folder. That only matters on the user's Windows machine.

## Next tasks, in order

1. Get `claude/button-colors` onto `main` and tag v0.8.0 (see "Where we stopped").
2. Ask the user to playtest the new UI on the iPhone at `https://with-earl.github.io/sanga/`:
   text size, the typewriter speed (`DialogueBox.LETTERS_PER_SECOND`), the plum window colour
   (`SoftWindow.FILL_TOP`/`FILL_BOTTOM`), and the blurred side fill.
3. Ask open questions 2-4 when it fits naturally. Don't block work on them.
4. Ideas offered but not requested, so don't do them unasked: music that dips or changes at story
   moments (cutscenes, the confession sequence), and recolouring the main menu buttons or story
   title cards ochre.
