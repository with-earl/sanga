# SANGA, final plan for the contest

**This plan is frozen.** Nothing is added to the game unless it is in this file. If a good idea comes up,
it goes into "Later" at the bottom and is not built before every milestone below is done.

## 1. What the game is

SANGA is a 2D decision game about one night and two days told through three stories (Kumpisal, Padala,
Tokhang), played in any order. Its cozy look hides a drug-war story. Text is in English and Filipino. The
targets are Android and the web (iPhone playtest).

## 2. The mechanic: Pananda ("the bookmark")

> **When a run ends, your ending is bookmarked. Go back, cut one thread of cause and effect in the past,
> and see whether the ending you came from still exists. If your cut removes what it depended on, that
> ending never happened, the bookmark crumbles, and there is no way back.**

It is built on what the game already has: every run ends with a recap ("Ang Nangyari", then "Ayusin ayon
sa oras") that draws red threads from each choice to its outcome (`story/threads.json`).

### The rules (final)

1. **Bookmark.** When a run ends, the ending you reached is bookmarked automatically. That is "the present".
2. **Cut.** On the time-order recap, a red thread that is marked cuttable shows a small scissors icon. Tap
   it, confirm, and the game takes you back to that moment in the past story, with what you know.
3. **Choose again.** You make a different choice at that moment. The story continues forward from there, in
   story time, through the stories that come after it, to a new ending.
4. **Check.** The game compares the new ending with the bookmarked one. There are three results, and only these:
   - **Same present.** Your change did not touch what the ending depended on. You return to it. The recap
     says "Walang nagbago" (nothing changed). Fate held.
   - **Changed present.** The ending is different but the bookmark's moment still exists. You return to the
     new ending, and the old one is kept in the book as a path not taken.
   - **Erased.** You cut a thread the bookmarked ending depended on. It never happened. The bookmark
     crumbles, you cannot return, and the old ending shows in the book as a crossed-out card ("Nabura").
5. **Anchored moments.** A few moments carry a padlock and refuse to change, with a reason inside the story.
   This keeps the rules fair and keeps the player from rewriting everything.
6. **Warning, not spoilers.** A cuttable thread says "baka mabura ang kasalukuyan" (the present may vanish)
   but never says which result you will get.
7. **Memories (Alaala) stay as they are.** Only you remember an erased ending. It still gives its memory, and
   the story says so: "Ikaw na lang ang nakakaalala." No new rules for memories.

### Why this is the new idea (said honestly)

Time travel and paradox exist in games (Life is Strange, Deathloop, Steins;Gate). What SANGA adds, as far as
I know, is that **the player edits the cause-and-effect map of their own finished run, with one visible rule
and one bookmark, and a future can truly cease to be.** I would say "a fresh take", not "never seen", to the
judges.

## 3. What the player does, start to finish (the demo path, about 25 minutes)

1. Main screen: Story Mode, Shift Mode (locked), Quit.
2. **Story Mode, first run:** Tokhang, then Kumpisal, then Padala, with the fixed spine and its choices.
3. The run ends. The recap writes it in the book, then lays it out in true time order with red threads.
4. **A guided first cut** (the tutorial): one thread is already highlighted, with the text "Putulin ang sinulid".
   The result is the "Erased" one, so the player sees the rule once, safely.
5. Shift Mode unlocks. Pick a starting point from the carousel, play, and reach a recap with **3 cuttable
   threads** and 1 anchored moment. Each cut leads to one of the three results.
6. The true ending ("walang_namatay") needs one successful Erased cut and the three good outcomes it
   already needs. Its epilogue plays.

## 4. Scope: in, and out

**In (this is all of it):**
- The cut and check logic, as data in `story/threads.json` (`cuttable`, `anchored`, `depends_on`, `result`)
  and about 150 lines of code in a new `autoload/paradox.gd`.
- The cut UI on the recap (scissors, confirm window, the crumbling bookmark animation, the crossed-out card).
- **Four authored cuts** (1 tutorial in Story Mode, 3 in Shift Mode) with their alternative scenes and lines.
- One anchored moment, with its reason in the story.
- The book page that lists erased and changed endings.
- Tests: the smoke test and the playthrough extended to cut, return, and be erased.
- Contest material (section 7).

**Out (not before the end of this plan):**
- No new game modes, no new characters, no new locations, no new stories.
- No new menu screens beyond the cut UI and the book page.
- No more art passes except fixing what looks broken.
- No new mechanics next to Pananda.

## 5. The four cuts (proposed, for you to approve once)

| # | Where | The thread cut | If cut, result |
|---|---|---|---|
| 1 | Story Mode recap (tutorial) | the food call in Padala leads to Peter being shot in Tokhang | Erased: Peter's ending never happened |
| 2 | Shift recap | "Hintayin mo 'ko. Sabay na tayong lumabas." leads to the Kulas ending | Changed |
| 3 | Shift recap | "Ama, aaminin ko na ang lahat." leads to Padala's release | Changed, and it leads towards the true ending |
| 4 | Shift recap | the toy gun choice in Tokhang's market | Same present |

Anchored (candidate): Gloria's sale of the real gun, which always happens, because the market always sells it.
If you disagree with any row, say so now; this table is the last time it changes.

## 6. Milestones, in order, each with a test of "done"

| # | Milestone | Done when |
|---|---|---|
| M0 | Clean base | every open PR is merged, and `main` passes the smoke test and the playthrough |
| M1 | The check engine | `Paradox.check(cut, new_outcomes)` returns Same, Changed or Erased for all four cuts, tested without any UI |
| M2 | The cut UI | scissors, confirm, return to the past scene, and back to the recap, with no dead ends |
| M3 | The four cuts written | each has its alternative scenes and lines, in English and Filipino, in the bible |
| M4 | Erasure and the book | the crumbling bookmark, the crossed-out card and the book page work |
| M5 | The true ending | it needs the cut described in section 3 and plays its epilogue |
| M6 | Tests and balance | the playthrough covers all four cuts and all three results; zero errors |
| M7 | Device playtest | played start to finish on a real Android phone and on iPhone web; every found bug fixed |
| M8 | Contest package | everything in section 7 |

M1 comes first on purpose: if the rule cannot be made to work in data, we learn it on day one.

## 7. Contest material (made last, from the finished game)

- A one-page pitch: the one sentence from section 2, three screenshots (the recap with scissors, a cut result,
  the crumbled bookmark), the team and the tools.
- A 90-second demo script, shown the same way every time: the recap, one cut, the "Erased" result.
- A trailer of about 60 seconds, captured from the game.
- Builds: the Android APK and the web link, both tested.
- A short "how it was made" note: a tiny 3D kit for the cutscenes, synthesised sound, and the game
  written in Godot.

## 8. Rules for the rest of the work

- **Cut scope before cutting quality.** If time runs short, drop cut #4, then cut #2. A small mechanic that
  works every time beats a large one that sometimes breaks.
- **Every milestone ends on a passing playthrough** and a commit. No half-finished state is left in `main`.
- **Listen on a device** after M2, M4 and M7, not only on a computer.

## 9. Later (do not build before M8)

Carousel summaries rewritten by the team, more cuts, a gallery of every erased ending, achievements, extra
languages, the 3D Peter for the TV news frame.
