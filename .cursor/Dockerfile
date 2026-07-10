# Optional base image for Cursor Cloud Agents (Godot 4.4 headless tests).
# Referenced only if you switch environment.json to use "build.dockerfile".
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV GODOT_VERSION=4.4-stable
ENV GODOT_ARCH=linux.x86_64

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    libfontconfig1 \
    libgl1 \
    libxcursor1 \
    libxinerama1 \
    libxrandr2 \
    libxi6 \
    libxrender1 \
    libxext6 \
    libx11-6 \
    libasound2t64 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/godot.zip \
      "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_${GODOT_ARCH}.zip" \
    && unzip -qo /tmp/godot.zip -d /usr/local/bin \
    && mv "/usr/local/bin/Godot_v${GODOT_VERSION}_${GODOT_ARCH}" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm -f /tmp/godot.zip

WORKDIR /workspace
