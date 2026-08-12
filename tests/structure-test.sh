#!/usr/bin/env bash
# Structural assertions for the planwright plugin.
#
# No framework by design: the artifact under test is markdown and JSON, so the
# assertions are about files existing and containing required strings. Each
# check prints one line; the script exits 1 if any check failed.
set -uo pipefail
cd "$(dirname "$0")/.."

fails=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

has_file() {
  if [ -f "$1" ]; then ok "exists: $1"; else fail "missing: $1"; fi
}
has_text() {
  if [ -f "$1" ] && grep -qF -- "$2" "$1"; then ok "$1 has: $2"
  else fail "$1 lacks: $2"; fi
}
lacks_text() {
  if [ -f "$1" ] && grep -qF -- "$2" "$1"; then fail "$1 must not contain: $2"
  else ok "$1 clean of: $2"; fi
}

echo "== manifests =="
has_file .claude-plugin/plugin.json
has_file .claude-plugin/marketplace.json
has_text .claude-plugin/plugin.json '"name": "planwright"'
has_text .claude-plugin/plugin.json '"license": "MIT"'
has_text .claude-plugin/marketplace.json '"name": "planwright-marketplace"'
has_text .claude-plugin/marketplace.json '"source": "./"'

# Deliberately not a pinned literal. Pinning the version would break on every
# release and assert only that someone remembered to edit this file. The
# invariant worth holding is that the two manifests AGREE: Claude Code compares
# the marketplace entry's version to decide an update exists, so bumping
# plugin.json alone ships a release nobody can install.
version_report=$(python3 - <<'PY' 2>&1
import json, re
try:
    plugin = json.load(open(".claude-plugin/plugin.json"))
    market = json.load(open(".claude-plugin/marketplace.json"))
except Exception as exc:
    print("UNPARSEABLE %s" % exc)
    raise SystemExit(0)
pv = plugin.get("version")
entries = [p for p in market.get("plugins", []) if p.get("name") == plugin.get("name")]
if not entries:
    print("NO-ENTRY marketplace.json lists no plugin named %r" % plugin.get("name"))
elif not isinstance(pv, str) or not re.fullmatch(r"\d+\.\d+\.\d+", pv):
    print("BAD-SEMVER plugin.json version %r" % pv)
elif entries[0].get("version") != pv:
    print("MISMATCH plugin.json %s != marketplace entry %s" % (pv, entries[0].get("version")))
else:
    print("OK %s" % pv)
PY
)
case "$version_report" in
  "OK "*) ok "manifest versions agree (${version_report#OK })" ;;
  *)      fail "manifest versions: $version_report" ;;
esac

echo "== license =="
has_file LICENSE
has_text LICENSE 'MIT License'
has_text LICENSE 'Copyright (c) 2026 sshah'
has_text LICENSE 'Copyright (c) 2025 Jesse Vincent'
has_text LICENSE 'obra/superpowers'

echo "== config template =="
has_file templates/planwright.yml
config_report=$(python3 - <<'PY' 2>&1
import yaml
required = [
    "backlog.epic_path", "backlog.fallback", "specs", "plans",
    "personas", "epics", "layers",
    "definition_of_done.unit.command",
    "definition_of_done.integration.command",
    "definition_of_done.integration.location",
    "definition_of_done.smoke.command",
    "definition_of_done.smoke.file",
    "definition_of_done.api_docs.file",
    "definition_of_done.security.surfaces",
    "definition_of_done.security.command",
]
# definition_of_done.backlog_status is deliberately absent: requirement #6 is
# unconditional, so a key for it would be a toggle that toggles nothing.
forbidden = [
    "definition_of_done.backlog_status",
]
try:
    doc = yaml.safe_load(open("templates/planwright.yml"))
except Exception as exc:
    print("UNPARSEABLE %s" % exc)
    raise SystemExit(0)
def resolve(path):
    node = doc
    for part in path.split("."):
        if isinstance(node, dict) and part in node:
            node = node[part]
        else:
            return False
    return True

missing = [p for p in required if not resolve(p)]
present = [p for p in forbidden if resolve(p)]
if missing:
    print("MISSING " + " ".join(missing))
elif present:
    print("DEAD-KEY " + " ".join(present))
else:
    print("OK")
PY
)
if [ "$config_report" = "OK" ]; then
  ok "templates/planwright.yml parses, has every documented key, and no dead ones"
else
  fail "templates/planwright.yml: $config_report"
fi

for surface in tenant-isolation authorization user-input file-handling secrets outbound-fetch dependency; do
  has_text templates/planwright.yml "$surface"
done

echo "== story-backlog skill =="
has_file skills/story-backlog/SKILL.md
has_text skills/story-backlog/SKILL.md 'name: story-backlog'
has_text skills/story-backlog/SKILL.md 'US-<epic>.<n>'
has_text skills/story-backlog/SKILL.md '.planwright.yml'
has_text skills/story-backlog/SKILL.md '⬜ Not started'
has_text skills/story-backlog/SKILL.md '🟡 Partial'
has_text skills/story-backlog/SKILL.md '✅ Done'
has_text skills/story-backlog/SKILL.md 'Promoting an epic'
has_text skills/story-backlog/SKILL.md 'evidence note'
has_text skills/story-backlog/SKILL.md 'docs/user-stories.md'
has_text skills/story-backlog/SKILL.md '## Stories'

echo "== story-plans skill =="
has_file skills/story-plans/SKILL.md
has_text skills/story-plans/SKILL.md 'name: story-plans'
has_text skills/story-plans/SKILL.md 'obra/superpowers'
has_text skills/story-plans/SKILL.md 'Jesse Vincent'
has_text skills/story-plans/SKILL.md 'not a tracked fork'
has_text skills/story-plans/SKILL.md 'Story Map'
has_text skills/story-plans/SKILL.md '[US-8.22·AC1]'
has_text skills/story-plans/SKILL.md 'No Placeholders'
has_text skills/story-plans/SKILL.md 'Definition of Done'
has_text skills/story-plans/SKILL.md 'no surface touched'
has_text skills/story-plans/SKILL.md 'not configured'
has_text skills/story-plans/SKILL.md 'Story coverage'
has_text skills/story-plans/SKILL.md 'subagent-driven-development'
has_text skills/story-plans/SKILL.md 'is available'
for surface in tenant-isolation authorization user-input file-handling secrets outbound-fetch dependency; do
  has_text skills/story-plans/SKILL.md "$surface"
done

echo "== readme =="
has_file README.md
has_text README.md '/plugin marketplace add sshah-tripcart/planwright'
has_text README.md '.planwright.yml'
has_text README.md 'story-backlog'
has_text README.md 'story-plans'
has_text README.md 'obra/superpowers'
has_text README.md '[US-8.22·AC1]'
lacks_text README.md 'TODO'
lacks_text README.md 'TBD'
lacks_text README.md 'FIXME'

echo
if [ "$fails" -eq 0 ]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
exit $((fails > 0))
