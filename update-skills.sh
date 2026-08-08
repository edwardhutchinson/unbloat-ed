#!/usr/bin/env bash
#
# Bump the upstream skills pin in skills.lock.
#
#   ./update-skills.sh              move to the latest upstream release tag
#   ./update-skills.sh v1.2.3       move to a specific tag, branch or commit
#   ./update-skills.sh main         track the tip of main
#   ./update-skills.sh --status     show the current pin and what's newer
#   ./update-skills.sh --list       list every skill available at the current pin

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/lib/skills-lib.sh"

CURRENT_COMMIT=$(lock_get commit)
CURRENT_REF=$(lock_get ref)

# Make sure the cache exists, then pull down everything so we can compare.
# install-*.sh fetches shallowly to stay cheap, so deepen before diffing —
# otherwise the commit log between two pins comes out truncated.
sync_upstream >/dev/null
echo "⬇️  Fetching upstream refs..."
if [ -f "$CACHE_DIR/.git/shallow" ]; then
    git -C "$CACHE_DIR" fetch --quiet --unshallow --tags origin 2>/dev/null || true
fi
git -C "$CACHE_DIR" fetch --quiet --tags --force origin '+refs/heads/*:refs/remotes/origin/*'

# latest_tag — newest vN.N.N tag by version order
latest_tag() {
    git -C "$CACHE_DIR" tag --list 'v[0-9]*' --sort=-v:refname | head -1
}

case "${1:---latest}" in
    --list)
        echo "📋 Skills available at $CURRENT_REF:"
        for bucket in "${BUCKETS[@]}"; do
            [ -d "$CACHE_DIR/skills/$bucket" ] || continue
            echo
            echo "  --- $bucket ---"
            find "$CACHE_DIR/skills/$bucket" -mindepth 1 -maxdepth 1 -type d \
                -exec basename {} \; | sort | sed 's/^/  /'
        done
        exit 0
        ;;
    --status)
        echo "📌 Current pin: $CURRENT_REF ($(printf '%.12s' "$CURRENT_COMMIT"))"
        newest=$(latest_tag)
        newest_commit=$(git -C "$CACHE_DIR" rev-list -n1 "$newest")
        if [ "$newest_commit" = "$CURRENT_COMMIT" ]; then
            echo "✅ Already on the latest release ($newest)"
        else
            echo "🆕 Latest release: $newest ($(printf '%.12s' "$newest_commit"))"
            echo "   Run ./update-skills.sh to move to it."
        fi
        exit 0
        ;;
    --latest)
        TARGET_REF=$(latest_tag)
        [ -n "$TARGET_REF" ] || die "No release tags found upstream"
        ;;
    *)
        TARGET_REF="$1"
        ;;
esac

TARGET_COMMIT=$(git -C "$CACHE_DIR" rev-parse --verify --quiet "${TARGET_REF}^{commit}" \
    || git -C "$CACHE_DIR" rev-parse --verify --quiet "origin/${TARGET_REF}^{commit}") \
    || die "Could not resolve '$TARGET_REF' upstream"

if [ "$TARGET_COMMIT" = "$CURRENT_COMMIT" ]; then
    echo "✅ Already pinned to $TARGET_REF ($(printf '%.12s' "$TARGET_COMMIT")) — nothing to do."
    exit 0
fi

echo
echo "📌 $CURRENT_REF ($(printf '%.12s' "$CURRENT_COMMIT"))  →  $TARGET_REF ($(printf '%.12s' "$TARGET_COMMIT"))"

# Show the diff, but only for the skills we actually install.
paths=()
while IFS= read -r name; do
    for bucket in "${BUCKETS[@]}"; do
        paths+=("skills/$bucket/$name")
    done
done < <(selected_skills)

echo
echo "── Changes to your selected skills ──"
if ! git -C "$CACHE_DIR" diff --stat "$CURRENT_COMMIT" "$TARGET_COMMIT" -- "${paths[@]}" 2>/dev/null | grep -q .; then
    echo "  (none — the skills you install are unchanged)"
else
    git -C "$CACHE_DIR" diff --stat "$CURRENT_COMMIT" "$TARGET_COMMIT" -- "${paths[@]}" | sed 's/^/  /'
fi

echo
echo "── Commits ──"
git -C "$CACHE_DIR" log --oneline --no-merges "$CURRENT_COMMIT..$TARGET_COMMIT" \
    | head -30 | sed 's/^/  /' || true

echo
read -r -p "Bump the pin to $TARGET_REF? [y/N] " reply
case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted — skills.lock unchanged."; exit 1 ;;
esac

# Rewrite the pin in place, leaving the file's comments and layout alone.
tmp=$(mktemp)
awk -v commit="$TARGET_COMMIT" -v ref="$TARGET_REF" -v today="$(date +%Y-%m-%d)" '
    $1 == "commit"    { printf "commit     %s\n", commit; next }
    $1 == "ref"       { printf "ref        %s\n", ref;    next }
    $1 == "pinned_at" { printf "pinned_at  %s\n", today;  next }
    { print }
' "$LOCK_FILE" > "$tmp"
mv "$tmp" "$LOCK_FILE"

echo "✅ skills.lock now pins $TARGET_REF ($(printf '%.12s' "$TARGET_COMMIT"))"
echo "   Re-run ./install-claude.sh to deploy, then commit skills.lock."
