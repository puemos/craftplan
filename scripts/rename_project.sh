#!/usr/bin/env bash
set -euo pipefail

# Rename an Elixir/Phoenix project from Craftday -> Craftplan
# - Text replacements across tracked files
# - Directory/file moves (lib/test, *_web)
# - Optional: update git remote, re-create DBs
#
# Usage:
#   scripts/rename_project.sh --dry-run      # preview
#   scripts/rename_project.sh --apply        # perform changes
#   scripts/rename_project.sh --apply --update-remote
#   scripts/rename_project.sh --apply --reset-dbs   # drop/create/migrate new DBs
#   scripts/rename_project.sh --help

OLD_CAMEL=${OLD_CAMEL:-"Craftday"}
NEW_CAMEL=${NEW_CAMEL:-"Craftplan"}
OLD_SNAKE=${OLD_SNAKE:-"craftday"}
NEW_SNAKE=${NEW_SNAKE:-"craftplan"}
OLD_UPPER=${OLD_UPPER:-"CRAFTDAY"}
NEW_UPPER=${NEW_UPPER:-"CRAFTPLAN"}

REMOTE_URL=${REMOTE_URL:-"https://github.com/puemos/craftplan.git"}

MODE="dry-run"
UPDATE_REMOTE=false
RESET_DBS=false

die() { echo "Error: $*" >&2; exit 1; }

usage() {
  cat <<EOF
Rename project ${OLD_CAMEL} -> ${NEW_CAMEL}

Options:
  --dry-run            Show planned changes (default)
  --apply              Apply changes
  --update-remote      Set origin to: ${REMOTE_URL}
  --reset-dbs          Drop/create/migrate dev & test databases after rename
  --help               Show this help

Env overrides:
  OLD_CAMEL, NEW_CAMEL, OLD_SNAKE, NEW_SNAKE, OLD_UPPER, NEW_UPPER, REMOTE_URL
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run" ; shift ;;
    --apply) MODE="apply" ; shift ;;
    --update-remote) UPDATE_REMOTE=true ; shift ;;
    --reset-dbs) RESET_DBS=true ; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

# Sanity: in a git repo and clean worktree
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Run from within a git repository"

# Files that potentially contain occurrences (rg may be missing; handle gracefully)
MATCH_COUNT=$(rg -l -S "${OLD_CAMEL}|${OLD_SNAKE}|${OLD_UPPER}" --hidden \
  --glob '!_build/**' --glob '!deps/**' --glob '!cover/**' --glob '!.elixir_ls/**' 2>/dev/null | wc -l | tr -d ' ' || true)

echo "== Rename preview: ${OLD_CAMEL}/${OLD_SNAKE}/${OLD_UPPER} -> ${NEW_CAMEL}/${NEW_SNAKE}/${NEW_UPPER}"
echo "Files with matches: ${MATCH_COUNT}"

count() { rg -n -S "$1" --hidden --glob '!_build/**' --glob '!deps/**' --glob '!cover/**' --glob '!.elixir_ls/**' | wc -l | tr -d ' '; }
echo "  ${OLD_CAMEL} occurrences: $(count "${OLD_CAMEL}")"
echo "  ${OLD_CAMEL}Web occurrences: $(count "${OLD_CAMEL}Web")"
echo "  :${OLD_SNAKE} occurrences: $(count ":${OLD_SNAKE}")"
echo "  ${OLD_SNAKE} occurrences: $(count "${OLD_SNAKE}")"
echo "  ${OLD_UPPER} occurrences: $(count "${OLD_UPPER}")"

# Planned path moves
declare -a MOVES=()
[[ -d "lib/${OLD_SNAKE}" ]] && MOVES+=("lib/${OLD_SNAKE} -> lib/${NEW_SNAKE}")
[[ -d "lib/${OLD_SNAKE}_web" ]] && MOVES+=("lib/${OLD_SNAKE}_web -> lib/${NEW_SNAKE}_web")
[[ -d "test/${OLD_SNAKE}" ]] && MOVES+=("test/${OLD_SNAKE} -> test/${NEW_SNAKE}")
[[ -d "test/${OLD_SNAKE}_web" ]] && MOVES+=("test/${OLD_SNAKE}_web -> test/${NEW_SNAKE}_web")

