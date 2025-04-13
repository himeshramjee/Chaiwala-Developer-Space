#!/bin/bash
# Ollama Vibe - Podman Installation Functions

# Guard against multiple sourcing
if [[ "${BASH_SOURCE[0]}" != "${0}" && "${_PODMAN_UTILS_LOADED:-}" == "true" ]]; then
  return 0
fi
export _PODMAN_UTILS_LOADED=true

# Check if Podman is already installed
is_podman_installed() {
  command -v podman &>/dev/null
}

# Check if a specific Podman machine exists
is_podman_machine_exists() {
  local machine_name="$1"
  podman machine list 2>/dev/null | grep -q "$machine_name"
}

# Check if a specific Podman machine is running
is_podman_machine_running() {
  local machine_name="$1"
  podman machine list 2>/dev/null | grep "$machine_name" | grep -i -q "running"
}

# Get the name of the currently running Podman machine
get_running_machine() {
  # Returns the name of the currently running machine, or empty string if none
  local running_info
  running_info=$(podman machine list 2>/dev/null | grep -i "running" || echo "")
  
  if [[ -n "$running_info" ]]; then
    # Remove trailing asterisk if present
    machine_name=$(echo "$running_info" | awk '{print $1}' | sed 's/\*$//')
    echo "$machine_name"
  else
    echo ""
  fi
}

# Create or recreate a Podman machine with custom configuration
create_podman_machine() {
  local machine_name="$1"
  
  # Get CPU and memory settings based on system
  local cpus memory
  cpus=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
  memory=$(($(sysctl -n hw.memsize 2>/dev/null || echo 8589934592) / 1024 / 1024 / 2))  # Half of system memory in MiB
  
  # Initialize with optimized settings
  print_info "Initializing Podman machine with optimized settings..."
  print_info "CPUs: $cpus, Memory: ${memory}MiB"
  
  # Create the machine with standard parameters (no template file)
  podman machine init --now \
    --cpus "$cpus" \
    --memory "$memory" \
    --disk-size 100 \
    "$machine_name" || {
    print_error "Failed to create Podman machine"
    return 1
  }
  
  print_success "Podman machine created successfully"
  return 0
}

# Core function to set up and manage Podman machines
setup_podman_machine() {
  local machine_name="$1"
  
  # First check if any machine is running - Podman on macOS only supports one active VM
  local running_machine
  running_machine=$(get_running_machine)
  
  if [[ -n "$running_machine" ]]; then
    # A machine is running - print info and use it
    print_info "Podman machine '$running_machine' is already running"
    
    if [[ "$running_machine" != "$machine_name" ]]; then
      print_info "Using existing running machine instead of requested '$machine_name'"
    fi

    # Return success - we have a running machine we can use
    return 0
  fi

  # No machine is running, so continue with normal flow
  if ! is_podman_machine_exists "$machine_name"; then
    print_info "Creating Podman machine: $machine_name"
    create_podman_machine "$machine_name" || {
      print_error "Failed to create Podman machine"
      return 1
    }
  else
    print_info "Podman machine '$machine_name' already exists"
  
    # Check if it's running before trying to start it
    if is_podman_machine_running "$machine_name"; then
      print_info "Podman machine '$machine_name' is already running"
    else
      print_info "Starting Podman machine: $machine_name"
      
      # Try to start the machine, capture output for error handling
      local start_output
      start_output=$(podman machine start "$machine_name" 2>&1) || {
        # Special case: handle "already running" as success
        if [[ "$start_output" == *"already running"* ]]; then
          print_info "Machine is already running (according to error message)"
          return 0
        else
          print_error "Failed to start Podman machine: $start_output"
          return 1
        fi
      }
    fi
    
    # Double check it's really running
    if ! is_podman_machine_running "$machine_name"; then
      print_error "Machine should be running but isn't according to 'podman machine list'"
      return 1
    fi
    
    print_success "Podman machine is running and ready to use"
  fi
  
  return 0
}

# Function to handle recreation of problematic Podman machines
recreate_podman_machine() {
  local machine_name="$1"
  
  print_info "Stopping and removing existing Podman machine..."
  podman machine stop "$machine_name" || true
  podman machine rm -f "$machine_name" || {
    print_error "Failed to remove existing Podman machine"
    return 1
  }
  
  # Create a new machine with optimized settings
  create_podman_machine "$machine_name" || {
    print_error "Failed to recreate Podman machine"
    return 1
  }
  
  return 0
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
    
    # Check if machine exists, if not create one
    if ! is_podman_machine_exists "$PODMAN_MACHINE_NAME"; then
      create_podman_machine "$PODMAN_MACHINE_NAME" || {
        print_error "Failed to create Podman machine"
        exit 1
      }
    else
      # If machine exists, start it and configure networking
      setup_podman_machine "$PODMAN_MACHINE_NAME" || {
        print_error "Failed to set up Podman machine"
        exit 1
      }
    fi
  fi

  print_success "Podman installed successfully!"
  return 0
}