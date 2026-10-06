#!/usr/bin/env bash
# Works out the next version from the commits since the last tag, following VERSIONING.md.
#
#   tools/next_version.sh                       commits since the latest vX.Y.Z tag
#   tools/next_version.sh --from v0.2.0         commits since a given tag
#   tools/next_version.sh --release-as 1.0.0    use this version, after checking the commits
#
# Each commit is labelled MAJOR, MINOR or PATCH from its Conventional Commits header. A release of
# several commits takes the highest label, once. Before 1.0.0 a MAJOR-level change bumps MINOR.
# Exits with 1 when there is nothing to release, and 2 when a commit cannot be labelled.
set -euo pipefail

from=""
release_as=""
while [ $# -gt 0 ]; do
	case "$1" in
		--from) from="$2"; shift 2 ;;
		--release-as) release_as="${2#v}"; shift 2 ;;
		-h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $1" >&2; exit 2 ;;
	esac
done

if [ -z "$from" ]; then
	from=$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true)
fi
if [ -z "$from" ]; then
	echo "No vX.Y.Z tag found. Tag the first release by hand, for example v0.1.0." >&2
	exit 2
fi
if ! [[ "$from" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
	echo "Not a vX.Y.Z tag: $from" >&2
	exit 2
fi
major=${BASH_REMATCH[1]}; minor=${BASH_REMATCH[2]}; patch=${BASH_REMATCH[3]}

commits=$(git rev-list --reverse --no-merges "$from..HEAD")
if [ -z "$commits" ]; then
	echo "Nothing to release: no commits since $from."
	exit 1
fi

# 0 = PATCH, 1 = MINOR, 2 = MAJOR.
names=(PATCH MINOR MAJOR)
highest=0
unlabelled=0
echo "Commits since $from:"
for sha in $commits; do
	subject=$(git log -1 --format=%s "$sha")
	body=$(git log -1 --format=%b "$sha")
	short=$(git log -1 --format=%h "$sha")
	if ! [[ "$subject" =~ ^([a-z]+)(\([^\)]+\))?(!)?:\ .+ ]]; then
		printf '  %-7s %s  %s\n' "?" "$short" "$subject"
		printf '          not a Conventional Commits header (type(scope): summary)\n'
		unlabelled=1
		continue
	fi
	type=${BASH_REMATCH[1]}; bang=${BASH_REMATCH[3]}
	if [ -n "$bang" ] || grep -qE '^BREAKING[ -]CHANGE: ' <<<"$body"; then
		level=2
		if [ -n "$bang" ]; then reason="breaking change (! in header)"; else reason="breaking change (BREAKING CHANGE footer)"; fi
	else
		case "$type" in
			feat) level=1; reason="new backward-compatible feature" ;;
			fix|perf|style|refactor|docs|test|build|ci|chore|revert)
				level=0; reason="$type: no new feature, nothing breaks" ;;
			*)
				printf '  %-7s %s  %s\n' "?" "$short" "$subject"
				printf '          unknown type "%s"\n' "$type"
				unlabelled=1
				continue ;;
		esac
	fi
	[ "$level" -gt "$highest" ] && highest=$level
	printf '  %-7s %s  %s\n' "${names[$level]}" "$short" "$subject"
	printf '          %s\n' "$reason"
done

if [ "$unlabelled" -ne 0 ]; then
	echo
	echo "Some commits cannot be labelled. Reword them (only if they are not pushed yet), or choose the"
	echo "version yourself with --release-as after checking them against VERSIONING.md."
	[ -z "$release_as" ] && exit 2
fi

bump=$highest
note=""
if [ "$highest" -eq 2 ] && [ "$major" -eq 0 ]; then
	bump=1
	note=" (before 1.0.0 a breaking change bumps MINOR; say BREAKING: in the tag message)"
fi
case "$bump" in
	2) next="$((major + 1)).0.0" ;;
	1) next="$major.$((minor + 1)).0" ;;
	0) next="$major.$minor.$((patch + 1))" ;;
esac

echo
echo "Highest label: ${names[$highest]}$note"
if [ -n "$release_as" ]; then
	echo "Evaluated:     v$next"
	echo "Releasing as:  v$release_as (chosen with --release-as)"
	next="$release_as"
else
	echo "Next version:  v$next"
fi
echo
echo "  git tag -a v$next -m \"v$next — <summary>\""
echo "  git push origin main --follow-tags"
