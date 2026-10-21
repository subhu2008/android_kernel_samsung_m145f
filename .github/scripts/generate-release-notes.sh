#!/usr/bin/env bash
#
# Generate Markdown release notes from all commits since the previous tag.
#
# Usage:
#   generate-release-notes.sh <release-tag>
#
# Environment:
#   GITHUB_SHA         Commit to generate notes for (default: HEAD)
#   GITHUB_REPOSITORY  owner/repo, used for links (optional)
#   GITHUB_SERVER_URL  GitHub server URL (default: https://github.com)

set -euo pipefail

tag="${1:?Usage: $0 <release-tag>}"
sha="${GITHUB_SHA:-HEAD}"
repo="${GITHUB_REPOSITORY:-}"
server="${GITHUB_SERVER_URL:-https://github.com}"
repo_url="${server}/${repo}"

# Find the previous tag reachable from the parent of the release commit. This
# also works when the release tag does not exist yet (manual dispatch).
previous_tag=""
if previous_tag=$(git describe --tags --abbrev=0 "${sha}^" 2>/dev/null); then
  range="${previous_tag}..${sha}"
else
  previous_tag=""
  range="${sha}"
fi

empty_tree=$(git hash-object -t tree /dev/null)
diff_base="${previous_tag:-${empty_tree}}"

commit_count=$(git rev-list --count --no-merges "${range}")
if [ "${commit_count}" -eq 0 ]; then
  echo "# ${tag}"
  echo
  echo "No commits since ${previous_tag:-the beginning of the repository}."
  exit 0
fi

file_count=$(git diff --name-only "${diff_base}" "${sha}" | wc -l | tr -d ' ')
shortstat=$(git diff --shortstat "${diff_base}" "${sha}" | sed -e 's/^ *//')

classify_commit() {
  local subject lower
  subject="$1"
  lower=$(printf '%s' "${subject}" | tr '[:upper:]' '[:lower:]')

  # Conventional Commits (https://www.conventionalcommits.org/)
  case "${lower}" in
    feat:*|feat\(*\):*|feature:*) echo "Added" ;;
    remove:*|removed:*|delete:*|deleted:*|drop:*) echo "Removed" ;;
    fix:*|fix\(*\):*|bugfix:*|hotfix:*) echo "Fixed" ;;
    perf:*|perf\(*\):*|performance:*) echo "Performance" ;;
    refactor:*|refactor\(*\):*|change:*|update:*) echo "Changed" ;;
    docs:*|doc:*|documentation:*) echo "Documentation" ;;
    build:*|build\(*\):*|ci:*|ci\(*\):*|workflow:*) echo "Build / CI" ;;
    chore:*|chore\(*\):*|test:*|tests:*|style:*) echo "Maintenance" ;;
    revert:*|revert\(*\):*) echo "Reverted" ;;
    *)
      # Fall back to leading verbs for projects without commit prefixes.
      case "${lower}" in
        add\ *|adds\ *|added\ *|implement*|introduce*|enable*|support*) echo "Added" ;;
        remove*|removes*|removed*|delete*|deletes*|deleted*|drop*|drops*|dropped*|ditch*|revert*) echo "Removed" ;;
        fix\ *|fixes\ *|fixed\ *|resolve*|correct*) echo "Fixed" ;;
        optimiz*|optimis*|speed*|performance*) echo "Performance" ;;
        update*|updates*|updated*|change*|changes*|changed*|refactor*|rename*|renames*|move*|moves*|improve*|improves*|shorten*|tweak*) echo "Changed" ;;
        doc*|docs*) echo "Documentation" ;;
        build*|ci\ *|workflow*|github*) echo "Build / CI" ;;
        chore*|test*|clean*|bump*|style*) echo "Maintenance" ;;
        *) echo "Other Changes" ;;
      esac
      ;;
  esac
}

order=(
  "Added"
  "Removed"
  "Fixed"
  "Changed"
  "Performance"
  "Documentation"
  "Build / CI"
  "Maintenance"
  "Reverted"
  "Other Changes"
)

