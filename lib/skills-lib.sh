#!/usr/bin/env bash
#
# Shared helpers for unbloat-ed skill deployment.
# Sourced by install-claude.sh, install-agy.sh and update-skills.sh.
#
# Skills come from two kinds of place:
#
#   sources/<name>.lock   an external repo, pinned to a commit, fetched into .cache/
#   core/skills/          our own skills, living in this repo
#
# Everything is symlinked into the harness's skills directory. Where two places
# offer the same skill name, the one deployed later wins — and our own skills
# are always deployed last, so they override anything upstream.

set -euo pipefail

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
SOURCES_DIR="$REPO_DIR/sources"
OWN_SKILLS_DIR="$REPO_DIR/core/skills"
CACHE_DIR="$REPO_DIR/.cache/sources"

die() {
    echo "❌ $*" >&2
    exit 1
}

# list_sources — every pinned source, in deployment order
list_sources() {
    [ -d "$SOURCES_DIR" ] || return 0
    local file
    for file in "$SOURCES_DIR"/*.lock; do
        [ -f "$file" ] || continue
        basename "$file" .lock
    done
}

# source_get <source> <key> — read a field; values may contain spaces
source_get() {
    local file="$SOURCES_DIR/$1.lock" value
    [ -f "$file" ] || die "No such source: '$1' (expected $file)"
    value=$(awk -v key="$2" '$1 == key { $1 = ""; sub(/^[[:space:]]+/, ""); print; exit }' "$file")
    [ -n "$value" ] || die "Source '$1' has no '$2' field"
    printf '%s' "$value"
}

# source_cache <source> — where that source's checkout lives
source_cache() {
    printf '%s' "$CACHE_DIR/$1"
}

# sync_source <source> — check the cache out at the pinned commit
sync_source() {
    local name="$1" url commit ref cache head
    url=$(source_get "$name" url)
    commit=$(source_get "$name" commit)
    ref=$(source_get "$name" ref)
    cache=$(source_cache "$name")

    if [ ! -d "$cache/.git" ]; then
        mkdir -p "$cache"
        git init --quiet "$cache"
        git -C "$cache" remote add origin "$url"
    fi

    # Keep the remote honest if the lockfile's URL changed.
    git -C "$cache" remote set-url origin "$url"

    # Only hit the network when the pinned commit isn't already local.
    if ! git -C "$cache" cat-file -e "${commit}^{commit}" 2>/dev/null; then
        echo "  ⬇️  fetching $ref ($(printf '%.12s' "$commit")) from $url"
        # Fetching a bare SHA is cheapest, but not every host allows it.
        git -C "$cache" fetch --quiet --depth 1 origin "$commit" 2>/dev/null \
            || git -C "$cache" fetch --quiet --tags origin \
            || die "Could not fetch $name from $url — check network access and SSH keys"
    fi

    git -C "$cache" checkout --quiet --force --detach "$commit" 2>/dev/null \
        || die "Commit $commit not found in $url — is sources/$name.lock correct?"

    head=$(git -C "$cache" rev-parse HEAD)
    [ "$head" = "$commit" ] || die "$name cache is at $head, expected $commit"
}

# source_skills <source> — emit "<skill name>\t<path>" for each skill it offers
source_skills() {
    local name="$1" cache globs
    cache=$(source_cache "$name")
    globs=$(source_get "$name" skills)
    [ -d "$cache" ] || return 0

    # Subshell: the cd must not leak, and $globs is deliberately unquoted so it
    # word-splits into patterns and then glob-expands.
    (
        cd "$cache" || exit 0
        local pattern dir
        for pattern in $globs; do
            for dir in $pattern; do
                [ -f "$dir/SKILL.md" ] || continue
                printf '%s\t%s\n' "$(basename "$dir")" "$cache/$dir"
            done
        done
    )
}

# own_skills — emit "<skill name>\t<path>" for each skill in core/skills/
own_skills() {
    [ -d "$OWN_SKILLS_DIR" ] || return 0
    local dir
    for dir in "$OWN_SKILLS_DIR"/*; do
        [ -f "$dir/SKILL.md" ] || continue
        printf '%s\t%s\n' "$(basename "$dir")" "$dir"
    done
}

# build_plan <outfile> — resolve every source plus our own into one skill list.
# Emits "<name>\t<path>\t<origin>", one winner per name, sorted by name.
build_plan() {
    local out="$1" raw name
    raw=$(mktemp)

    {
        for name in $(list_sources); do
            source_skills "$name" | awk -v origin="$name" '{ print $0 "\t" origin }'
        done
        own_skills | awk '{ print $0 "\tcore/skills" }'
    } > "$raw"

    # Report every name offered by more than one place before collapsing.
    local dupe winner losers
    while IFS= read -r dupe; do
        [ -n "$dupe" ] || continue
        winner=$(awk -F'\t' -v n="$dupe" '$1 == n { o = $3 } END { print o }' "$raw")
        losers=$(awk -F'\t' -v n="$dupe" -v w="$winner" \
            '$1 == n && $3 != w { printf "%s ", $3 }' "$raw")
        echo "  ↪️  $dupe: using $winner (overrides ${losers% })"
    done < <(cut -f1 "$raw" | sort | uniq -d)

    # Last entry for a given name wins, so our own skills override upstream.
    awk -F'\t' '{ win[$1] = $0 } END { for (k in win) print win[k] }' "$raw" \
        | sort > "$out"

    rm -f "$raw"
}

# deploy_skills <target_dir> — sync every source, then symlink the whole plan
deploy_skills() {
    local target_dir="$1"
    local plan name path origin link count=0

    plan=$(mktemp)
    build_plan "$plan"

    mkdir -p "$target_dir"

    while IFS=$'\t' read -r name path origin; do
        link="$target_dir/$name"

        # Replace a link outright; never silently destroy a real directory.
        if [ -L "$link" ]; then
            rm "$link"
        elif [ -d "$link" ]; then
            echo "  ⚠️  a real directory already exists at $link — backing up to .bak"
            rm -rf "${link}.bak"
            mv "$link" "${link}.bak"
        fi

        ln -s "$path" "$link"
        count=$((count + 1))
    done < "$plan"

    prune_stale "$target_dir" "$plan"

    echo "✅ Linked $count skills into $target_dir"
    rm -f "$plan"
}

# prune_stale <target_dir> <plan> — drop links we own that are no longer deployed
#
# Only touches symlinks pointing back into this repo, so skills installed by
# other means are left alone.
prune_stale() {
    local target_dir="$1" plan="$2"
    local link name target

    [ -d "$target_dir" ] || return 0

    for link in "$target_dir"/*; do
        [ -L "$link" ] || continue
        target=$(readlink "$link")
        case "$target" in
            "$REPO_DIR"/*) ;;
            *) continue ;;
        esac

        name=$(basename "$link")
        if ! cut -f1 "$plan" | grep -qxF "$name"; then
            rm "$link"
            echo "  🗑️  removed $name (no longer provided by any source)"
        fi
    done
}

# sync_all — check out every source at its pin, announcing each one
sync_all() {
    local name ref commit found=0
    for name in $(list_sources); do
        found=1
        sync_source "$name"
        ref=$(source_get "$name" ref)
        commit=$(source_get "$name" commit)
        echo "📌 $name @ $ref ($(printf '%.12s' "$commit"))"
    done
    [ "$found" = 1 ] || echo "ℹ️  No sources pinned in $SOURCES_DIR"
}
