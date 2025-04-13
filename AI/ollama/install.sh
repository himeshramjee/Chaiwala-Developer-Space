#!/bin/bash
# Ollama Vibe Installer
# This script installs and configures Ollama with coding-optimized LLM models.

set -e

# Import utilities and constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utilities/cli_utilities.sh"
source "$SCRIPT_DIR/utilities/constants.sh"
source "$SCRIPT_DIR/utilities/install_ollama.sh"
source "$SCRIPT_DIR/utilities/install_podman.sh"
source "$SCRIPT_DIR/utilities/install_openwebui.sh"

print_info "Script dir: ${SCRIPT_DIR}"

# Use ports from constants.sh
PODMAN_PORT=$OPENWEBUI_PORT

# Remove reference to the wrapper script - we'll start Ollama directly
OLLAMA_SERVE_SCRIPT=""

# Models to install - can be overridden with MODELS env var
if [[ -n "${MODELS}" ]]; then
  # Use the space-separated list from environment variable
  read -ra MODELS_ARRAY <<< "${MODELS}"
  print_info "Using custom model list: ${MODELS}"
else
  # Use default models from constants.sh
  MODELS_ARRAY=("${DEFAULT_MODELS[@]}")
fi

# Check system requirements
check_requirements() {
  print_step "Checking system requirements"

  if ! is_macos && ! is_linux; then
    print_error "Unsupported operating system. Only macOS and Linux are supported."
    exit 1
  fi

  print_success "Operating system check passed"
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
  
  # Create a version file to track what's been installed
  local version_file="$SCRIPT_DIR/.ollama_vibe_version"
  echo "# Ollama Vibe Installation" > "$version_file"
  echo "INSTALL_DATE=\"$(date)\"" >> "$version_file"
  echo "VERSION=\"1.0.0\"" >> "$version_file"
  
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
  print_info "Starting model installation..."
  local models_success=true
  if ! install_models; then
    models_success=false
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