#!/usr/bin/env bash
#
# Deploy every pinned source plus our own skills into Codex.

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/lib/skills-lib.sh"

echo "🧹 unbloat-ed: Deploying skills to Codex..."
sync_all
deploy_skills "${CODEX_HOME:-$HOME/.codex}/skills"
