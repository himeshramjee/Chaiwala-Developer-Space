#!/bin/bash
# Ollama Vibe Uninstaller
# This script removes all components installed by the Ollama Vibe installer.

set -e

# Import utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utilities/cli_utilities.sh"

# Constants
OPENWEBUI_CONTAINER_NAME="openwebui"
PODMAN_MACHINE_NAME="podman-machine-default" # Use default machine

# Remove OpenWebUI container
remove_openwebui() {
  print_step "Removing OpenWebUI container"
  
  if podman ps -a --format "{{.Names}}" | grep -q "^${OPENWEBUI_CONTAINER_NAME}$"; then
    print_info "Stopping and removing OpenWebUI container..."
    podman stop "$OPENWEBUI_CONTAINER_NAME" 2>/dev/null || true
    podman rm -f "$OPENWEBUI_CONTAINER_NAME" 2>/dev/null || true
    print_success "OpenWebUI container removed"
  else
    print_info "OpenWebUI container not found. Skipping."
  fi
}

# Remove Ollama and configuration
remove_ollama() {
  print_step "Removing Ollama"
  
  # Stop Ollama service
  if pgrep -x "ollama" > /dev/null; then
    print_info "Stopping Ollama service..."
    if is_macos; then
      killall ollama 2>/dev/null || true
    else
      sudo systemctl stop ollama 2>/dev/null || true
      killall ollama 2>/dev/null || true
    fi
  fi
  
  # Remove Ollama binary
  if is_macos; then
    print_info "Removing Ollama binary..."
    sudo rm -f /usr/local/bin/ollama 2>/dev/null || true
  else
    print_info "Removing Ollama binary..."
    sudo rm -f /usr/bin/ollama 2>/dev/null || true
  fi
  
  # Remove Ollama data
  local ollama_dir="$HOME/.ollama"
  if [[ -d "$ollama_dir" ]]; then
    print_warning "This will remove all Ollama models and data from $ollama_dir"
    read -p "Continue? (y/N): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
      print_info "Removing Ollama data directory..."
      rm -rf "$ollama_dir" 2>/dev/null || true
      print_success "Ollama data removed"
    else
      print_info "Skipping Ollama data removal"
    fi
  fi
  
  # Remove environment variables
  local config_file
  config_file=$(get_shell_config_file)
  
  print_info "Removing environment variables from $config_file"
  sed -i.bak '/export OLLAMA_ORIGINS=/d' "$config_file" 2>/dev/null || true
  sed -i.bak '/export OLLAMA_HOST=/d' "$config_file" 2>/dev/null || true
  
  print_success "Ollama removed"
}

# Ask about Podman removal
ask_remove_podman() {
  print_step "Podman Removal Options"
  
  if ! is_podman_installed; then
    print_info "Podman is not installed. Skipping."
    return 0
  fi
  
  print_warning "Podman is likely used by other applications on your system."
  print_warning "Since we're using the default Podman machine, removing it might affect other applications."
  read -p "Do you want to completely remove Podman from your system? (y/N): " confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    # Double-check with user before proceeding with removal
    read -p "Are you ABSOLUTELY SURE? This will remove ALL Podman containers and machines. (y/N): " confirm_again
    if [[ "$confirm_again" != "y" && "$confirm_again" != "Y" ]]; then
      print_info "Podman removal cancelled"
      return 0
    fi
    
    if is_macos; then
      print_info "Stopping and removing Podman machines..."
      
      # Get list of running containers first
      print_info "Listing all running containers:"
      podman ps -a
      
      # Stop all containers first
      print_info "Stopping all containers..."
      podman stop -a 2>/dev/null || true
      
      # Stop and remove all machines
      local all_machines
      all_machines=$(podman machine list --format "{{.Name}}" 2>/dev/null)
      if [[ -n "$all_machines" ]]; then
        print_info "Found Podman machines: $all_machines"
        for machine in $all_machines; do
          print_info "Stopping Podman machine: $machine"
          podman machine stop "$machine" 2>/dev/null || true
          print_info "Removing Podman machine: $machine"
          podman machine rm -f "$machine" 2>/dev/null || true
        done
      else
        print_info "No Podman machines found"
      fi
      
      print_info "Uninstalling Podman via Homebrew..."
      brew uninstall podman 2>/dev/null || true
    elif is_linux; then
      # For Linux, first remove all containers
      print_info "Stopping all containers..."
      podman stop -a 2>/dev/null || true
      
      if command -v apt-get &>/dev/null; then
        print_info "Removing Podman via apt..."
        sudo apt-get remove -y podman 2>/dev/null || true
      elif command -v dnf &>/dev/null; then
        print_info "Removing Podman via dnf..."
        sudo dnf remove -y podman 2>/dev/null || true
      else
        print_warning "Unsupported Linux distribution. Please remove Podman manually."
      fi
    fi
    print_success "Podman removed"
  else
    print_info "Skipping Podman removal"
  fi
}

# Main uninstallation function
main() {
  print_step "Ollama Vibe Uninstallation"
  print_info "This script will remove components installed by Ollama Vibe."
  
  read -p "Continue with uninstallation? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_info "Uninstallation cancelled."
    exit 0
  fi
  
  # Perform uninstallation steps
  remove_openwebui
  remove_ollama
  ask_remove_podman
  
  print_success "Uninstallation completed!"
  print_info "Please restart your terminal or run 'source $(get_shell_config_file)' to apply changes."
}

# Run the main function
main "$@"