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
- Phases 1 to 4 of the GUI plan are done and checked in screenshots at 16:9, 19.5:9 and 4:3.
  Left from the plan: **Phase 5** (a lighter text blur that is the same on every screen, and the
  title/ending cards moved fully onto the window palette) and **Phase 6** polish (consistent
  easing, a small press bounce). Both are optional.
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
- **Confessions show the sad pictures** (`_2`: Gloria, Batista, Gwen) of whoever is confessing
  (`Location._sad_portrait_for`, `SAD_PORTRAIT_SUFFIX`). Kulas has no sad picture yet, so he
  keeps his usual one until `kulas_2.png` is added. The sad pictures of Gloria and Batista look
  the other way from their usual ones, so `DialogueBox` takes per-picture facing entries
  (`PORTRAITS_FACING_LEFT` = gloria_2 and gwen_2, `batista_2` in `PORTRAITS_FACING_RIGHT`); all four
  confessors were checked facing Father Eli.
- **Music volume:** the user still has not confirmed -24 dB sounds right.

## Open questions

1. **Pushing to `main` from the cloud** is refused (403). Ask the user how they want changes
   landed: PRs they merge, or granting the session push access to `main`. (Pages itself is
   solved: the repo is public and the source is GitHub Actions.)
2. **Is the music quiet enough now?** If not, lower `MusicDirector.VOLUME_DB` further.
3. **Alternate ending numbering** (table above) is an assumption. Ask if it matches what they
   mean by "Alternate 1 to 5".
4. **Keep the main-screen gear** now that a Settings text row exists? We offered to remove it and
   got no answer.
5. **There is no Android export preset** in the repo. The user said "keep the Android preset
   untouched", but there never was one here; it may only exist on their desktop. If they add it
   from the editor, it will sit next to the Web preset.

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
