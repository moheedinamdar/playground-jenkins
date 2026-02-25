#!/usr/bin/env bash
# ============================================================================
# generate-ssh-key.sh — Generate SSH keypair for Jenkins SSH agents
# ============================================================================
set -euo pipefail

SECRETS_DIR="$(cd "$(dirname "$0")" && pwd)/secrets"
KEY_FILE="${SECRETS_DIR}/jenkins_agent_key"

if [[ -f "${KEY_FILE}" ]]; then
    echo "✔ SSH keypair already exists at ${KEY_FILE}"
    echo "  To regenerate, delete the secrets/ directory and re-run this script."
    exit 0
fi

echo "▸ Creating secrets directory..."
mkdir -p "${SECRETS_DIR}"

echo "▸ Generating RSA 4096-bit SSH keypair..."
ssh-keygen -t rsa -b 4096 -f "${KEY_FILE}" -N "" -C "jenkins-agent-key"

echo ""
echo "✔ SSH keypair generated successfully!"
echo "  Private key: ${KEY_FILE}"
echo "  Public key:  ${KEY_FILE}.pub"
echo ""
echo "▸ The public key contents (for reference):"
cat "${KEY_FILE}.pub"
