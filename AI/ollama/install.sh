#!/bin/bash
# Ollama Vibe Installer
# This script installs and configures Ollama with coding-optimized LLM models.

set -e

# Import utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utilities/cli_utilities.sh"

# Models to install - can be overridden with MODELS env var
if [[ -n "${MODELS}" ]]; then
  # Use the space-separated list from environment variable
  read -ra MODELS_ARRAY <<< "${MODELS}"
  print_info "Using custom model list: ${MODELS}"
else
  # Default models
  MODELS_ARRAY=(
    "qwen2.5-coder:14b"
    "codellama:7b",
    "codellama:13b",
    "deepcoder:14b",
    "gemma3:12b",
    "llama3.3:70b"
  )
fi

# Constants
OPENWEBUI_CONTAINER_NAME="openwebui"
PODMAN_PORT=${OPENWEBUI_PORT:-"3000"}  # Use environment variable or default to 3000
OLLAMA_PORT="11434"
PODMAN_MACHINE_NAME="podman-machine-default" # Use the default machine name instead of custom

# Check system requirements
check_requirements() {
  print_step "Checking system requirements"

  if ! is_macos && ! is_linux; then
    print_error "Unsupported operating system. Only macOS and Linux are supported."
    exit 1
  fi

  print_success "Operating system check passed"
}

# Install Ollama
install_ollama() {
  print_step "Installing Ollama"

  if is_ollama_installed; then
    print_info "Ollama is already installed. Skipping installation."
    return 0
  fi

  print_info "Downloading and installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
  
  if ! is_ollama_installed; then
    print_error "Failed to install Ollama."
    exit 1
  fi

  print_success "Ollama installed successfully!"

  # Configure environment variables
  setup_ollama_environment
}

# Configure Ollama environment variables
setup_ollama_environment() {
  print_step "Configuring Ollama"
  
  local config_file
  config_file=$(get_shell_config_file)
  
  # Check if OLLAMA_ORIGINS is already set
  if ! grep -q "export OLLAMA_ORIGINS" "$config_file"; then
    print_info "Setting OLLAMA_ORIGINS in $config_file"
    echo "export OLLAMA_ORIGINS=\"$(get_ollama_origins)\"" >> "$config_file"
  fi
  
  # Check if OLLAMA_HOST is already set
  if ! grep -q "export OLLAMA_HOST" "$config_file"; then
    print_info "Setting OLLAMA_HOST in $config_file"
    echo "export OLLAMA_HOST=\"0.0.0.0\"" >> "$config_file"
  fi
  
  print_info "Environment variables set. Please restart your terminal or run 'source $config_file'"
  print_success "Ollama configuration complete"
}

# Install Podman (required for OpenWebUI)
install_podman() {
  print_step "Installing Podman"

  if is_podman_installed; then
    print_info "Podman is already installed. Skipping installation."
    return 0
  fi

  if is_macos; then
    if ! is_homebrew_installed; then
      print_error "Homebrew is required to install Podman on macOS."
      print_info "Please install Homebrew first: https://brew.sh"
      exit 1
    fi

    print_info "Installing Podman via Homebrew..."
    brew install podman
  elif is_linux; then
    if command -v apt-get &>/dev/null; then
      print_info "Installing Podman via apt..."
      sudo apt-get update
      sudo apt-get install -y podman
    elif command -v dnf &>/dev/null; then
      print_info "Installing Podman via dnf..."
      sudo dnf install -y podman
    else
      print_error "Unsupported Linux distribution. Please install Podman manually."
      exit 1
    fi
  fi

  if ! is_podman_installed; then
    print_error "Failed to install Podman."
    exit 1
  fi

  # Initialize Podman machine on macOS
  if is_macos; then
    print_step "Setting up Podman machine"
    setup_podman_machine "$PODMAN_MACHINE_NAME" || {
      print_error "Failed to set up Podman machine"
      exit 1
    }
  fi

  print_success "Podman installed successfully!"
}

