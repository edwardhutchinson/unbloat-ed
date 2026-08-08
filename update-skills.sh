#!/usr/bin/env bash
#
# Bump the commit pinned in sources/<name>.lock.
#
#   ./update-skills.sh                     move every source to its latest release
#   ./update-skills.sh mattpocock          move one source to its latest release
#   ./update-skills.sh mattpocock v1.2.3   move one source to a tag, branch or commit
#   ./update-skills.sh --status            show every pin and what's newer
#   ./update-skills.sh --list              list every skill that would be installed

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/lib/skills-lib.sh"

# fetch_refs <source> — make sure the cache has full history to compare against
fetch_refs() {
    local cache
    cache=$(source_cache "$1")
    sync_source "$1"
    # The install path fetches shallowly to stay cheap, so deepen before diffing —
    # otherwise the commit log between two pins comes out truncated.
    if [ -f "$cache/.git/shallow" ]; then
        git -C "$cache" fetch --quiet --unshallow --tags origin 2>/dev/null || true
    fi
    git -C "$cache" fetch --quiet --tags --force origin '+refs/heads/*:refs/remotes/origin/*'
}

# latest_tag <source> — newest vN.N.N tag by version order
latest_tag() {
    git -C "$(source_cache "$1")" tag --list 'v[0-9]*' --sort=-v:refname | head -1
}

# update_one <source> [ref] — show what changes, confirm, rewrite the pin
update_one() {
    local name="$1" target_ref="${2:-}"
    local cache current_commit current_ref target_commit lock reply tmp

    cache=$(source_cache "$name")
    lock="$SOURCES_DIR/$name.lock"
    current_commit=$(source_get "$name" commit)
    current_ref=$(source_get "$name" ref)

    echo "🔎 $name"
    fetch_refs "$name"

    if [ -z "$target_ref" ]; then
        target_ref=$(latest_tag "$name")
        [ -n "$target_ref" ] || die "No release tags found in $name — pass a ref explicitly"
    fi

    target_commit=$(git -C "$cache" rev-parse --verify --quiet "${target_ref}^{commit}" \
        || git -C "$cache" rev-parse --verify --quiet "origin/${target_ref}^{commit}") \
        || die "Could not resolve '$target_ref' in $name"

    if [ "$target_commit" = "$current_commit" ]; then
        echo "  ✅ already at $target_ref ($(printf '%.12s' "$target_commit")) — nothing to do"
        return 0
    fi

    echo "  📌 $current_ref ($(printf '%.12s' "$current_commit"))  →  $target_ref ($(printf '%.12s' "$target_commit"))"

    # Diff only the paths this source actually contributes skills from. These
    # stay as literal git pathspecs — `read -a` splits on whitespace without
    # letting the shell glob-expand them against the current directory first.
    local globs paths=()
    globs=$(source_get "$name" skills)
    IFS=' ' read -r -a paths <<< "$globs"

    echo
    echo "  ── Changed skills ──"
    git -C "$cache" diff --stat "$current_commit" "$target_commit" -- "${paths[@]}" \
        | sed 's/^/  /' || true

    echo
    echo "  ── Commits ──"
    git -C "$cache" log --oneline --no-merges "$current_commit..$target_commit" \
        -- "${paths[@]}" | head -30 | sed 's/^/  /' || true

    echo
    read -r -p "  Bump $name to $target_ref? [y/N] " reply
    case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "  Aborted — $lock unchanged."; return 1 ;;
    esac

    # Rewrite the pin in place, leaving comments and layout alone.
    tmp=$(mktemp)
    awk -v commit="$target_commit" -v ref="$target_ref" -v today="$(date +%Y-%m-%d)" '
        $1 == "commit"    { printf "commit     %s\n", commit; next }
        $1 == "ref"       { printf "ref        %s\n", ref;    next }
        $1 == "pinned_at" { printf "pinned_at  %s\n", today;  next }
        { print }
    ' "$lock" > "$tmp"
    mv "$tmp" "$lock"

    echo "  ✅ $lock now pins $target_ref ($(printf '%.12s' "$target_commit"))"
}

case "${1:-}" in
    --list)
        for name in $(list_sources); do
            sync_source "$name"
        done
        plan=$(mktemp)
        build_plan "$plan" >/dev/null
        echo "📋 Skills that would be installed ($(wc -l < "$plan" | tr -d ' ') total):"
        awk -F'\t' '{ printf "  %-34s %s\n", $1, $3 }' "$plan"
        rm -f "$plan"
        ;;
    --status)
        for name in $(list_sources); do
            fetch_refs "$name"
            current=$(source_get "$name" commit)
            newest=$(latest_tag "$name")
            echo "📌 $name: $(source_get "$name" ref) ($(printf '%.12s' "$current"))"
            if [ -n "$newest" ]; then
                newest_commit=$(git -C "$(source_cache "$name")" rev-list -n1 "$newest")
                if [ "$newest_commit" = "$current" ]; then
                    echo "   ✅ latest release"
                else
                    echo "   🆕 $newest available ($(printf '%.12s' "$newest_commit"))"
                fi
            fi
        done
        ;;
    "")
        for name in $(list_sources); do
            update_one "$name" || true
        done
        echo
        echo "Re-run ./install-claude.sh to deploy, then commit sources/."
        ;;
    *)
        update_one "$1" "${2:-}"
        echo
        echo "Re-run ./install-claude.sh to deploy, then commit sources/."
        ;;
esac
