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
     | Alternate 1 | main | Police Card |
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

## Where we stopped

- **The last thing the user asked** was this handoff: HANDOFF.md, CLAUDE.md, iPhone web
  playtesting, a cloud setup script, `.gitignore`, then commit and push everything. It was done
  in this release, and all work is committed and pushed. There is no half-finished work.
- **Before that,** the user asked "why does the volume of background music is still high". In the
  code everything was already quiet (-36 dBFS). The likely causes were a stale running copy or a
  high system volume. Music was lowered anyway to -24 dB (v0.6.2). **The user has not confirmed
  that it now sounds right.**

## Open questions

1. **GitHub Pages on a private repo.** `with-earl/sanga` is private. GitHub Pages for private
   repos needs a paid plan (Pro, Team or Enterprise) on the owner account `with-earl`, and the
   site itself is still public. If the deploy job fails with a Pages error, the user must either
   upgrade, make the repo public, or choose another host. Pages also needs **Settings > Pages >
   Source: GitHub Actions**, set once by the repo owner. The previous session could not check
   the Actions result (no `gh` CLI on that machine).
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

1. In the cloud session, run the first steps above. Check that the **Web build** workflow ran and
   deployed. If Pages failed, explain open question 1 and get the user's choice.
2. Give the user the Pages URL `https://with-earl.github.io/sanga/` to open on the iPhone, and
   take their playtest feedback. Likely areas: touch input, load time, audio after "Tap to
   start", text size on a small screen, and the landscape layout.
3. Ask open questions 2-4 when it fits naturally. Don't block work on them.
4. Ideas offered but not requested, so don't do them unasked: music that dips or changes at story
   moments (cutscenes, the confession sequence), and recolouring the main menu buttons or story
   title cards ochre.
