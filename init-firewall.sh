#!/usr/bin/env bash
# Runs as root inside the container.
# 1. Sets up iptables egress allowlist
# 2. Marks CLAUDE.md and ARCHITECTURE.md read-only
# 3. Drops to the claude user and execs loop.sh
set -euo pipefail

# --- FIREWALL ---

# Drop all outbound traffic by default
iptables -F OUTPUT
iptables -P OUTPUT DROP

# Allow loopback
iptables -A OUTPUT -o lo -j ACCEPT

# Allow DNS so we can resolve domain names below
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Resolve a domain to its IPv4 addresses (requires DNS above to be open)
resolve_ipv4() {
    getent ahosts "$1" 2>/dev/null \
        | awk '{print $1}' \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -u
}

ALLOWED_DOMAINS=(
    api.anthropic.com
    github.com
    objects.githubusercontent.com
    codeload.github.com
    registry.npmjs.org
    registry.yarnpkg.com
    pypi.org
    files.pythonhosted.org
    ntfy.sh
    claude.ai
)

for domain in "${ALLOWED_DOMAINS[@]}"; do
    echo "Resolving $domain..."
    for ip in $(resolve_ipv4 "$domain"); do
        echo "  ACCEPT $ip"
        iptables -A OUTPUT -d "$ip" -j ACCEPT
    done
done

echo "Firewall configured. All other egress blocked."

# --- READ-ONLY FILES ---

[ -f /workspace/CLAUDE.md ]       && chmod 0444 /workspace/CLAUDE.md
[ -f /workspace/ARCHITECTURE.md ] && chmod 0444 /workspace/ARCHITECTURE.md

# --- DROP TO NON-ROOT ---

# Match claude's UID to the workspace owner so files written inside the container
# are owned by the host user. The ubuntu user is removed in the Dockerfile so
# claude holds UID 1000 cleanly — no collision, no -o flag needed.
WORKSPACE_UID=$(stat -c %u /workspace)
if [ "$WORKSPACE_UID" -gt 0 ] && [ "$(id -u claude)" != "$WORKSPACE_UID" ]; then
    usermod -u "$WORKSPACE_UID" claude
    chown -R claude /home/claude
fi

exec su -s /bin/bash claude -c \
    "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin && bash /workspace/loop.sh"
