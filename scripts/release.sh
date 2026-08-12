#!/usr/bin/env bash
# Release planwright: bump every version position, verify, tag, publish.
#
# The version lives in THREE places — plugin.json's `version`, marketplace.json's
# `metadata.version`, and the plugin entry's `version` — and a bump that moves
# some but not all of them is the failure this script exists to prevent. It has
# happened twice: once shipping a release whose metadata contradicted its entry,
# and once leaving a tag that pointed at a partially-bumped commit.
#
# The script is deliberately all-or-nothing. It runs every precondition check
# BEFORE touching a file, and reverts the bump if verification fails afterwards,
# because a script that can half-finish would recreate the very problem it is
# meant to solve.
#
# Usage:
#   scripts/release.sh 0.1.2                 full release: bump, verify, commit, tag, push, publish
#   scripts/release.sh 0.1.2 --dry-run       print the plan, change nothing
#   scripts/release.sh 0.1.2 --no-release    bump, verify, commit, tag, push — skip the GitHub release
#   scripts/release.sh 0.1.2 --notes-file X  use X as the release notes instead of generating them
set -euo pipefail
cd "$(dirname "$0")/.."

PLUGIN=.claude-plugin/plugin.json
MARKET=.claude-plugin/marketplace.json
BRANCH=main

die()  { printf '\nrelease: %s\n' "$1" >&2; exit 1; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
note() { printf '    %s\n' "$1"; }

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
version=${1:-}
[ -n "$version" ] || die "usage: scripts/release.sh <version> [--dry-run] [--no-release] [--notes-file FILE]"
shift

dry_run=0
do_release=1
notes_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)    dry_run=1 ;;
    --no-release) do_release=0 ;;
    --notes-file) shift; notes_file=${1:-}; [ -n "$notes_file" ] || die "--notes-file needs a path" ;;
    *)            die "unknown option: $1" ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Preconditions — every one of these runs before anything is modified
# ---------------------------------------------------------------------------
step "Checking preconditions"

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || die "version must be X.Y.Z (semver, no 'v' prefix, no suffix); got '$version'"

current=$(python3 -c "import json;print(json.load(open('$PLUGIN'))['version'])")
note "current version: $current"
note "new version:     $version"

[ "$version" != "$current" ] || die "version $version is already the current version"
# sort -V puts the greater version last; if that is not the new one, this is a downgrade.
[ "$(printf '%s\n%s\n' "$current" "$version" | sort -V | tail -1)" = "$version" ] \
  || die "version $version is lower than the current $current — releases only move forward"

on=$(git rev-parse --abbrev-ref HEAD)
[ "$on" = "$BRANCH" ] || die "on branch '$on', expected '$BRANCH'"

# Tracked changes only. Untracked files cannot reach the release commit — it adds
# just the two manifests — and blocking on them would reject a perfectly good
# release for an unrelated scratch file, or for the notes file being passed in.
[ -z "$(git status --porcelain --untracked-files=no)" ] \
  || die "tracked files have uncommitted changes — commit or stash first, so the release commit contains only the bump"

git rev-parse "v$version" >/dev/null 2>&1 && die "tag v$version already exists locally"
if git ls-remote --exit-code --tags origin "refs/tags/v$version" >/dev/null 2>&1; then
  die "tag v$version already exists on origin"
fi

git fetch -q origin "$BRANCH"
[ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$BRANCH")" ] \
  || die "local $BRANCH and origin/$BRANCH differ — push or pull first, so the tag matches what is published"

if [ "$do_release" -eq 1 ]; then
  command -v gh >/dev/null 2>&1 || die "gh is not installed (or pass --no-release)"
  gh auth status >/dev/null 2>&1 || die "gh is not authenticated (or pass --no-release)"
fi
[ -z "$notes_file" ] || [ -f "$notes_file" ] || die "notes file not found: $notes_file"

note "all preconditions passed"

