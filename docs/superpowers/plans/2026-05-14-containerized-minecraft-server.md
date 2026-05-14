# Containerized Minecraft Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Docker image and docker-compose setup for a Minecraft 1.20.1 Forge server with Re-Avaritia, JEI, and performance mods.

**Architecture:** Multi-stage Containerfile — builder stage downloads Forge installer + mods, runtime stage uses minimal JRE Alpine image. docker-compose.yml orchestrates with named volume for persistent data.

**Tech Stack:** Docker, eclipse-temurin:17-jdk (builder), eclipse-temurin:17-jre-alpine (runtime), Forge 47.4.20, wget, unzip, jq, iproute2

---

## Files

```
re-avaritia-containerized/
├── image/
│   ├── Containerfile        # Multi-stage Docker build
│   └── entrypoint.sh         # First-run init + server launch
├── docker-compose.yml        # Orchestration
```

### File Responsibilities

| File | Responsibility |
|------|---------------|
| `image/Containerfile` | Two-stage build: download Forge + mods, assemble minimal runtime image with iproute2 for healthcheck |
| `image/entrypoint.sh` | Initialize /data on first run (copy mods, write eula.txt + server.properties), then launch Forge with JVM args |
| `docker-compose.yml` | Service definition, volumes, ports, env vars, `ss`-based healthcheck |

---

### Task 1: Create directory structure

**Files:**
- Create: `image/` directory

- [ ] **Step 1: Create the image directory**

```bash
mkdir -p /Users/andreas/Source/re-avaritia-containerized/image
```

---

### Task 2: Write the Containerfile

**Files:**
- Create: `image/Containerfile`

- [ ] **Step 1: Write the multi-stage Containerfile**

```dockerfile
# Stage 1: Builder — download Forge and mods
FROM eclipse-temurin:17-jdk AS builder

WORKDIR /build

# Install tools
RUN apt-get update && apt-get install -y wget unzip jq && rm -rf /var/lib/apt/lists/*

# Download Forge installer
ARG FORGE_VERSION=1.20.1-47.4.20
RUN wget -q "https://maven.minecraftforge.net/net/minecraftforge/forge/${FORGE_VERSION}/forge-${FORGE_VERSION}-installer.jar" -O forge-installer.jar

# Install Forge server (creates libraries/ and run script)
RUN java -jar forge-installer.jar --installServer

# Create mods directory
RUN mkdir -p /build/mods

# Download Re-Avaritia from GitHub releases
ARG AVARITIA_VERSION=1.3.9.5-release
RUN wget -q "https://github.com/Nova-Committee/Re-Avaritia/releases/download/v${AVARITIA_VERSION}-forge/Re-Avaritia-forge-1.20.1-${AVARITIA_VERSION}.jar" -O /build/mods/Re-Avaritia.jar

# Download JEI from Modrinth
RUN wget -q "https://api.modrinth.com/v2/project/jei/version?loaders=[\"forge\"]&game_versions=[\"1.20.1\"]" -O /tmp/jei_versions.json && \
    JEI_URL=$(jq -r '.[0].files[] | select(.primary==true) | .url' /tmp/jei_versions.json) && \
    wget -q "$JEI_URL" -O /build/mods/jei.jar && \
    rm /tmp/jei_versions.json

# Download ModernFix from Modrinth
RUN wget -q "https://api.modrinth.com/v2/project/modernfix/version?loaders=[\"forge\"]&game_versions=[\"1.20.1\"]" -O /tmp/mf_versions.json && \
    MF_URL=$(jq -r '.[0].files[] | select(.primary==true) | .url' /tmp/mf_versions.json) && \
    wget -q "$MF_URL" -O /build/mods/modernfix.jar && \
    rm /tmp/mf_versions.json

# Download FerriteCore from Modrinth
RUN wget -q "https://api.modrinth.com/v2/project/ferrite-core/version?loaders=[\"forge\"]&game_versions=[\"1.20.1\"]" -O /tmp/fc_versions.json && \
    FC_URL=$(jq -r '.[0].files[] | select(.primary==true) | .url' /tmp/fc_versions.json) && \
    wget -q "$FC_URL" -O /build/mods/ferritecore.jar && \
    rm /tmp/fc_versions.json

# Download FastSuite from Modrinth
RUN wget -q "https://api.modrinth.com/v2/project/fastsuite/version?loaders=[\"forge\"]&game_versions=[\"1.20.1\"]" -O /tmp/fs_versions.json && \
    FS_URL=$(jq -r '.[0].files[] | select(.primary==true) | .url' /tmp/fs_versions.json) && \
    wget -q "$FS_URL" -O /build/mods/fastsuite.jar && \
    rm /tmp/fs_versions.json

# Stage 2: Runtime — minimal JRE with server files
FROM eclipse-temurin:17-jre-alpine

# Install iproute2 for ss command (used by healthcheck)
RUN apk add --no-cache iproute2 bash

WORKDIR /server

# Create non-root user
RUN addgroup -g 1000 minecraft && adduser -D -u 1000 -G minecraft minecraft

# Copy server files from builder
COPY --from=builder /build/libraries /server/libraries
COPY --from=builder /build/forge-*.jar /server/
COPY --from=builder /build/mods /defaults/mods

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown minecraft:minecraft /entrypoint.sh

# Create data directory
RUN mkdir -p /data /defaults && chown -R minecraft:minecraft /server /data /defaults

USER minecraft

VOLUME ["/data"]
EXPOSE 25565

ENTRYPOINT ["/entrypoint.sh"]
```

---

### Task 3: Write the entrypoint script

