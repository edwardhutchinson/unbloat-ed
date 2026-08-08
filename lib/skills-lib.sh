#!/usr/bin/env bash
#
# Shared helpers for unbloat-ed skill deployment.
# Sourced by install-claude.sh, install-agy.sh and update-skills.sh.

set -euo pipefail

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
LOCK_FILE="$REPO_DIR/skills.lock"
LIST_FILE="$REPO_DIR/skills.list"
CACHE_DIR="$REPO_DIR/.cache/mattpocock-skills"

# Buckets upstream sorts its skills into. Searched in this order.
BUCKETS=(engineering productivity misc in-progress deprecated)

die() {
    echo "❌ $*" >&2
    exit 1
}

# lock_get <key> — read a value out of skills.lock
lock_get() {
    [ -f "$LOCK_FILE" ] || die "Missing $LOCK_FILE"
    local value
    value=$(awk -v key="$1" '$1 == key { print $2; exit }' "$LOCK_FILE")
    [ -n "$value" ] || die "No '$1' entry in $LOCK_FILE"
    printf '%s' "$value"
}

# selected_skills — the skill names from skills.list, comments stripped
selected_skills() {
    [ -f "$LIST_FILE" ] || die "Missing $LIST_FILE"
    sed -e 's/#.*//' -e 's/[[:space:]]//g' "$LIST_FILE" | grep -v '^$' || true
}

# sync_upstream — make CACHE_DIR a checkout of the pinned commit
sync_upstream() {
    local url commit ref
    url=$(lock_get upstream)
    commit=$(lock_get commit)
    ref=$(lock_get ref)

    if [ ! -d "$CACHE_DIR/.git" ]; then
        echo "📦 Creating upstream cache: $CACHE_DIR"
        mkdir -p "$CACHE_DIR"
        git init --quiet "$CACHE_DIR"
        git -C "$CACHE_DIR" remote add origin "$url"
    fi

    # Keep the remote honest if the lockfile's URL changed.
    git -C "$CACHE_DIR" remote set-url origin "$url"

    # Only hit the network when the pinned commit isn't already local.
    if ! git -C "$CACHE_DIR" cat-file -e "${commit}^{commit}" 2>/dev/null; then
        echo "⬇️  Fetching $ref ($(printf '%.12s' "$commit")) from $url"
        # Fetching a bare SHA is cheapest, but not every host allows it.
        git -C "$CACHE_DIR" fetch --quiet --depth 1 origin "$commit" 2>/dev/null \
            || git -C "$CACHE_DIR" fetch --quiet --tags origin \
            || die "Could not fetch from $url — check network access and SSH keys"
    fi

    git -C "$CACHE_DIR" checkout --quiet --force --detach "$commit" 2>/dev/null \
        || die "Commit $commit not found in $url — is the pin in skills.lock correct?"

    local head
    head=$(git -C "$CACHE_DIR" rev-parse HEAD)
    [ "$head" = "$commit" ] || die "Cache is at $head, expected $commit"

    echo "📌 Pinned at $ref ($(printf '%.12s' "$commit"))"
}

# resolve_skill <name> — echo the path to a skill within the pinned checkout
resolve_skill() {
    local name="$1" bucket matches=()
    for bucket in "${BUCKETS[@]}"; do
        [ -d "$CACHE_DIR/skills/$bucket/$name" ] && matches+=("$bucket")
    done

    case ${#matches[@]} in
        1) printf '%s' "$CACHE_DIR/skills/${matches[0]}/$name" ;;
        0) return 1 ;;
        *) die "'$name' exists in several buckets at this pin: ${matches[*]}" ;;
    esac
}

# prune_stale <target_dir> — drop links we own that are no longer selected
#
# Only touches symlinks pointing back into this repo, so skills installed by
# other means are left alone. This is what clears out links to skills that
# have been dropped from skills.list.
prune_stale() {
    local target_dir="$1"
    local link name target selected
    selected=$(selected_skills)

    [ -d "$target_dir" ] || return 0

    for link in "$target_dir"/*; do
        [ -L "$link" ] || continue
        target=$(readlink "$link")
        case "$target" in
            "$REPO_DIR"/*) ;;
            *) continue ;;
        esac

        name=$(basename "$link")
        if ! printf '%s\n' "$selected" | grep -qxF "$name"; then
            rm "$link"
            echo "🗑️  Removed $name (no longer in skills.list)"
        fi
    done
}

# deploy_skills <target_dir> — symlink every selected skill into target_dir
deploy_skills() {
    local target_dir="$1"
    local name src link missing=() count=0

    mkdir -p "$target_dir"
    prune_stale "$target_dir"

    while IFS= read -r name; do
        if ! src=$(resolve_skill "$name"); then
            missing+=("$name")
            continue
        fi

        link="$target_dir/$name"

        # Replace an old link outright; never silently destroy a real directory.
        if [ -L "$link" ]; then
            rm "$link"
        elif [ -d "$link" ]; then
            echo "⚠️  A real directory already exists at $link — backing up to .bak"
            rm -rf "${link}.bak"
            mv "$link" "${link}.bak"
        fi

        ln -s "$src" "$link"
        echo "🔗 $name"
        count=$((count + 1))
    done < <(selected_skills)

    echo "✅ Linked $count skills into $target_dir"

    if [ ${#missing[@]} -gt 0 ]; then
        echo
        echo "⚠️  Not found at this pin: ${missing[*]}"
        echo "   They may have been renamed or removed upstream."
        echo "   Run ./update-skills.sh --list to see what's available."
        return 1
    fi
}
