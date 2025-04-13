#!/bin/bash
# Ollama Vibe Uninstaller
# This script removes all components installed by the Ollama Vibe installer.

set -e

# Import utilities and constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utilities/cli_utilities.sh"
source "$SCRIPT_DIR/utilities/constants.sh"
source "$SCRIPT_DIR/utilities/install_podman.sh"

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
  
  # Ask about Ollama binary removal
  print_info "Ollama binary removal options:"
  print_info "1. Keep the Ollama binary (allows reinstallation without downloading)"
  print_info "2. Remove the Ollama binary (complete removal)"
  
  read -p "Select option [1-2] (default: 1): " binary_option
  
  if [[ "$binary_option" == "2" ]]; then
    if is_macos; then
      print_info "Removing Ollama binary..."
      if is_homebrew_installed && brew list --formula | grep -q "^ollama$"; then
        print_info "Uninstalling Ollama via Homebrew..."
        brew uninstall ollama 2>/dev/null || true
      else
        print_info "Removing Ollama binary file..."
        sudo rm -f /usr/local/bin/ollama 2>/dev/null || true
      fi
    else
      print_info "Removing Ollama binary..."
      sudo rm -f /usr/bin/ollama 2>/dev/null || true
    fi
    print_success "Ollama binary removed"
  else
    print_info "Keeping Ollama binary for future use"
  fi
  
  # Handle Ollama data with more options
  local ollama_dir="$HOME/.ollama"
  if [[ -d "$ollama_dir" ]]; then
    # Get model sizes to show user
    local models_size=0
    if [[ -d "$ollama_dir/models" ]]; then
      models_size=$(du -sh "$ollama_dir/models" 2>/dev/null | awk '{print $1}' || echo "unknown")
    fi
    
    print_info "Ollama data directory options:"
    print_info "1. Keep all Ollama data including downloaded models (${models_size})"
    print_info "2. Remove configuration but keep downloaded models"
    print_info "3. Remove everything (models, config, and all data)"
    
    read -p "Select option [1-3] (default: 1): " data_option
    
    case "$data_option" in
      "3")
        print_info "Removing all Ollama data ($ollama_dir)..."
        rm -rf "$ollama_dir" 2>/dev/null || true
        print_success "All Ollama data removed"
        ;;
      "2")
        # Keep models directory but remove other files/directories
        if [[ -d "$ollama_dir/models" ]]; then
          print_info "Keeping models but removing other Ollama data..."
          
          # Create temporary directory to hold models
          local temp_dir=$(mktemp -d)
          mv "$ollama_dir/models" "$temp_dir/" || true
          
          # Remove everything else
          rm -rf "$ollama_dir" 2>/dev/null || true
          
          # Recreate directory and move models back
          mkdir -p "$ollama_dir" || true
          mv "$temp_dir/models" "$ollama_dir/" || true
          rm -rf "$temp_dir" || true
          
          print_success "Ollama configuration removed, but models preserved"
        else
          print_info "No models directory found, removing all Ollama data..."
          rm -rf "$ollama_dir" 2>/dev/null || true
          print_success "All Ollama data removed"
        fi
        ;;
      *)
        print_info "Keeping all Ollama data in $ollama_dir"
        ;;
    esac
  fi
  
  # Remove Ollama startup script
  local ollama_wrapper="$SCRIPT_DIR/$OLLAMA_SERVE_SCRIPT"
  
  if [[ -f "$ollama_wrapper" ]]; then
    print_info "Removing Ollama startup script"
    rm -f "$ollama_wrapper" 2>/dev/null || true
    
    if [[ ! -f "$ollama_wrapper" ]]; then
      print_success "Ollama startup script removed"
    else
      print_warning "Failed to remove Ollama startup script"
    fi
  else
    print_info "No Ollama startup script found"
  fi
  
  print_success "Ollama removed"
}

