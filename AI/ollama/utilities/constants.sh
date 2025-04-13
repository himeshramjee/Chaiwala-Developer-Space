#!/bin/bash
# Ollama Vibe - Constants and Configuration

#----- Common Constants -----#

# Application Settings
OLLAMA_PORT="11434"
OLLAMA_HOST="0.0.0.0"  # Accept connections on all interfaces

# Container Settings
OPENWEBUI_CONTAINER_NAME="openwebui"
OPENWEBUI_PORT="8080"  # Main web interface port
OPENWEBUI_IMAGE="ghcr.io/open-webui/open-webui:latest"

# Podman Settings
PODMAN_MACHINE_NAME="podman-machine-default"

# Default models - essential coding models
declare -a DEFAULT_MODELS=(
  "qwen2.5-coder:14b"
  "codellama:7b"
  "deepseek-coder-v2:16b"
  "gemma3:12b"
  "llama3.3:70b"
)

# File paths
OLLAMA_SERVE_SCRIPT="ollama-serve.sh"