#!/bin/bash
# Ollama Vibe CLI Utilities

# ANSI color codes for terminal output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  Warning: $1${NC}"
}

print_error() {
  echo -e "${RED}❌ Error: $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

print_step() {
  echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}"
}

is_macos() {
  [[ "$OSTYPE" == "darwin"* ]]
}

is_linux() {
  [[ "$OSTYPE" == "linux"* ]]
}

is_homebrew_installed() {
  command -v brew &>/dev/null
}

is_ollama_installed() {
  command -v ollama &>/dev/null
}

is_podman_installed() {
  command -v podman &>/dev/null
}

get_shell_config_file() {
  if [[ -n "$SHELL" && "$SHELL" == *"zsh"* ]]; then
    echo "$HOME/.zshrc"
  else
    echo "$HOME/.bashrc"
  fi
}

get_ollama_origins() {
  echo "http://localhost http://localhost:* http://127.0.0.1 http://127.0.0.1:* http://0.0.0.0 http://0.0.0.0:* *"
}

get_ollama_host() {
  if is_macos; then
    # Use the gateway IP if available, otherwise fallback to host.containers.internal
    local gateway
    gateway=$(get_gateway_ip)
    if [[ -n "$gateway" ]]; then
      echo "$gateway"
    else
      echo "host.containers.internal"
    fi
  else
    echo "localhost"
  fi
}

get_host_ip() {
  if is_macos; then
    ifconfig en0 | grep 'inet ' | awk '{print $2}'
  else
    hostname -I | awk '{print $1}'
  fi
}

# Podman machine utility functions
is_podman_machine_exists() {
  local machine_name="$1"
  podman machine list 2>/dev/null | grep -q "$machine_name"
}

is_podman_machine_running() {
  local machine_name="$1"
  podman machine list 2>/dev/null | grep "$machine_name" | grep -q "currently running"
}

get_running_machine() {
  # Returns the name of the currently running machine, or empty string if none
  local running_info
  running_info=$(podman machine list 2>/dev/null | grep "currently running" || echo "")
  
  if [[ -n "$running_info" ]]; then
    echo "$running_info" | awk '{print $1}'
  else
    echo ""
  fi
}

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
    podman machine init "$machine_name" || return 1
  else
    print_info "Podman machine '$machine_name' already exists"
  fi
  
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
  
  return 0
}

get_gateway_ip() {
  if is_macos; then
    # First check which machine is running
    local running_machine
    running_machine=$(get_running_machine)
    
    if [[ -n "$running_machine" ]]; then
      # Use the running machine
      podman machine inspect "$running_machine" | grep -o '"Gateway": "[^"]*"' | head -1 | cut -d '"' -f 4
    else
      # Fallback to default
      podman machine inspect | grep -o '"Gateway": "[^"]*"' | head -1 | cut -d '"' -f 4
    fi
  else
    ip route | grep default | awk '{print $3}'
  fi
}