echo "Planned moves (${#MOVES[@]}):"
for m in "${MOVES[@]}"; do echo "  git mv ${m}"; done

if [[ "${MODE}" == "dry-run" ]]; then
  echo "-- Dry-run complete. Re-run with --apply to perform changes."
  exit 0
fi

echo "== Applying text replacements"

# Use perl for safe in-place multi-platform edits
replace_in_file() {
  local pattern="$1"; shift
  local repl="$1"; shift
  # -0777 handles multiline, -i edits in-place
  perl -0777 -i -pe "s/${pattern}/${repl}/g" "$@"
}

# Apply targeted replacements in matched files first
# Apply replacements across all tracked files; perl will no-op where no matches
git ls-files -z \
  ':!:deps/**' ':!:_build/**' ':!:cover/**' ':!:.elixir_ls/**' ':!:assets/node_modules/**' \
  | xargs -0 perl -0777 -i -pe "s/${OLD_CAMEL}Web/${NEW_CAMEL}Web/g"
git ls-files -z \
  ':!:deps/**' ':!:_build/**' ':!:cover/**' ':!:.elixir_ls/**' ':!:assets/node_modules/**' \
  | xargs -0 perl -0777 -i -pe "s/${OLD_CAMEL}\\.MixProject/${NEW_CAMEL}.MixProject/g"
git ls-files -z \
  ':!:deps/**' ':!:_build/**' ':!:cover/**' ':!:.elixir_ls/**' ':!:assets/node_modules/**' \
  | xargs -0 perl -0777 -i -pe "s/${OLD_CAMEL}/${NEW_CAMEL}/g"
git ls-files -z \
  ':!:deps/**' ':!:_build/**' ':!:cover/**' ':!:.elixir_ls/**' ':!:assets/node_modules/**' \
  | xargs -0 perl -0777 -i -pe "s/:${OLD_SNAKE}/:${NEW_SNAKE}/g"
git ls-files -z \
  ':!:deps/**' ':!:_build/**' ':!:cover/**' ':!:.elixir_ls/**' ':!:assets/node_modules/**' \
  | xargs -0 perl -0777 -i -pe "s/${OLD_SNAKE}/${NEW_SNAKE}/g"
git ls-files -z \
  ':!:deps/**' ':!:_build/**' ':!:cover/**' ':!:.elixir_ls/**' ':!:assets/node_modules/**' \
  | xargs -0 perl -0777 -i -pe "s/${OLD_UPPER}/${NEW_UPPER}/g"

echo "== Renaming directories/files"
if [[ -d "lib/${OLD_SNAKE}" ]]; then git mv "lib/${OLD_SNAKE}" "lib/${NEW_SNAKE}"; fi
if [[ -d "lib/${OLD_SNAKE}_web" ]]; then git mv "lib/${OLD_SNAKE}_web" "lib/${NEW_SNAKE}_web"; fi
if [[ -d "test/${OLD_SNAKE}" ]]; then git mv "test/${OLD_SNAKE}" "test/${NEW_SNAKE}"; fi
if [[ -d "test/${OLD_SNAKE}_web" ]]; then git mv "test/${OLD_SNAKE}_web" "test/${NEW_SNAKE}_web"; fi

echo "== Post-replace adjustments"
# If mix aliases reference esbuild/tailwind profiles using the old snake, keep them consistent
# (We rely on the above replacements handling this in mix.exs)

if ${UPDATE_REMOTE}; then
  echo "== Updating git remote origin to ${REMOTE_URL}"
  git remote set-url origin "${REMOTE_URL}"
fi

if ${RESET_DBS}; then
  echo "== Resetting dev & test databases under new names"
  MIX_ENV=dev mix ecto.drop || true
  MIX_ENV=test mix ecto.drop || true
  MIX_ENV=dev mix ash.setup || MIX_ENV=dev mix ecto.setup
  MIX_ENV=test mix ecto.create
fi

echo "== Done. Next suggested steps:"
echo "  - mix deps.get && mix compile"
echo "  - mix test"
echo "  - Review remaining occurrences: rg -n -S '${OLD_CAMEL}|${OLD_SNAKE}|${OLD_UPPER}'"
echo "  - Optionally rename the folder to '${NEW_SNAKE}' and restart your shell session"
