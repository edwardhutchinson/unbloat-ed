#!/usr/bin/env bash
#
# Deploy every pinned source plus our own skills into Claude Code.

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/lib/skills-lib.sh"

echo "🧹 unbloat-ed: Deploying skills to Claude Code..."
sync_all
deploy_skills "$HOME/.claude/skills"
