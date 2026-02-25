# playground-jenkins

A fully Dockerized **Jenkins master-slave playground** with 3 agents (2 SSH + 1 JNLP/inbound), auto-configured via [Jenkins Configuration as Code (JCasC)](https://www.jenkins.io/projects/jcasc/). Launch with a single command — zero manual setup.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Docker Network: jenkins-net            │
│                                                          │
│  ┌──────────────────┐                                    │
│  │  jenkins-master   │◄──────── http://localhost:8080    │
│  │  (LTS + JDK 21)  │                                    │
│  │                   │         ┌────────────────┐        │
│  │  Port 8080 (UI)   │──SSH──▶│  ssh-agent-1    │        │
│  │  Port 50000 (JNLP)│        │  (JDK 21)      │        │
│  │                   │        └────────────────┘        │
│  │  Plugins:         │                                    │
│  │  • JCasC          │        ┌────────────────┐        │
│  │  • SSH Slaves     │──SSH──▶│  ssh-agent-2    │        │
│  │  • Pipeline       │        │  (JDK 21)      │        │
│  │  • Job DSL        │        └────────────────┘        │
│  │  • Git            │                                    │
│  │                   │        ┌────────────────┐        │
│  │                   │◀─JNLP─│  jnlp-agent-1   │        │
│  │                   │        │  (JDK 21)      │        │
│  └──────────────────┘        └────────────────┘        │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Agent types:**
- **SSH agents** (master-initiated): Jenkins master connects to agents via SSH on port 22
- **JNLP/Inbound agent** (agent-initiated): Agent connects back to master via WebSocket on port 50000

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (v24+)
- [Docker Compose](https://docs.docker.com/compose/) (v2+)
- `ssh-keygen` (pre-installed on macOS/Linux)
- `make` (optional, for convenience commands)

---

## Quick Start

### 1. Generate SSH keys & start everything

```bash
make up
```

Or without `make`:

```bash
bash generate-ssh-key.sh
export JENKINS_AGENT_SSH_PUBKEY=$(cat secrets/jenkins_agent_key.pub)
docker compose up --build -d
```

### 2. Wait for Jenkins to initialize

Jenkins takes ~90 seconds to boot, install plugins, and apply JCasC configuration.

```bash
# Watch the logs
make logs

# Or check container status
make status
```

### 3. Access Jenkins

- **URL:** http://localhost:8080
- **Username:** `admin`
- **Password:** `admin`

The SSH agents will auto-connect. You should see `ssh-agent-1` and `ssh-agent-2` online under **Manage Jenkins → Nodes**.

### 4. Connect the JNLP agent

The JNLP agent needs a secret token from the master. After Jenkins is fully up:

```bash
# Fetch the secret
make jnlp-secret

# Copy the secret and save it
echo 'JNLP_SECRET=<paste-secret-here>' > .env

# Restart the JNLP agent with the secret
make restart-jnlp
```

### 5. Run sample pipelines

Three sample pipeline jobs are automatically created:

| Job | Description | Agent Label |
|-----|-------------|-------------|
| `ssh-agent-test` | Runs system info commands on an SSH agent | `ssh-agent` |
| `jnlp-agent-test` | Runs system info commands on the JNLP agent | `jnlp-agent` |
| `all-agents-parallel` | Runs tasks in parallel across both agent types | `ssh-agent` + `jnlp-agent` |

Go to the Jenkins dashboard and click **Build Now** on any job.

---

## Project Structure

```
playground-jenkins/
├── docker-compose.yml          # Orchestrates all containers
├── Makefile                    # Convenience commands
├── Jenkinsfile                 # Sample pipeline for this repo
├── generate-ssh-key.sh         # Generates SSH keypair
├── fetch-jnlp-secret.sh       # Retrieves JNLP secret from master
├── .gitignore
├── .env                        # JNLP_SECRET (generated, gitignored)
├── master/
│   ├── Dockerfile              # Jenkins master image
│   ├── plugins.txt             # Plugins to install
│   └── casc.yaml               # JCasC configuration (agents, jobs, security)
├── ssh-agent/
│   └── Dockerfile              # SSH agent image
└── secrets/                    # Generated SSH keys (gitignored)
    ├── jenkins_agent_key       # Private key (mounted into master)
    └── jenkins_agent_key.pub   # Public key (injected into SSH agents)
```

---

## Available `make` Commands

```
make help              Show all available commands
make up                Start the entire playground
make down              Stop all containers
make restart           Restart everything
make logs              Tail logs from all containers
make logs-master       Tail logs from master only
make status            Show container status
make jnlp-secret      Fetch JNLP secret from master
make restart-jnlp      Restart the JNLP agent
make clean             Remove containers, volumes, and secrets
make shell-master      Open a shell on the master
make shell-ssh1        Open a shell on ssh-agent-1
make shell-ssh2        Open a shell on ssh-agent-2
make shell-jnlp        Open a shell on jnlp-agent-1
```

---

## How It Works

### Jenkins Configuration as Code (JCasC)

The entire Jenkins configuration is defined declaratively in [`master/casc.yaml`](master/casc.yaml):

- **Security:** Local user database with `admin`/`admin`; logged-in users can do everything
- **Nodes:** 2 SSH agents + 1 JNLP agent, each with 2 executors
- **Credentials:** SSH private key loaded from Docker secret
- **Jobs:** 3 sample pipeline jobs created via Job DSL
- **Master:** Zero executors (builds only run on agents)

### SSH Agent Connection Flow

1. Master reads the private key from `/run/secrets/jenkins_agent_key`
2. SSH agents receive the public key via `JENKINS_AGENT_SSH_PUBKEY` env var
3. Master connects to agents on port 22 using the `jenkins` user
4. Host key verification is disabled (playground only — don't do this in production!)

### JNLP Agent Connection Flow

1. JCasC creates the `jnlp-agent-1` node definition on the master
2. Jenkins generates a secret token for the agent
3. The agent container connects to the master using `JENKINS_URL`, `JENKINS_AGENT_NAME`, and `JENKINS_SECRET`
4. Communication happens over WebSocket (`JENKINS_WEB_SOCKET=true`)

---

## Customization

### Add more SSH agents

Add a new service to `docker-compose.yml`:

```yaml
ssh-agent-3:
  build:
    context: ./ssh-agent
    dockerfile: Dockerfile
  container_name: ssh-agent-3
  restart: unless-stopped
  environment:
    - JENKINS_AGENT_SSH_PUBKEY=${JENKINS_AGENT_SSH_PUBKEY}
  expose:
    - "22"
  networks:
    - jenkins-net
```

Then add the corresponding node in `master/casc.yaml` under `jenkins.nodes`.

### Change Jenkins version

Edit `master/Dockerfile`:

```dockerfile
FROM jenkins/jenkins:2.479.2-lts-jdk21   # pin a specific version
```

### Add more plugins

Edit `master/plugins.txt` and rebuild:

```bash
make restart
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| SSH agents stuck "offline" | Check `make logs` for SSH errors; verify keys exist in `secrets/` |
| JNLP agent won't connect | Ensure `.env` has correct `JNLP_SECRET`; run `make jnlp-secret` again |
| Port 8080 already in use | Change the port mapping in `docker-compose.yml`: `"9090:8080"` |
| Stale state after changes | Run `make clean && make up` to start fresh |
| Plugin installation fails | Check network connectivity; the master needs internet during build |

---

## Tear Down

```bash
# Stop containers (keeps data)
make down

# Stop containers AND delete all data
make clean
```

---

## License

[MIT](LICENSE)