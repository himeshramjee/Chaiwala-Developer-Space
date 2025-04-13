#!/bin/bash
# OpenWebUI Connection Diagnostic Script
# This script helps diagnose "Connection Reset" errors when connecting to OpenWebUI

set -e

# Import utilities and constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utilities/cli_utilities.sh"
source "$SCRIPT_DIR/../utilities/constants.sh"
source "$SCRIPT_DIR/../utilities/install_podman.sh"

# Use ports from constants.sh directly
# No environment variable processing

# Print version information
print_info "Ollama version information:"
ollama -v || echo "Ollama not found"

print_step "OpenWebUI Connection Diagnostics"
print_info "This script will help diagnose OpenWebUI connection issues."

# Check if Podman is running
print_step "Checking Podman Status"
if ! command -v podman &>/dev/null; then
  print_error "Podman is not installed. Please install Podman first."
  exit 1
fi

# Check if a Podman machine exists and is running (macOS only)
if is_macos; then
  print_info "Checking Podman machine status on macOS..."
  
  # List all machines and their status
  print_info "Podman machines:"
  podman machine list || print_warning "Failed to list Podman machines"
  
  # Check if any machine is running
  running_machine=$(get_running_machine)
  if [[ -z "$running_machine" ]]; then
    print_error "No Podman machine is running. Start one with: podman machine start podman-machine-default"
    exit 1
  else
    print_success "Podman machine '$running_machine' is running"
  fi
  
  # Get and display the gateway IP
  gateway_ip=$(get_gateway_ip)
  if [[ -n "$gateway_ip" ]]; then
    print_info "Podman gateway IP: $gateway_ip"
  else 
    print_warning "Could not determine Podman gateway IP"
  fi
  
  # Podman machine networking info
  print_info "Podman uses host.containers.internal for container-to-host communication"
  
  # Just get host IP in case needed for diagnosis
  host_ip=$(get_host_ip)
  print_info "Host IP (for reference): $host_ip"
  
  # Check in the actual container if it exists
  if podman ps --format "{{.Names}}" | grep -q "^${OPENWEBUI_CONTAINER_NAME}$"; then
    print_info "Testing host.containers.internal resolution inside the OpenWebUI container..."
    host_resolution=$(podman exec "$OPENWEBUI_CONTAINER_NAME" getent hosts host.containers.internal 2>/dev/null || echo "Not found")
    if [[ "$host_resolution" == *"Not found"* ]]; then
      print_warning "host.containers.internal cannot be resolved inside the OpenWebUI container"
      print_info "This may cause connection issues between OpenWebUI and Ollama"
    else
      print_success "host.containers.internal resolves to: $host_resolution in the OpenWebUI container"
    fi
  fi
fi

# Check if the container exists and is running
print_step "Checking OpenWebUI Container"
if ! podman ps -a --format "{{.Names}}" | grep -q "^${OPENWEBUI_CONTAINER_NAME}$"; then
  print_error "OpenWebUI container does not exist. Run the installer script first."
  exit 1
fi

# Check container status
container_status=$(podman ps --format "{{.Status}}" -f "name=${OPENWEBUI_CONTAINER_NAME}" 2>/dev/null)
if [[ -z "$container_status" ]]; then
  print_error "OpenWebUI container exists but is not running."
  print_info "Start it with: podman start $OPENWEBUI_CONTAINER_NAME"
  exit 1
else
  print_success "OpenWebUI container is running: $container_status"
fi

# Check port forwarding setup
print_step "Checking Port Forwarding"
port_mapping=$(podman port "$OPENWEBUI_CONTAINER_NAME" 2>/dev/null)
if ! echo "$port_mapping" | grep -q "3000/tcp -> 0.0.0.0:${OPENWEBUI_PORT}"; then
  print_warning "Port forwarding may be misconfigured:"
  echo "$port_mapping"
else
  print_success "Port forwarding is correctly configured: ${port_mapping}"
fi

# Check for port conflicts 
print_info "Checking for port conflicts on ${OPENWEBUI_PORT}..."
if command -v lsof &>/dev/null; then
  lsof_result=$(lsof -i ":${OPENWEBUI_PORT}" 2>/dev/null)
  if [[ -n "$lsof_result" ]]; then
    print_warning "Port ${OPENWEBUI_PORT} is being used by multiple processes:"
    echo "$lsof_result"
  fi
