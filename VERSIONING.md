# Versioning

SANGA uses [Semantic Versioning 2.0.0](https://semver.org): `vMAJOR.MINOR.PATCH`, as annotated git
tags on `main`. Every change that is pushed gets a tag.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org), and the label of
each commit decides the version bump. `tools/next_version.sh` applies these rules and prints the next
version.

## What counts as the "public API" of a game

SemVer is defined against a public API. For SANGA that is what a player or a save file depends on:

1. **Save files.** A save made by one version can be loaded by later versions.
2. **Story progress and outcomes.** The stories, choices, endings and realities a save has recorded
   still exist and mean the same thing.
3. **Player-facing features and settings.** Menus, controls, settings and the stored `settings.cfg`.
4. **Platform requirements.** Godot version, renderer, and the minimum Android or desktop version
   needed to run the game.

## Choosing the label

Read the questions in order. The first "yes" is the label.

| # | Question | Label | Commit type |
|---|----------|-------|-------------|
| 1 | Does it break any of the four points above? Old saves fail to load or lose progress, a story, choice, ending or setting is removed or changes meaning, or platform requirements go up. | **MAJOR** | `feat!:`, `fix!:` … or a `BREAKING CHANGE:` footer |
| 2 | Does it add something the player can do, see or choose that was not there before, in a backward-compatible way? New features, scenes, stories, choices, endings or settings. Also deprecating something without removing it yet. | **MINOR** | `feat:` |
| 3 | Anything else: bug fixes, visual or text tweaks, balancing, performance, refactors, docs, tests, build and tooling. | **PATCH** | `fix:` `style:` `perf:` `refactor:` `docs:` `test:` `build:` `ci:` `chore:` `revert:` |

Notes for edge cases:

- **Adding fields to the save format** is MINOR or PATCH, not MAJOR, as long as older saves still load
  and get sensible defaults (as `GameState.read_slot` does). **Removing or renaming a field, or
  refusing older saves**, is MAJOR.
- **Changing what an existing feature does by default** (for example the default volume) is PATCH if it
  is a fix or tweak. It is MAJOR if players lose something they relied on.
- **Look and feel changes** (colours, fonts, layout, art swaps) are PATCH, unless they add a new
  feature the player can use, which is MINOR.
- **Debug-only features** (things gated by `OS.is_debug_build()`) never ship to players, so they are
  PATCH.

## Several changes in one release

When one tag covers several commits, the bump is the **highest label among them**, applied **once**:

| Labels in the release | Bump | Example from `v1.4.2` |
|---|---|---|
| PATCH only | PATCH | `v1.4.3` |
| MINOR + PATCH | MINOR | `v1.5.0` |
| MINOR + MINOR | MINOR (once) | `v1.5.0` |
| MAJOR + anything | MAJOR | `v2.0.0` |
| MAJOR + MINOR + PATCH | MAJOR | `v2.0.0` |

Bumping resets the lower numbers: a MINOR bump sets PATCH to 0, and a MAJOR bump sets MINOR and
PATCH to 0. Three features never make `v1.7.0` out of `v1.4.2`: a release moves up by one step.

## Before 1.0.0

While the game is in development (`0.y.z`), the public API is not considered stable. Following
SemVer item 4:

- A MAJOR-level change bumps **MINOR** (`0.3.1` becomes `0.4.0`). The tag message must say
  `BREAKING:` and describe what breaks, for example "saves from v0.3.x cannot be loaded".
- MINOR and PATCH behave as normal.

Tag `v1.0.0` for the first public release (for example the first store build). From then on the rules
above apply exactly.

## Making a release

```bash
tools/next_version.sh            # evaluate the commits since the last tag
git tag -a vX.Y.Z -m "vX.Y.Z — summary"
git push origin main --follow-tags
```

The script prints each commit's label and the reason, the combined bump and the next version. It
stops if a commit message does not follow Conventional Commits, so the label is never guessed. Use
`--release-as X.Y.Z` to choose the version yourself, for example for `1.0.0`.
