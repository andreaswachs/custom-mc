# Containerized Minecraft Server — Re-Avaritia

**Date:** 2026-05-14
**Status:** Approved

## Overview

A containerized Minecraft 1.20.1 Forge server running Re-Avaritia, JEI, and performance mods, managed via Docker + docker-compose with persistent data volumes.

## Requirements

- Minecraft 1.20.1 with Forge (latest stable 49.x)
- Re-Avaritia v1.3.9.5 (latest release)
- JEI 15.x (recipe viewer)
- Performance mods: ModernFix, FerriteCore, FastSuite
- Docker + docker-compose
- Persistent world/mod/config data via volume
- Health checks

## Architecture

### Multi-stage Dockerfile

**Stage 1 (builder):** `eclipse-temurin:17-jdk`
- Downloads Forge installer for 1.20.1
- Runs installer to generate server files (`libraries/`, `run.sh`, etc.)
- Downloads all mod JARs into `/mods` directory

**Stage 2 (runtime):** `eclipse-temurin:17-jre-alpine`
- Copies only necessary server files from Stage 1
- Contains a small entrypoint script for first-run initialization
- Uses Aikar's JVM flags for optimal GC performance

### docker-compose.yml

- Single service: `minecraft`
- Port: `25565:25565` (TCP and UDP for Minecraft protocol)
- Named volume: `mc-data:/data`
- Environment: `JAVA_OPTS`, `MIN_RAM`, `MAX_RAM` (default 4G)
- `restart: unless-stopped`

### Directory Structure

```
/images                # Dockerfile for building the image
/docker-compose.yml    # Container orchestration
```

Inside the container:

```
/data/                 # Persistent volume
  mods/                # Mod JARs
  config/              # Mod configs
  world/               # World save
  logs/                # Server logs
  server.properties
  eula.txt
  banned-ips.json, banned-players.json, ops.json, whitelist.json
```

/defaults/             # Image layer (copied to /data on first run)
  mods/
  server.properties
```

### Entrypoint Script

On container start:
1. If `/data/mods/` is empty → copy `/defaults/mod/*` → `/data/mods/`, create `eula.txt=true`, write default `server.properties`
2. On subsequent starts → skip initialization (preserve user changes)
3. Execute Forge server JAR with configured JVM args

## Mod Selection

| Mod | Version | Purpose |
|-----|---------|---------|
| Forge | 49.x (latest stable) | Mod loader for 1.20.1 |
| Re-Avaritia | 1.3.9.5 | Core mod - Avaritia content |
| JEI | 15.x | Recipe viewer (server-side compatible) |
| ModernFix | latest 1.20.1 | Startup time and memory optimization |
| FerriteCore | latest 1.20.1 | RAM reduction (chunk storage compression) |
| FastSuite | latest 1.20.1 | Recipe loading speedup |

## Server Configuration

### server.properties defaults

```properties
gamemode=survival
difficulty=normal
view-distance=10
simulation-distance=8
max-players=20
enable-command-block=false
```

### JVM Flags (Aikar's)

```
-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200
-XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC
-XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40
-XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5
-XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15
-XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5
```

## Health Checks

- Docker healthcheck pings the Minecraft server via its query/RCon protocol
- Check interval: 60s, 3 consecutive failures = unhealthy
- Compose `restart: unless-stopped` handles crashes

## Error Handling

- Forge server exits non-zero → error logged to Docker logs, container stays alive for inspection
- Volume initialization is idempotent — never overwrites existing user data
- Stdout/stderr forwarded to Docker log driver

## Backup Strategy

Manual, not automated:
- `docker cp` for named volume data
- Alternatively, bind mount `/data` to host filesystem for direct access

## Out of Scope

- Automatic backups
- Multi-server orchestration
- Mod management UI
- Fabric support
- Custom modpack tooling (CurseForge launcher compatibility)