else
  print_info "lsof not available, skipping port conflict check"
fi

# Check Ollama connectivity
print_step "Checking Ollama Connectivity"

# First check if Ollama is running
print_info "Checking if Ollama service is running..."
if command -v pgrep &>/dev/null && pgrep -x "ollama" > /dev/null; then
  print_success "Ollama service is running"
else
  print_warning "Ollama service may not be running"
  print_info "Try starting it with: OLLAMA_HOST=0.0.0.0:${OLLAMA_PORT} ollama serve"
fi

# Check Ollama API connectivity
print_info "Testing Ollama API access..."
ollama_host="localhost"
curl_cmd="curl -s -o /dev/null -w '%{http_code}' http://${ollama_host}:${OLLAMA_PORT}/api/tags"

if command -v curl &>/dev/null; then
  http_code=$(eval "$curl_cmd" 2>/dev/null || echo "failed")
  if [[ "$http_code" == "200" ]]; then
    print_success "Successfully connected to Ollama API"
  else
    print_error "Failed to connect to Ollama API (Status: $http_code)"
    print_info "Testing alternate host addresses..."
    
    # Try alternate addressing methods
    if is_macos; then
      gateway_ip=$(get_gateway_ip)
      if [[ -n "$gateway_ip" ]]; then
        print_info "Testing Podman gateway IP: $gateway_ip"
        http_code=$(curl -s -o /dev/null -w '%{http_code}' http://${gateway_ip}:${OLLAMA_PORT}/api/tags 2>/dev/null || echo "failed")
        if [[ "$http_code" == "200" ]]; then
          print_success "Successfully connected to Ollama API via gateway IP"
          print_info "Use OLLAMA_GATEWAY_IP=$gateway_ip with the install script"
        fi
      fi
    fi
  fi
else
  print_warning "curl not available, cannot test Ollama API connectivity"
fi

# Check OpenWebUI logs
print_step "Checking OpenWebUI Logs"
print_info "Last 20 lines of OpenWebUI container logs:"

# Get container ID to avoid logs error when run remotely
container_id=$(podman ps -q --filter "name=$OPENWEBUI_CONTAINER_NAME" 2>/dev/null)
if [[ -n "$container_id" ]]; then
  podman logs "$container_id" --tail 20 || print_warning "Failed to get container logs"
else
  print_warning "Container ID not found for $OPENWEBUI_CONTAINER_NAME, unable to get logs"
fi

# Check environment variables in container
print_step "Checking Container Environment"
print_info "OpenWebUI container environment variables:"
env_vars=$(podman exec "$OPENWEBUI_CONTAINER_NAME" env 2>/dev/null || echo "Failed to get environment variables")
echo "$env_vars" | grep -i ollama || print_warning "No Ollama-related environment variables found"

# Check OpenWebUI connectivity
print_step "Testing OpenWebUI Connectivity"
print_info "Testing connection to OpenWebUI on port ${OPENWEBUI_PORT}..."

if command -v curl &>/dev/null; then
  # Test with both localhost and 127.0.0.1 (they can behave differently)
  print_info "Testing with localhost..."
  localhost_code=$(curl -v -s -o /dev/null -w '%{http_code}' http://localhost:${OPENWEBUI_PORT} 2>&1 || echo "failed")
  
  print_info "Testing with 127.0.0.1..."
  ip_code=$(curl -v -s -o /dev/null -w '%{http_code}' http://127.0.0.1:${OPENWEBUI_PORT} 2>&1 || echo "failed")
  
  # Test with actual host IP
  host_ip=$(get_host_ip)
  print_info "Testing with host IP (${host_ip})..."
  host_ip_code=$(curl -v -s -o /dev/null -w '%{http_code}' http://${host_ip}:${OPENWEBUI_PORT} 2>&1 || echo "failed")
  
  # Record success of any method
  if [[ "$localhost_code" == "200" || "$localhost_code" == "301" || "$localhost_code" == "302" ]]; then
    print_success "Successfully connected via localhost"
    success=true
  elif [[ "$ip_code" == "200" || "$ip_code" == "301" || "$ip_code" == "302" ]]; then
    print_success "Successfully connected via 127.0.0.1"
    success=true
  elif [[ "$host_ip_code" == "200" || "$host_ip_code" == "301" || "$host_ip_code" == "302" ]]; then
    print_success "Successfully connected via $host_ip"
    success=true
  else
    print_error "Failed to connect to OpenWebUI on all addresses"
    print_info "  localhost: $localhost_code"
    print_info "  127.0.0.1: $ip_code"
    print_info "  $host_ip: $host_ip_code"
    success=false
  fi
else
  print_warning "curl not available, cannot test OpenWebUI connectivity"
fi

# Provide detailed diagnostic information
print_step "Diagnostic Summary"

# Get network information
print_info "Network status:"
host_ip=$(get_host_ip)
gateway_ip=$(get_gateway_ip)

echo "Host IP: $host_ip"
echo "Gateway IP: $gateway_ip"
echo "OpenWebUI URL: http://localhost:${OPENWEBUI_PORT}"
echo "Ollama API URL: http://localhost:${OLLAMA_PORT}"

# Check container's internal network configuration
print_info "Container network configuration:"
podman exec "$OPENWEBUI_CONTAINER_NAME" cat /etc/hosts 2>/dev/null || print_warning "Could not read container's hosts file"
podman exec "$OPENWEBUI_CONTAINER_NAME" ip addr 2>/dev/null || print_warning "Could not check container's IP configuration"

# Check if the container can reach Ollama
print_info "Testing if container can reach Ollama API:"
podman exec "$OPENWEBUI_CONTAINER_NAME" curl -s -o /dev/null -w "%{http_code}" http://host.containers.internal:${OLLAMA_PORT}/api/tags 2>/dev/null || echo "failed"

# Check if the application is actually listening on the correct port internally
print_info "Checking if web application is listening internally:"
podman exec "$OPENWEBUI_CONTAINER_NAME" netstat -tulpn 2>/dev/null || 
podman exec "$OPENWEBUI_CONTAINER_NAME" ss -tulpn 2>/dev/null || 
print_warning "Could not check container's listening ports"

# Check firewall status and Ollama connectivity
print_step "Checking Ollama API Connectivity and Firewall"

# Test if Ollama is available on localhost vs 127.0.0.1
if command -v curl &>/dev/null; then
  print_info "Testing Ollama API on localhost..."
  localhost_ollama=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:${OLLAMA_PORT}/api/tags 2>/dev/null || echo "failed")
  
  print_info "Testing Ollama API on 127.0.0.1..."
  ip_ollama=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:${OLLAMA_PORT}/api/tags 2>/dev/null || echo "failed")
  
  print_info "Testing Ollama API on host IP (${host_ip})..."
  host_ip_ollama=$(curl -s -o /dev/null -w '%{http_code}' http://${host_ip}:${OLLAMA_PORT}/api/tags 2>/dev/null || echo "failed")
  
  print_info "Ollama API connectivity results:"
  print_info "  localhost:${OLLAMA_PORT}: $localhost_ollama"
  print_info "  127.0.0.1:${OLLAMA_PORT}: $ip_ollama"
  print_info "  ${host_ip}:${OLLAMA_PORT}: $host_ip_ollama"
  
  # Check if Ollama is only listening on 127.0.0.1 but not external interfaces
  if [[ "$ip_ollama" == "200" && "$host_ip_ollama" != "200" ]]; then
    print_warning "Ollama is only listening on 127.0.0.1, not on all interfaces"
    print_info "This is likely why the OpenWebUI container cannot connect to Ollama"
    
    # Offer to fix the issue
    if is_macos; then
      print_info "Would you like to reconfigure Ollama to listen on all interfaces? (recommended)"
      read -p "Reconfigure Ollama? (Y/n): " fix_ollama
      if [[ "$fix_ollama" != "n" && "$fix_ollama" != "N" ]]; then
        print_info "Stopping Ollama..."
        pkill ollama 2>/dev/null || true
        sleep 2
        
        # Start Ollama with external interface binding from constants
        print_info "Starting Ollama with: OLLAMA_HOST=0.0.0.0:${OLLAMA_PORT} ollama serve"
        env OLLAMA_HOST="0.0.0.0:${OLLAMA_PORT}" ollama serve > /dev/null 2>&1 &
        sleep 5
        
        # Verify the change
        print_info "Testing if Ollama is now accessible on all interfaces..."
        host_ip_ollama_after=$(curl -s -o /dev/null -w '%{http_code}' http://${host_ip}:${OLLAMA_PORT}/api/tags 2>/dev/null || echo "failed")
        if [[ "$host_ip_ollama_after" == "200" ]]; then
          print_success "Ollama is now accessible on all interfaces!"
          print_info "You may need to restart the OpenWebUI container for changes to take effect"
        else
          print_warning "Ollama is still not accessible on external interfaces"
          print_info "You may need to restart your terminal or computer for changes to take effect"
        fi
      fi
    fi
  fi
else
  print_warning "curl not available, cannot test Ollama API connectivity"
fi

# Check system firewall status and actual rules
print_info "Checking host firewall status (may require sudo):"
if is_macos; then
  # macOS firewall check
  firewall_status=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null)
  
  # Check if Ollama is already in the firewall exceptions
  ollama_path=$(which ollama 2>/dev/null || echo "/usr/local/bin/ollama")
  
  # Check detailed firewall rules
  print_info "Checking if Ollama is already allowed in firewall rules..."
  allowed_apps=$(/usr/libexec/ApplicationFirewall/socketfilterfw --listapps 2>/dev/null || echo "")
  
  ollama_in_firewall=$(echo "$allowed_apps" | grep -i ollama || echo "")
  ollama_already_allowed=false
  
  if [[ -n "$ollama_in_firewall" ]]; then
    if [[ "$ollama_in_firewall" == *"(Allow)"* ]]; then
      print_success "Ollama is already allowed in firewall rules"
      ollama_already_allowed=true
    else
      print_warning "Ollama is in firewall rules but might be blocked"
    fi
  fi
  
  if [[ "$firewall_status" == *"enabled"* && "$ollama_already_allowed" != "true" ]]; then
    print_warning "macOS firewall is enabled and Ollama is not in the exceptions list"
    print_info "Would you like to add Ollama to the firewall exceptions? (recommended)"
    read -p "Update firewall? (Y/n): " update_firewall
    if [[ "$update_firewall" != "n" && "$update_firewall" != "N" ]]; then
      print_info "Adding Ollama to firewall exceptions (may require password)..."
      sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$ollama_path" 2>/dev/null || true
      sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$ollama_path" 2>/dev/null || true
      print_success "Firewall rules updated!"
      
      # Ask to restart Ollama
      print_info "Ollama needs to be restarted for firewall changes to take effect."
      read -p "Restart Ollama now? (Y/n): " restart_ollama
      if [[ "$restart_ollama" != "n" && "$restart_ollama" != "N" ]]; then
        print_info "Stopping Ollama..."
        pkill ollama 2>/dev/null || true
        sleep 2
        
        # Start Ollama with host binding from constants
        print_info "Starting Ollama with external interface binding ($OLLAMA_HOST)..."
        ollama serve --host $OLLAMA_HOST > /dev/null 2>&1 &
        
        # Wait for Ollama to start
        sleep 5
        
        # Verify Ollama is running
        if pgrep -x "ollama" > /dev/null; then
          print_success "Ollama restarted successfully!"
        else
          print_error "Failed to restart Ollama. Please start it manually with: ollama serve"
        fi
        
        # Check API connectivity
        print_info "Testing Ollama API connectivity after restart..."
        host_ip_ollama_after=$(curl -s -o /dev/null -w '%{http_code}' http://${host_ip}:${OLLAMA_PORT}/api/tags 2>/dev/null || echo "failed")
        if [[ "$host_ip_ollama_after" == "200" ]]; then
          print_success "Ollama API is accessible on the host IP after restart!"
        else
          print_warning "Ollama API is still not accessible on the host IP. You may need to manually configure OLLAMA_HOST=0.0.0.0"
        fi
      fi
    fi
  else
    print_info "macOS firewall appears to be disabled"
  fi
else
  # Linux firewall check 
  systemctl status firewalld 2>/dev/null || 
  systemctl status ufw 2>/dev/null || 
  print_warning "Could not check Linux firewall status"
fi

if is_macos; then
  print_info "macOS Specific Recommendations:"
  print_info "1. Confirm this environment variable is set in the container:"
  print_info "   OLLAMA_API_BASE_URL=http://$gateway_ip:$OLLAMA_PORT"
  print_info "2. Try restarting the Podman machine:"
  print_info "   podman machine stop; podman machine start"
  print_info "3. Make sure Ollama is listening on all interfaces (0.0.0.0)"
fi

print_info "Recommended actions:"
print_info "1. Check web browser console for specific errors"
print_info "2. Try a different browser or private/incognito window"
print_info "3. Restart the OpenWebUI container:"
print_info "   podman restart $OPENWEBUI_CONTAINER_NAME"
print_info "4. Reinstall with explicit gateway IP (macOS):"
print_info "   OLLAMA_GATEWAY_IP=$gateway_ip bash install.sh"
print_info "5. Check for browser extensions or firewalls that might block connections"

print_step "Advanced Troubleshooting"
print_info "Try recreating the container with explicit network configuration:"
print_info "1. Stop and remove the current container:"
print_info "   podman stop $OPENWEBUI_CONTAINER_NAME && podman rm $OPENWEBUI_CONTAINER_NAME"
print_info "2. Run with a new configuration:"

if is_macos; then
  # macOS solution using host.containers.internal 
  print_info "   For macOS (recommended):"
  print_info "   podman run -d --name $OPENWEBUI_CONTAINER_NAME -p ${OPENWEBUI_PORT}:8080 -e \"OLLAMA_API_BASE_URL=http://host.containers.internal:${OLLAMA_PORT}\" $OPENWEBUI_IMAGE"
  
  # Fallback with host network (most compatible)
  print_info "   Alternative with host network (if above doesn't work):"
  print_info "   podman run -d --name $OPENWEBUI_CONTAINER_NAME --network=host -e \"OLLAMA_API_BASE_URL=http://localhost:${OLLAMA_PORT}\" $OPENWEBUI_IMAGE"
  print_info "   Note: With host network, you'll access OpenWebUI at http://localhost:8080 (container internal port)"
  
  # Get host IP in case other options fail
  host_ip=$(get_host_ip)
  if [[ -n "$host_ip" ]]; then
    print_info "   Another alternative using host IP directly:"
    print_info "   podman run -d --name $OPENWEBUI_CONTAINER_NAME -p ${OPENWEBUI_PORT}:8080 -e \"OLLAMA_API_BASE_URL=http://${host_ip}:${OLLAMA_PORT}\" $OPENWEBUI_IMAGE"
  fi
else
  # Linux solution
  print_info "   For Linux:"
  print_info "   podman run -d --name $OPENWEBUI_CONTAINER_NAME -p ${OPENWEBUI_PORT}:8080 -e \"OLLAMA_API_BASE_URL=http://localhost:${OLLAMA_PORT}\" $OPENWEBUI_IMAGE"
fi

# Add detailed browser troubleshooting
print_info "For browser connection reset errors:"
print_info "1. Clear your browser cache and cookies"
print_info "2. Check Developer Tools -> Network tab for specific error details"
print_info "3. Disable any content blockers or privacy extensions"
print_info "4. Try accessing via IP address instead of localhost: http://${host_ip}:${OPENWEBUI_PORT}"
print_info "5. Try a different browser entirely"

print_step "Inside Container Investigation"
print_info "To troubleshoot inside the container:"
print_info "1. Run this command to open a shell inside the container:"
print_info "   podman exec -it $OPENWEBUI_CONTAINER_NAME bash"
print_info "2. Inside the container, run these commands to verify the web server:"
print_info "   ps -aux                         # Check if the Python process is running"
print_info "   cat /etc/hosts                  # Check host mapping"
print_info "   curl -v http://localhost:8080   # Test internal web server (port 8080)"
print_info "   curl -v http://host.containers.internal:${OLLAMA_PORT}/api/tags  # Test Ollama connectivity"

print_step "Possible Causes for 'Connection was Reset'"
print_info "1. Port mapping issue - container using port 8080 internally but not properly mapped"
print_info "2. Network mode incompatibility - host network mode might not work correctly on your system"
print_info "3. Firewall blocking connections - check macOS firewall settings"
print_info "4. OpenWebUI can't reach Ollama - container networking issue"
print_info "5. DNS resolution issues inside container - check /etc/hosts mapping"
print_info "6. Podman networking configuration - might need to restart podman machine"
print_info "7. Ollama not configured to listen on the correct interface - use OLLAMA_HOST environment variable"
print_info "8. Incompatible ollama version - check 'ollama -v' to verify your version works with this script"

print_success "Diagnostic checks completed!"