# Install OpenWebUI
install_openwebui() {
  print_step "Installing OpenWebUI"

  # Turn off exit on error temporarily for this function
  set +e
  
  # Debug: Print current Podman status
  print_info "Current Podman status:"
  podman ps -a || print_warning "Failed to list Podman containers"
  
  # Check if the container already exists
  if podman ps -a --format "{{.Names}}" | grep -q "^${OPENWEBUI_CONTAINER_NAME}$"; then
    print_info "OpenWebUI container already exists. Removing existing container..."
    
    # Step 1: Stop the container with detailed output
    print_info "Stopping container..."
    podman stop "$OPENWEBUI_CONTAINER_NAME"
    stop_result=$?
    if [ $stop_result -ne 0 ]; then
      print_warning "Failed to stop container (code: $stop_result), but continuing..."
    fi
    sleep 2  # Give it a moment to stop
    
    # Step 2: Remove the container with detailed output
    print_info "Removing container..."
    podman rm -f "$OPENWEBUI_CONTAINER_NAME" 
    rm_result=$?
    if [ $rm_result -ne 0 ]; then
      print_warning "Failed to remove container (code: $rm_result), but continuing..."
    fi
    sleep 2  # Give it a moment to remove
    
    # Debug: Verify removal
    if podman ps -a --format "{{.Names}}" | grep -q "^${OPENWEBUI_CONTAINER_NAME}$"; then
      print_warning "Container still exists after removal attempt. Will try to overwrite."
    else
      print_success "Container removed successfully"
    fi
  fi

  # Check for any container using our target port
  local port_check
  port_check=$(podman ps --format "{{.Names}}" -f "publish=${PODMAN_PORT}" 2>/dev/null)
  if [[ -n "$port_check" ]]; then
    print_warning "Port ${PODMAN_PORT} is already in use by container: $port_check"
    print_info "Stopping and removing conflicting container..."
    podman stop "$port_check" 
    sleep 2
    podman rm -f "$port_check"
    sleep 2
    
    # Debug: Verify removal
    if podman ps --format "{{.Names}}" -f "publish=${PODMAN_PORT}" 2>/dev/null | grep -q .; then
      print_warning "Port ${PODMAN_PORT} is still occupied by a container. Will try alternate port."
      PODMAN_PORT="3100"  # Try alternate port
      print_info "Using alternate port: ${PODMAN_PORT}"
    fi
  fi
  
  # Check for processes using our port (if lsof is available)
  if command -v lsof &>/dev/null; then
    if lsof -i ":${PODMAN_PORT}" &>/dev/null; then
      print_warning "Port ${PODMAN_PORT} is already in use by another process"
      lsof -i ":${PODMAN_PORT}" || true
      
      # Automatically use alternate port
      print_info "Using alternate port 3100"
      PODMAN_PORT="3100"
      
      # Check if the alternate port is also in use
      if lsof -i ":${PODMAN_PORT}" &>/dev/null; then
        print_error "Alternate port ${PODMAN_PORT} is also in use."
        print_info "Please free up ports or specify a different port with OPENWEBUI_PORT=XXXX"
        return 1
      fi
    fi
  else
    print_warning "lsof command not found - unable to check for port conflicts"
  fi
  
  # Ensure podman machine is running (macOS)
  if is_macos; then
    print_info "Ensuring Podman machine is running..."
    if ! setup_podman_machine "$PODMAN_MACHINE_NAME"; then
      print_error "Failed to ensure Podman machine is running properly"
      return 1
    fi
    # Give a moment for the machine to fully initialize
    sleep 5
  fi
  
  # Get proper configuration based on OS
  local host_ip
  host_ip=$(get_host_ip)
  print_info "Host IP: $host_ip"
  
  local ollama_host
  if [[ -n "${OLLAMA_GATEWAY_IP}" ]]; then
    # Use the manually provided gateway IP if specified
    ollama_host="${OLLAMA_GATEWAY_IP}"
    print_info "Using manually specified Ollama host: $ollama_host"
  elif is_macos; then
    # For macOS, we need the podman gateway IP
    local gateway_ip
    gateway_ip=$(get_gateway_ip)
    ollama_host="${gateway_ip:-$(get_ollama_host)}"
    print_info "Using macOS configuration with Ollama host: $ollama_host"
  else
    # For Linux, localhost should work
    ollama_host="localhost"
    print_info "Using Linux configuration with Ollama host: $ollama_host"
  fi

  # Pull the image first to ensure we have the latest version
  print_info "Pulling OpenWebUI image..."
  podman pull ghcr.io/open-webui/open-webui:latest
  pull_result=$?
  if [ $pull_result -ne 0 ]; then
    print_error "Failed to pull OpenWebUI image (code: $pull_result). Check network connection."
    return 1
  fi
  
  print_info "Running OpenWebUI container on port ${PODMAN_PORT}..."
  
  # Show the exact command we're running for debugging
  print_info "Running: podman run -d --name \"$OPENWEBUI_CONTAINER_NAME\" -p \"${PODMAN_PORT}:3000\" -p \"3001:3001\" -e \"OLLAMA_API_BASE_URL=http://${ollama_host}:${OLLAMA_PORT}\" --restart always ghcr.io/open-webui/open-webui:latest"
  
  # Run the container
  podman run -d \
    --name "$OPENWEBUI_CONTAINER_NAME" \
    -p "${PODMAN_PORT}:3000" \
    -p "3001:3001" \
    -e "OLLAMA_API_BASE_URL=http://${ollama_host}:${OLLAMA_PORT}" \
    --restart always \
    ghcr.io/open-webui/open-webui:latest
  
  # Capture the result
  run_result=$?
  
  # Check the result
  if [ $run_result -ne 0 ]; then
    print_error "Failed to run OpenWebUI container. Error code: $run_result"
    
    # Provide more detailed debugging
    print_info "Debugging information:"
    podman ps -a
    print_info "Checking for errors in the logs:"
    podman logs "$OPENWEBUI_CONTAINER_NAME" 2>&1 || true
    
    # Try running with a simplified command as fallback
    print_info "Trying simplified container command as fallback..."
    podman run -d \
      --name "${OPENWEBUI_CONTAINER_NAME}_simple" \
      -p "${PODMAN_PORT}:3000" \
      -e "OLLAMA_API_BASE_URL=http://${ollama_host}:${OLLAMA_PORT}" \
      ghcr.io/open-webui/open-webui:latest
      
    if [ $? -eq 0 ]; then
      print_success "Fallback container started successfully!"
      OPENWEBUI_CONTAINER_NAME="${OPENWEBUI_CONTAINER_NAME}_simple"
    else
      return 1
    fi
  fi

  # Verify the container is running
  if ! podman ps | grep -q "$OPENWEBUI_CONTAINER_NAME"; then
    print_error "Failed to start OpenWebUI container. Checking logs:"
    podman logs "$OPENWEBUI_CONTAINER_NAME" 2>&1 || true
    return 1
  fi

  # Turn exit on error back on
  set -e

  print_success "OpenWebUI deployed successfully!"
  print_info "Access the WebUI at http://localhost:${PODMAN_PORT}"
}

