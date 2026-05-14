# Stage 1: Builder — download Forge and mods
FROM eclipse-temurin:17-jdk AS builder

WORKDIR /build

# Install tools
RUN apt-get update && apt-get install -y wget unzip jq && rm -rf /var/lib/apt/lists/*

# Download Forge installer
ARG FORGE_VERSION=1.20.1-47.4.20
RUN wget -q "https://maven.minecraftforge.net/net/minecraftforge/forge/${FORGE_VERSION}/forge-${FORGE_VERSION}-installer.jar" -O forge-installer.jar

# Install Forge server (creates libraries/ and run script)
RUN java -jar forge-installer.jar --installServer && rm -f forge-installer.jar forge-installer.jar.log

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

# Stage 2: Runtime — minimal JRE with server files
FROM eclipse-temurin:17-jre

# Install iproute2 for ss command (used by healthcheck)
RUN apt-get update && apt-get install -y iproute2 bash && rm -rf /var/lib/apt/lists/*

WORKDIR /server

# Create non-root user
RUN useradd -m -s /bin/bash minecraft

# Copy server files from builder
COPY --from=builder /build/libraries /server/libraries
COPY --from=builder /build/user_jvm_args.txt /server/
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
