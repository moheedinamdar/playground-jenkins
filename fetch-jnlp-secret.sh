#!/usr/bin/env bash
# ============================================================================
# fetch-jnlp-secret.sh — Retrieve the JNLP agent secret from Jenkins master
# ============================================================================
# After Jenkins master is up and JCasC has created the jnlp-agent-1 node,
# this script fetches the secret token needed for the inbound agent to connect.
#
# Usage: ./fetch-jnlp-secret.sh [agent-name]
# ============================================================================
set -euo pipefail

AGENT_NAME="${1:-jnlp-agent-1}"
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_PASS="${JENKINS_PASS:-admin}"

echo "▸ Waiting for Jenkins to be ready..."
until curl -sf "${JENKINS_URL}/login" > /dev/null 2>&1; do
    sleep 5
    echo "  Still waiting..."
done

echo "▸ Fetching JNLP secret for agent '${AGENT_NAME}'..."

# Get a crumb for CSRF protection
CRUMB=$(curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
    "${JENKINS_URL}/crumbIssuer/api/json" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d['crumbRequestField'] + '=' + d['crumb'])" 2>/dev/null || echo "")

SECRET=$(curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
    ${CRUMB:+-H "${CRUMB%%=*}: ${CRUMB#*=}"} \
    "${JENKINS_URL}/computer/${AGENT_NAME}/slave-agent.jnlp" | \
    sed -n 's/.*<argument>\([a-f0-9]\{64\}\)<\/argument>.*/\1/p')

if [[ -z "${SECRET}" ]]; then
    echo "✘ Failed to retrieve secret. Is the agent '${AGENT_NAME}' configured in Jenkins?"
    echo "  You may need to wait longer for Jenkins to finish initializing."
    exit 1
fi

echo ""
echo "✔ JNLP secret for '${AGENT_NAME}':"
echo "  ${SECRET}"
echo ""
echo "▸ To use it, add to your .env file:"
echo "  JNLP_SECRET=${SECRET}"
