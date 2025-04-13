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

get_shell_config_file() {
  # First check for custom SHELL_CONFIG_FILE env var
  if [[ -n "$SHELL_CONFIG_FILE" ]]; then
    echo "$SHELL_CONFIG_FILE"
    return 0
  fi

  # Then check based on current shell
  if [[ -n "$SHELL" ]]; then
    if [[ "$SHELL" == *"zsh"* ]]; then
      echo "$HOME/.zshrc"
    elif [[ "$SHELL" == *"fish"* ]]; then
      echo "$HOME/.config/fish/config.fish"
    elif [[ "$SHELL" == *"bash"* ]]; then
      # Bash configuration differs by OS
      if is_macos; then
        if [[ -f "$HOME/.bash_profile" ]]; then
          echo "$HOME/.bash_profile"
        else
          echo "$HOME/.bashrc"
        fi
      else
        echo "$HOME/.bashrc"
      fi
    else
      # Default to bashrc for unknown shells
      echo "$HOME/.bashrc"
    fi
  else
    # SHELL is not set, try to determine from process
    if command -v fish &>/dev/null && pgrep -x "fish" >/dev/null; then
      echo "$HOME/.config/fish/config.fish"
    elif command -v zsh &>/dev/null && pgrep -x "zsh" >/dev/null; then
      echo "$HOME/.zshrc"
    else
      # Default to bashrc
      echo "$HOME/.bashrc"
    fi
  fi
}

get_ollama_origins() {
  echo "http://localhost http://localhost:* http://127.0.0.1 http://127.0.0.1:* http://0.0.0.0 http://0.0.0.0:* *"
}

get_ollama_host() {
  if is_macos; then
    # Import the podman utilities if not already loaded
    if [[ "${_PODMAN_UTILS_LOADED:-}" != "true" ]]; then
      source "$SCRIPT_DIR/utilities/install_podman.sh"
    fi
    
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
    # Try en0 first (most common for macOS)
    local ip
    ip=$(ifconfig en0 2>/dev/null | grep 'inet ' | awk '{print $2}')
    
    # If en0 doesn't work, try other common interfaces
    if [[ -z "$ip" ]]; then
      # Try en1 (often used for WiFi on some Macs)
      ip=$(ifconfig en1 2>/dev/null | grep 'inet ' | awk '{print $2}')
    fi
    
    # If still no IP, try all interfaces and take first one
    if [[ -z "$ip" ]]; then
      ip=$(ifconfig -a | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}')
    fi
    
    echo "$ip"
  else
    # For Linux, try hostname -I first
    if command -v hostname &>/dev/null; then
      local ip
      ip=$(hostname -I 2>/dev/null | awk '{print $1}')
      
      if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
      fi
    fi
    
    # Fallback to ip addr (more universal across Linux distros)
    if command -v ip &>/dev/null; then
      ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d/ -f1
    else
      # Last resort, try ifconfig
      ifconfig | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}'
    fi
  fi
}
