#!/bin/bash

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SKILLS_SRC="$REPO_DIR/core/skills"
TARGET_DIR="$HOME/.claude/skills"

echo "🧹 unbloat-ed: Deploying skills to system environment..."

# Ensure target directory path exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Creating system directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

# Iterate through everything inside core/skills/
for item in "$SKILLS_SRC"/*; do
    # Only process skills directories
    if [ -f "$item" ]; then
        continue
    fi

    dir_name=$(basename "$item")
    target_link="$TARGET_DIR/$dir_name"

    # Safe cleanup if an old link or folder already exists at the target location
    if [ -L "$target_link" ]; then
        rm "$target_link"
    elif [ -d "$target_link" ]; then
        echo "⚠️  A physical directory already exists at $target_link. Backing up to _bak"
        mv "$target_link" "${target_link}.bak"
    fi

    # Create the absolute symlink for this specific skill folder
    ln -s "$item" "$target_link"
    echo "🔗 Linked directory: $dir_name -> $TARGET_DIR/"
done

echo "✅ Done! All skill directories mapped"

