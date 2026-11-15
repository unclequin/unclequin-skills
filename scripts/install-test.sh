#!/usr/bin/env bash
# Install every skill the two ways the README documents, into throwaway
# directories, and check that each install yields exactly that one skill.
#
# Usage: scripts/install-test.sh [source]
#   source  what to install from: a GitHub "owner/repo" (default, the
#           published repo) or a path to a local checkout.
#
# Silent on success. On failure, names the command that failed and exits 1.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
source=${1:-unclequin/unclequin-skills}
manifest="$root/.claude-plugin/marketplace.json"
marketplace=$(jq -r .name "$manifest")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail() {
  echo "install-test: $1" >&2
  exit 1
}

# Run a command quietly; on failure show its output and name it.
run() {
  local log="$work/log"
  if ! "$@" >"$log" 2>&1; then
    cat "$log" >&2
    fail "command failed: $*"
  fi
}

# A local path must be absolute, because the installs run from other folders.
if [ -d "$source" ]; then
  source=$(cd "$source" && pwd)
fi

# Plugin install: one marketplace, then each plugin by name.
export CLAUDE_CONFIG_DIR="$work/claude-config"
mkdir -p "$CLAUDE_CONFIG_DIR"
cd "$work"
run claude plugin marketplace add "$source"
jq -r '.plugins[].name' "$manifest" | while read -r skill; do
  run claude plugin install "$skill@$marketplace"
  details=$(claude plugin details "$skill@$marketplace" 2>&1) ||
    fail "command failed: claude plugin details $skill@$marketplace"
  # The inventory line reads "Skills (1)  <name>" when the plugin has one skill.
  echo "$details" | grep -Eq "^ *Skills \(1\) +$skill\$" ||
    fail "plugin $skill should load exactly the skill $skill, but its inventory is:
$details"
done
unset CLAUDE_CONFIG_DIR

# npx install: a fresh home per skill, so the count of installed skills is exact.
jq -r '.plugins[].name' "$manifest" | while read -r skill; do
  home="$work/home-$skill"
  mkdir -p "$home"
  # -y answers the CLI's prompts; the README command is otherwise unchanged.
  (cd "$home" && HOME="$home" run npx --yes skills add "$source" --skill "$skill" -a claude-code -g -y)
  installed=$(ls "$home/.claude/skills" 2>/dev/null | tr '\n' ' ')
  [ "$installed" = "$skill " ] ||
    fail "npx skills add --skill $skill should install only $skill, but ~/.claude/skills holds: ${installed:-nothing}"
  [ -f "$home/.claude/skills/$skill/SKILL.md" ] ||
    fail "npx skills add --skill $skill left no SKILL.md in ~/.claude/skills/$skill"
done