if [ "$dry_run" -eq 1 ]; then
  step "Dry run — nothing will be changed"
  note "would set $version in: $PLUGIN (version), $MARKET (metadata.version, plugins[].version)"
  note "would run: bash tests/structure-test.sh"
  note "would run: claude plugin validate --strict on both manifests"
  note "would commit: 'chore: release $version'"
  note "would tag:    v$version"
  note "would push:   $BRANCH and v$version to origin"
  [ "$do_release" -eq 1 ] \
    && note "would create GitHub release v$version ($([ -n "$notes_file" ] && echo "notes from $notes_file" || echo "generated notes"))" \
    || note "would NOT create a GitHub release (--no-release)"
  exit 0
fi

# ---------------------------------------------------------------------------
# Bump — all three positions, or none
# ---------------------------------------------------------------------------
step "Bumping all three version positions"

revert() { git checkout -- "$PLUGIN" "$MARKET" 2>/dev/null || true; }

python3 - "$version" <<'PY'
import json, sys
version = sys.argv[1]
PLUGIN, MARKET = ".claude-plugin/plugin.json", ".claude-plugin/marketplace.json"

plugin = json.load(open(PLUGIN))
plugin["version"] = version
json.dump(plugin, open(PLUGIN, "w"), indent=2, ensure_ascii=False)
open(PLUGIN, "a").write("\n")

market = json.load(open(MARKET))
market["metadata"]["version"] = version
hits = [p for p in market["plugins"] if p.get("name") == plugin["name"]]
if not hits:
    raise SystemExit("marketplace.json has no plugin entry named %r" % plugin["name"])
for entry in hits:
    entry["version"] = version
json.dump(market, open(MARKET, "w"), indent=2, ensure_ascii=False)
open(MARKET, "a").write("\n")

print("    plugin.json version           -> %s" % version)
print("    marketplace metadata.version  -> %s" % version)
print("    marketplace plugin entry      -> %s (%d entry)" % (version, len(hits)))
PY

# ---------------------------------------------------------------------------
# Verify — the structure suite is what actually enforces three-way agreement
# ---------------------------------------------------------------------------
step "Verifying"

if ! bash tests/structure-test.sh > /tmp/planwright-release-tests.log 2>&1; then
  revert
  printf '\n'; tail -20 /tmp/planwright-release-tests.log
  die "structure tests failed — bump reverted, nothing committed"
fi
note "$(grep -E 'all checks passed|manifest versions' /tmp/planwright-release-tests.log | tr '\n' ' ' | sed 's/  */ /g')"

for manifest in "$PLUGIN" "$MARKET"; do
  if ! claude plugin validate "$manifest" --strict >/tmp/planwright-release-validate.log 2>&1; then
    revert
    printf '\n'; cat /tmp/planwright-release-validate.log
    die "claude plugin validate --strict failed on $manifest — bump reverted, nothing committed"
  fi
done
note "both manifests validate --strict"

# ---------------------------------------------------------------------------
# Commit, tag, push
# ---------------------------------------------------------------------------
step "Committing and tagging"

git add "$PLUGIN" "$MARKET"
git commit -q -m "chore: release $version" -m "Bumps all three version positions together: plugin.json, marketplace metadata.version, and the marketplace plugin entry."
git tag -a "v$version" -m "planwright $version"
note "commit $(git rev-parse --short HEAD), tag v$version"

step "Pushing to origin"
git push -q origin "$BRANCH"
git push -q origin "v$version"
note "pushed $BRANCH and v$version"

# ---------------------------------------------------------------------------
# GitHub release
# ---------------------------------------------------------------------------
if [ "$do_release" -eq 1 ]; then
  step "Creating GitHub release"
  if [ -n "$notes_file" ]; then
    gh release create "v$version" --title "v$version" --notes-file "$notes_file"
  else
    gh release create "v$version" --title "v$version" --generate-notes
  fi
else
  step "Skipping GitHub release (--no-release)"
  note "create it later with: gh release create v$version --title v$version --generate-notes"
fi

step "Released $version"
note "Installs are unaffected by the release object: Claude Code clones the default"
note "branch and reads marketplace.json. The tag is history for humans."
