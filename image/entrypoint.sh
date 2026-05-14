#!/bin/sh
set -e

# Initialize /data on first run
if [ ! -f /data/server.properties ]; then
    echo "=== First run: initializing server data ==="
    mkdir -p /data/mods
    cp /defaults/mods/* /data/mods/ 2>/dev/null || true

    # Symlink libraries so Forge can find them from /data
    ln -sf /server/libraries /data/libraries

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

# Ensure libraries symlink exists (re-create if missing)
if [ ! -d /data/libraries ]; then
    ln -sf /server/libraries /data/libraries
fi

# Set memory limits from env or default
MIN_RAM=${MIN_RAM:-2G}
MAX_RAM=${MAX_RAM:-4G}

FORGE_ARGS="@libraries/net/minecraftforge/forge/1.20.1-47.4.20/unix_args.txt"

echo "Starting Forge server with ${MAX_RAM} max RAM..."
cd /data
exec java -Xms${MIN_RAM} -Xmx${MAX_RAM} \
    -XX:+UseG1GC \
    -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+DisableExplicitGC \
    -XX:+AlwaysPreTouch \
    -XX:G1NewSizePercent=30 \
    -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M \
    -XX:G1ReservePercent=20 \
    -XX:G1HeapWastePercent=5 \
    -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    ${FORGE_ARGS} nogui