declare -A headings=(
  ["Added"]="Added"
  ["Removed"]="Removed"
  ["Fixed"]="Fixed"
  ["Changed"]="Changed"
  ["Performance"]="Performance"
  ["Documentation"]="Documentation"
  ["Build / CI"]="Build / CI"
  ["Maintenance"]="Maintenance"
  ["Reverted"]="Reverted"
  ["Other Changes"]="Other Changes"
)

declare -A entries
for section in "${order[@]}"; do
  entries["${section}"]=""
done

commit_details=""
detail_limit=50
detail_count=0

while IFS= read -r -d '' commit &&
      IFS= read -r -d '' subject &&
      IFS= read -r -d '' body &&
      IFS= read -r -d '' author &&
      IFS= read -r -d '' date; do
  short=$(git rev-parse --short "${commit}")
  if [ -n "${repo}" ]; then
    commit_link="[${short}](${repo_url}/commit/${commit})"
  else
    commit_link="${short}"
  fi

  section=$(classify_commit "${subject}")
  entries["${section}"]+="- ${subject} (${commit_link}) — ${author}"$'\n'

  if [ "${detail_count}" -lt "${detail_limit}" ]; then
    commit_stat=$(git show --shortstat --format='' "${commit}" | sed -e '/^$/d' -e 's/^ *//')
    commit_details+="### ${subject}"$'\n\n'
    commit_details+="**Commit:** ${commit_link}  "$'\n'
    commit_details+="**Author:** ${author}  "$'\n'
    commit_details+="**Date:** ${date}"$'\n\n'
    if [ -n "${body}" ]; then
      commit_details+="${body}"$'\n\n'
    fi
    if [ -n "${commit_stat}" ]; then
      commit_details+="\`${commit_stat}\`"$'\n\n'
    fi
    detail_count=$((detail_count + 1))
  fi
done < <(git log -z --no-merges --date=short \
  --pretty=format:'%H%x00%s%x00%b%x00%an%x00%ad' "${range}")

echo "# ${tag}"
echo
if [ -n "${previous_tag}" ]; then
  echo "Changes since [\`${previous_tag}\`](${repo_url}/releases/tag/${previous_tag}): **${commit_count} commits**, ${shortstat}."
else
  echo "**${commit_count} commits**, ${shortstat}."
fi
echo

for section in "${order[@]}"; do
  [ -n "${entries[${section}]}" ] || continue
  echo "## ${headings[${section}]}"
  echo
  printf '%s' "${entries[${section}]}"
  echo
done

if [ -n "${commit_details}" ]; then
  echo "<details>"
  echo "<summary><strong>Commit details</strong></summary>"
  echo
  printf '%s' "${commit_details}"
  if [ "${commit_count}" -gt "${detail_limit}" ]; then
    echo "_The remaining $((commit_count - detail_limit)) commits are available in the full changelog below._"
    echo
  fi
  echo "</details>"
  echo
fi

max_files=200
echo "<details>"
echo "<summary><strong>Files changed</strong> (${file_count})</summary>"
echo
echo "| Change | File |"
echo "| --- | --- |"
shown_files=0
while IFS=$'\t' read -r status file extra; do
  [ -n "${status}" ] || continue
  if [ "${shown_files}" -ge "${max_files}" ]; then
    break
  fi
  case "${status}" in
    A) label="Added" ;;
    M) label="Modified" ;;
    D) label="Deleted" ;;
    R*) label="Renamed" ;;
    C*) label="Copied" ;;
    T) label="Type changed" ;;
    *) label="${status}" ;;
  esac
  if [ "${label}" = "Renamed" ] || [ "${label}" = "Copied" ]; then
    file="${file} → ${extra}"
  fi
  echo "| ${label} | \`${file}\` |"
  shown_files=$((shown_files + 1))
done < <(git diff --name-status "${diff_base}" "${sha}")
if [ "${file_count}" -gt "${max_files}" ]; then
  echo "| … | $((file_count - max_files)) more file(s) |"
fi
echo
echo "</details>"
echo

if [ -n "${previous_tag}" ]; then
  echo "**Full Changelog**: [\`${previous_tag}...${tag}\`](${repo_url}/compare/${previous_tag}...${tag})"
else
  echo "**Full Changelog**: [\`${tag}\`](${repo_url}/commits/${tag})"
fi
