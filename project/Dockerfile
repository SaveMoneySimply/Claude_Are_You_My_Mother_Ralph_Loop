FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

ENV ANTHROPIC_API_KEY=""
ENV GEMINI_API_KEY=""
ENV GROQ_API_KEY=""
ENV MISTRAL_API_KEY=""
ENV OPENROUTER_API_KEY=""

# System packages: Node 20 setup prereqs + runtime tools
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    iptables \
    jq \
    perl \
    ripgrep \
    && rm -rf /var/lib/apt/lists/*

# Node 20 via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Non-root user for loop execution.
# Remove the ubuntu user that ships in ubuntu:24.04 at UID 1000 so claude can
# cleanly own UID 1000. This prevents a UID collision when init-firewall.sh runs
# usermod to match claude's UID to the bind-mounted workspace owner (typically 1000).
RUN userdel -r ubuntu && useradd -m -s /bin/bash -u 1000 claude

WORKDIR /workspace

COPY init-firewall.sh /init-firewall.sh
RUN chmod +x /init-firewall.sh

# init-firewall.sh runs as root, sets up iptables, then drops to claude user
ENTRYPOINT ["/init-firewall.sh"]