# Download and install LLM models
install_models() {
  print_step "Installing LLM models"

  # Make sure Ollama service is running
  if ! pgrep -x "ollama" > /dev/null; then
    print_info "Starting Ollama service..."
    if is_macos; then
      ollama serve > /dev/null 2>&1 &
    else
      sudo systemctl start ollama || ollama serve > /dev/null 2>&1 &
    fi
    # Wait for service to start
    sleep 5
  fi

  for model in "${MODELS_ARRAY[@]}"; do
    print_info "Pulling model: $model"
    ollama pull "$model"
    pull_result=$?
    if [ $pull_result -ne 0 ]; then
      print_error "Failed to pull mode: ${model}. Error code: $pull_result"
    fi
  done

  print_success "All models installed successfully!"
}

# Show usage information
show_usage() {
  print_step "Installation Complete"
  
  print_info "Ollama Vibe has been successfully installed!"
  print_info "- Ollama is available on port $OLLAMA_PORT"
  print_info "- OpenWebUI is available at http://localhost:$PODMAN_PORT"
  print_info "- Installed models: ${MODELS_ARRAY[*]}"
  print_info ""
  print_info "You can use these models directly via terminal with:"
  print_info "  ollama run codellama:7b"
  print_info "Or access them through the OpenWebUI interface."
}

# Main installation function
main() {
  print_step "Ollama Vibe Installation"
  print_info "This script will install Ollama, Podman, OpenWebUI, and code-optimized LLM models."
  
  # Perform installation steps with error handling
  check_requirements || { 
    print_error "System requirements check failed"
    exit 1
  }
  
  install_ollama || {
    print_error "Ollama installation failed"
    exit 1
  }
  
  install_podman || {
    print_error "Podman installation failed"
    exit 1
  }
  
  # OpenWebUI installation - this can fail but we can still continue
  if ! install_openwebui; then
    print_warning "OpenWebUI installation failed, but continuing with model installation"
    read -p "Do you want to continue without OpenWebUI? (Y/n): " continue_without_webui
    if [[ "$continue_without_webui" == "n" || "$continue_without_webui" == "N" ]]; then
      print_error "Installation aborted by user"
      exit 1
    fi
  fi
  
  # Model installation
  if ! install_models; then
    print_warning "Some models failed to install"
    read -p "Do you want to continue anyway? (Y/n): " continue_without_models
    if [[ "$continue_without_models" == "n" || "$continue_without_models" == "N" ]]; then
      print_error "Installation aborted by user"
      exit 1
    fi
  fi
  
  show_usage
  print_success "Installation completed successfully!"
}

# Enable better error tracing
trap 'echo "Error at line $LINENO: $BASH_COMMAND"' ERR

# Run the main function
main "$@"