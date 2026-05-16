#!/bin/sh
set -e

echo "=== Initializing Minecraft server ==="

# Ensure PVC directories exist
mkdir -p /data/world /data/logs

# Remove any pre-existing real directories so symlinks work correctly
rm -rf /server/world /server/logs

# Symlink world and logs to PVC
ln -sfn /data/world /server/world
ln -sfn /data/logs /server/logs

# Apply config: prefer /config overrides, else write defaults
apply_config() {
    local file=$1
    if [ -f "/config/${file}" ]; then
        echo "Using ConfigMap override for ${file}"
        cp "/config/${file}" "/server/${file}"
    elif [ ! -f "/server/${file}" ]; then
        echo "Writing default ${file}"
        write_default "${file}"
    fi
}

write_default() {
    local file=$1
    case "${file}" in
        server.properties)
            cat > /server/server.properties << 'PROPS'
enable-jmx-monitoring=false
rcon.port=25575
level-seed=
gamemode=creative
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
            ;;
        ops.json)
            cat > /server/ops.json << 'OPS'
[
  {
    "uuid": "94a648c3-b81a-4ff1-878f-30a88694a59c",
    "name": "hektor7591",
    "level": 4,
    "bypassesPlayerLimit": false
  }
]
OPS
            ;;
        eula.txt)
            echo "eula=true" > /server/eula.txt
            ;;
    esac
}

apply_config server.properties
apply_config ops.json
apply_config eula.txt

# Set memory limits from env or default
MIN_RAM=${MIN_RAM:-2G}
MAX_RAM=${MAX_RAM:-4G}

FORGE_ARGS="@libraries/net/minecraftforge/forge/1.20.1-47.4.20/unix_args.txt"

echo "Starting Forge server with ${MAX_RAM} max RAM..."
cd /server
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