**Files:**
- Create: `image/entrypoint.sh`

- [ ] **Step 1: Write entrypoint.sh**

```bash
#!/bin/sh
set -e

# Initialize /data on first run
if [ ! -f /data/server.properties ]; then
    echo "=== First run: initializing server data ==="
    mkdir -p /data/mods
    cp /defaults/mods/* /data/mods/ 2>/dev/null || true

    cat > /data/server.properties << 'PROPS'
enable-jmx-monitoring=false
rcon.port=25575
level-seed=
gamemode=survival
enable-command-block=false
enable-query=false
generator-settings={}
level-name=world
motd=Re-Avaritia Server
query.port=25565
pvp=true
generate-structures=true
difficulty=normal
network-compression-threshold=256
max-tick-time=60000
max-players=20
use-native-transport=true
online-mode=true
enable-status=true
allow-flight=false
broadcast-rcon-to-ops=true
view-distance=10
max-build-height=256
server-ip=
allow-nether=true
server-port=25565
enable-rcon=false
sync-chunk-writes=true
op-permission-level=4
prevent-proxy-connections=false
hide-online-players=false
resource-pack=
entity-broadcast-range-percentage=100
simulation-distance=8
rcon.password=
player-idle-timeout=0
force-gamemode=false
rate-limit=0
hardcore=false
white-list=false
broadcast-console-to-ops=true
spawn-npcs=true
spawn-animals=true
function-permission-level=2
level-type=minecraft\:normal
text-filtering-config=
spawn-monsters=true
enforce-whitelist=false
resource-pack-sha1=
spawn-protection=16
max-world-size=29999984
PROPS

    echo "eula=true" > /data/eula.txt
fi

# Find the forge jar
FORGE_JAR=$(ls /server/forge-*.jar 2>/dev/null | head -1)
if [ -z "$FORGE_JAR" ]; then
    echo "ERROR: No forge server jar found in /server/"
    exit 1
fi

echo "Found forge jar: ${FORGE_JAR}"

# Set memory limits from env or default
MIN_RAM=${MIN_RAM:-2G}
MAX_RAM=${MAX_RAM:-4G}

JAVA_OPTS="${JAVA_OPTS:--XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5}"

echo "Starting Forge server with ${MAX_RAM} max RAM..."
cd /data
exec java -Xms${MIN_RAM} -Xmx${MAX_RAM} ${JAVA_OPTS} -jar "${FORGE_JAR}" nogui
```

---

### Task 4: Write docker-compose.yml

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Write docker-compose.yml**

```yaml
version: "3.8"

services:
  minecraft:
    build:
      context: ./image
      dockerfile: Containerfile
    container_name: re-avaritia-mc
    ports:
      - "25565:25565/tcp"
      - "25565:25565/udp"
    volumes:
      - mc-data:/data
    environment:
      MIN_RAM: "2G"
      MAX_RAM: "4G"
    healthcheck:
      test: ["CMD-SHELL", "ss -tln | grep -q ':25565 '"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 120s
    restart: unless-stopped
    stdin_open: true
    tty: true

volumes:
  mc-data:
```

---

### Task 5: Build and test

- [ ] **Step 1: Build the Docker image**

```bash
docker compose -f /Users/andreas/Source/re-avaritia-containerized/docker-compose.yml build
```

Expected: Build succeeds. Mod downloads complete successfully.

- [ ] **Step 2: Start the server in detached mode**

```bash
docker compose -f /Users/andreas/Source/re-avaritia-containerized/docker-compose.yml up -d
```

Expected: Container starts. First-run initialization copies mods and creates eula.txt + server.properties.

- [ ] **Step 3: Check logs for successful startup**

```bash
docker compose -f /Users/andreas/Source/re-avaritia-containerized/docker-compose.yml logs -f --tail=50
```

Expected: See "First run: initializing server data", Forge loads mods including Re-Avaritia, and eventually the "Done" message indicating server is ready.

- [ ] **Step 4: Verify healthcheck passes**

```bash
sleep 130
docker compose -f /Users/andreas/Source/re-avaritia-containerized/docker-compose.yml ps
```

Expected: Container status shows "(healthy)".

- [ ] **Step 5: Verify mods directory has all 5 mods**

```bash
docker compose -f /Users/andreas/Source/re-avaritia-containerized/docker-compose.yml exec minecraft ls -la /data/mods/
```

Expected: 5 JAR files — Re-Avaritia.jar, jei.jar, modernfix.jar, ferritecore.jar, fastsuite.jar.

- [ ] **Step 6: Shut down the server**

```bash
docker compose -f /Users/andreas/Source/re-avaritia-containerized/docker-compose.yml down
```

Expected: Container and network removed. Named volume persists.

- [ ] **Step 7: Verify data persistence across restarts**

```bash
docker compose -f /Users/andreas/Source/re-avaritia-containerized/docker-compose.yml up -d
sleep 10
docker compose -f /Users/andreas/Source/re-avaritia-containerized/docker-compose.yml logs --tail=5
```

Expected: Server starts without re-initialization (no "First run" message). No "initializing" text in logs.

- [ ] **Step 8: Clean up**

```bash
docker compose -f /Users/andreas/Source/re-avaritia-containerized/docker-compose.yml down
```

Expected: Clean shutdown.

---

### Task 6: Commit

- [ ] **Step 1: Commit all files**

```bash
cd /Users/andreas/Source/re-avaritia-containerized && \
git add image/Containerfile image/entrypoint.sh docker-compose.yml && \
git commit -m "feat: add containerized Minecraft 1.20.1 Forge server with Re-Avaritia"
```