# Ask about Podman removal
ask_remove_podman() {
  print_step "Podman Management Options"
  
  if ! is_podman_installed; then
    print_info "Podman is not installed. Skipping."
    return 0
  fi
  
  print_warning "Podman is likely used by other applications on your system."
  print_warning "Since we're using the default Podman machine, changing it might affect other applications."

  # Present multiple options for handling Podman
  print_info "Podman management options:"
  print_info "1. Keep Podman and all machines (no changes)"
  print_info "2. Stop Podman machines but keep Podman installed"
  print_info "3. Stop and remove Podman machines but keep Podman installed"
  print_info "4. Completely remove Podman (stops/removes machines and uninstalls Podman)"
  
  # Get user selection with default option 1
  read -p "Select an option [1-4] (default: 1): " podman_option
  
  # Default to option 1 if no selection
  podman_option=${podman_option:-1}
  
  case "$podman_option" in
    1)
      print_info "Keeping Podman and all machines unchanged"
      return 0
      ;;
    2)
      print_info "Stopping Podman machines but keeping Podman installed..."
      
      # Only stop containers and machines
      print_info "Stopping all running containers..."
      podman stop -a 2>/dev/null || true
      
      # Stop all machines
      local all_machines
      all_machines=$(podman machine list --format "{{.Name}}" 2>/dev/null)
      if [[ -n "$all_machines" ]]; then
        print_info "Found Podman machines: $all_machines"
        for machine in $all_machines; do
          print_info "Stopping Podman machine: $machine"
          podman machine stop "$machine" 2>/dev/null || true
        done
        print_success "Podman machines stopped"
      else
        print_info "No Podman machines found"
      fi
      ;;
    3)
      print_info "Stopping and removing Podman machines but keeping Podman installed..."
      
      # Stop all containers first
      print_info "Stopping all running containers..."
      podman ps -a
      podman stop -a 2>/dev/null || true
      
      # Stop and remove all machines
      local all_machines
      all_machines=$(podman machine list --format "{{.Name}}" 2>/dev/null | sed 's/\*$//' )
      if [[ -n "$all_machines" ]]; then
        print_info "Found Podman machines: $all_machines"
        for machine in $all_machines; do
          print_info "Stopping Podman machine: $machine"
          podman machine stop "$machine" 2>/dev/null || true
          
          # Confirm removal of each machine
          read -p "Remove Podman machine '$machine'? (Y/n): " remove_machine
          if [[ "$remove_machine" != "n" && "$remove_machine" != "N" ]]; then
            print_info "Removing Podman machine: $machine"
            podman machine rm -f "$machine" 2>/dev/null || true
          else
            print_info "Keeping Podman machine: $machine (stopped)"
          fi
        done
        print_success "Podman machines managed according to selection"
      else
        print_info "No Podman machines found"
      fi
      ;;
    4)
      print_info "Preparing to completely remove Podman..."
      
      # Double-check with user before proceeding with complete removal
      read -p "Are you ABSOLUTELY SURE? This will remove ALL Podman containers, machines and the application. (y/N): " confirm_again
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
        
        # Ask about keeping downloaded machine images
        print_info "Podman machine OS images are stored in ~/.local/share/containers/podman/machine/"
        print_info "These cached files can save time when reinstalling Podman in the future."
        read -p "Keep downloaded machine OS images (quay.io/podman/machine-os)? (Y/n): " keep_images
        
        if [[ "$keep_images" == "n" || "$keep_images" == "N" ]]; then
          print_info "Removing downloaded Podman machine images..."
          rm -rf ~/.local/share/containers/podman/machine/applehv 2>/dev/null || true
          rm -rf ~/.local/share/containers/podman/machine/qemu 2>/dev/null || true
          print_success "Downloaded machine images removed"
        else
          print_info "Keeping downloaded machine images for future use"
        fi
        
        print_info "Uninstalling Podman via Homebrew..."
        brew uninstall podman 2>/dev/null || true
      elif is_linux; then
        # For Linux, first remove all containers
        print_info "Stopping all containers..."
        podman stop -a 2>/dev/null || true
        
        # Ask about keeping downloaded machine images
        print_info "Podman machine OS images are stored in ~/.local/share/containers/podman/"
        print_info "These cached files can save time when reinstalling Podman in the future."
        read -p "Keep downloaded machine OS images? (Y/n): " keep_images
        
        if [[ "$keep_images" == "n" || "$keep_images" == "N" ]]; then
          print_info "Removing downloaded Podman machine images..."
          rm -rf ~/.local/share/containers/podman/ 2>/dev/null || true
          print_success "Downloaded machine images removed"
        else
          print_info "Keeping downloaded machine images for future use"
        fi
        
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
      print_success "Podman completely removed"
      ;;
    *)
      print_warning "Invalid option: $podman_option. Keeping Podman unchanged."
      return 0
      ;;
  esac
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
  
  # Check for version file to verify what was installed
  local version_file="$SCRIPT_DIR/.ollama_vibe_version"
  if [[ -f "$version_file" ]]; then
    print_info "Found installation record:"
    source "$version_file"
    print_info "Installed version: ${VERSION:-unknown}"
    print_info "Install date: ${INSTALL_DATE:-unknown}"
  else
    print_warning "No installation record found. Will attempt to remove components anyway."
  fi

  # Perform uninstallation steps
  remove_openwebui
  remove_ollama
  ask_remove_podman
  
  # Remove version file
  if [[ -f "$version_file" ]]; then
    rm -f "$version_file"
  fi
  
  print_success "Uninstallation completed!"
  print_info "Please restart your terminal or run 'source $(get_shell_config_file)' to apply changes."
}

# Run the main function
main "$@"