FROM jenkins/ssh-agent:latest-jdk21

# Install useful tools for build agents
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    make \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Do NOT switch to USER jenkins here — the setup-sshd entrypoint
# needs root to write /etc/environment and start the SSH daemon.
# It drops privileges to the jenkins user internally.

# The public key will be injected via environment variable JENKINS_AGENT_SSH_PUBKEY
# in docker-compose.yml
