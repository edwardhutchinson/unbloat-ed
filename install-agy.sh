#!/usr/bin/env bash
#
# Deploy the pinned upstream skills into Gemini Antigravity.

set -euo pipefail

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/lib/skills-lib.sh"

echo "🧹 unbloat-ed: Deploying skills to Gemini Antigravity..."
sync_upstream
deploy_skills "$HOME/.gemini/skills"
