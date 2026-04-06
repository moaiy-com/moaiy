#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release/setup_tag_ruleset.sh [options]

Options:
  --repo <owner/name>     Repository (default: inferred from git remote)
  --enforcement <state>   active|evaluate|disabled (default: active)
  --integration-actor-id <id>
                           Optional GitHub App actor id to bypass creation rule
  --dry-run               Print payload without applying
  -h, --help              Show help

Description:
  Creates or updates a tag ruleset for refs/tags/v* that:
  - blocks deletion
  - blocks non-fast-forward updates (rewrite)
  - blocks creation unless bypassed
  - allows bypass for repository/organization admins
  - optionally adds integration bypass when --integration-actor-id is provided
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO=""
ENFORCEMENT="active"
INTEGRATION_ACTOR_ID=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --enforcement)
      ENFORCEMENT="${2:-}"
      shift 2
      ;;
    --integration-actor-id)
      INTEGRATION_ACTOR_ID="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option '$1'"
      usage
      exit 1
      ;;
  esac
done

if [[ "$ENFORCEMENT" != "active" && "$ENFORCEMENT" != "evaluate" && "$ENFORCEMENT" != "disabled" ]]; then
  echo "ERROR: --enforcement must be active, evaluate, or disabled"
  exit 1
fi

if [[ -z "$REPO" ]]; then
  remote_url="$(git -C "$ROOT_DIR" config --get remote.origin.url)"
  if [[ "$remote_url" =~ github.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
    REPO="${BASH_REMATCH[1]}"
  else
    echo "ERROR: unable to infer repository from origin remote"
    exit 1
  fi
fi

payload_file="$(mktemp /tmp/moaiy-tag-ruleset.XXXXXX.json)"
trap 'rm -f "$payload_file"' EXIT

if [[ -n "$INTEGRATION_ACTOR_ID" && ! "$INTEGRATION_ACTOR_ID" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --integration-actor-id must be a number"
  exit 1
fi

jq -n \
  --arg enforcement "$ENFORCEMENT" \
  --arg integration_actor_id "$INTEGRATION_ACTOR_ID" \
  '{
    name: "Protect release tags (v*)",
    target: "tag",
    enforcement: $enforcement,
    conditions: {
      ref_name: {
        include: ["refs/tags/v*"],
        exclude: []
      }
    },
    rules: [
      { type: "creation" },
      { type: "deletion" },
      { type: "non_fast_forward" }
    ],
    bypass_actors: (
      [
        { actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "always" },
        { actor_id: 1, actor_type: "OrganizationAdmin", bypass_mode: "always" }
      ] +
      (if $integration_actor_id == "" then
        []
      else
        [{ actor_id: ($integration_actor_id | tonumber), actor_type: "Integration", bypass_mode: "always" }]
      end)
    )
  }' > "$payload_file"

echo "Repository: $REPO"
echo "Enforcement: $ENFORCEMENT"
echo "Ruleset payload:"
cat "$payload_file"

if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run enabled, no API call made."
  exit 0
fi

existing_id="$(
  gh api "repos/$REPO/rulesets" \
    --jq '.[] | select(.name=="Protect release tags (v*)") | .id' \
    | head -n 1 || true
)"

if [[ -n "$existing_id" ]]; then
  gh api --method PUT "repos/$REPO/rulesets/$existing_id" --input "$payload_file" >/dev/null
  echo "Updated ruleset id: $existing_id"
else
  new_id="$(
    gh api --method POST "repos/$REPO/rulesets" --input "$payload_file" --jq '.id'
  )"
  echo "Created ruleset id: $new_id"
fi
