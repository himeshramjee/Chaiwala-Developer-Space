#!/bin/bash
# Ollama Vibe - OpenWebUI Installation Functions

# Launch OpenWebUI container with host.containers.internal
run_container_with_host_internal() {
  print_info "Using container configuration with host.containers.internal"
  print_info "Command: podman run -d --cap-add 'net_raw' --name \"$OPENWEBUI_CONTAINER_NAME\" -p \"${OPENWEBUI_PORT}:8080\" -e \"OLLAMA_API_BASE_URL=http://host.containers.internal:${OLLAMA_PORT}\" --restart always $OPENWEBUI_IMAGE"

  podman run -d \
    --cap-add 'net_raw' \
    --name "$OPENWEBUI_CONTAINER_NAME" \
    -p "${OPENWEBUI_PORT}:8080" \
    -e "OLLAMA_API_BASE_URL=http://host.containers.internal:${OLLAMA_PORT}" \
    --restart always \
    $OPENWEBUI_IMAGE

  return $?
}

# Install OpenWebUI
install_openwebui() {
  print_step "Installing OpenWebUI"

  # Debug: Print current Podman status
  print_info "Current Podman status:"
  podman ps -a || print_warning "Failed to list Podman containers"
  
  # Check if the container already exists
  if podman ps -a --format "{{.Names}}" | grep -q "^${OPENWEBUI_CONTAINER_NAME}$"; then
    print_info "OpenWebUI container already exists."
    
    # Check if the container is running
    if podman ps --format "{{.Names}}" | grep -q "^${OPENWEBUI_CONTAINER_NAME}$"; then
      print_info "OpenWebUI container is already running."
      
      # Ask the user if they want to reinstall
      if [[ "${FORCE_REINSTALL}" != "true" ]]; then
        read -p "Do you want to remove and reinstall OpenWebUI? (y/N): " reinstall_choice
        if [[ "$reinstall_choice" != "y" && "$reinstall_choice" != "Y" ]]; then
          print_info "Keeping existing OpenWebUI container."
          print_info "To access OpenWebUI, go to http://localhost:${OPENWEBUI_PORT}"
          return 0
        fi
      else
        print_info "FORCE_REINSTALL=true, removing existing container."
      fi
    fi
    
    # Remove the container if running or if user requested reinstall
    print_info "Removing existing container..."
    
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
  fi

  # Pull the image to ensure we have the latest version
  print_info "Pulling OpenWebUI image..."
  podman pull $OPENWEBUI_IMAGE
  pull_result=$?
  if [ $pull_result -ne 0 ]; then
    print_error "Failed to pull OpenWebUI image (code: $pull_result). Check network connection."
    return 1
  fi
  
  print_info "Running OpenWebUI container on port ${OPENWEBUI_PORT}..."
  run_container_with_host_internal
  # Capture the result
  run_result=$?
  
  # Check the result
  if [ $run_result -ne 0 ]; then
    print_error "Failed to run OpenWebUI container. Error code: $run_result"
    return 1
  fi

  # Verify the container is running
  if ! podman ps | grep -q "$OPENWEBUI_CONTAINER_NAME"; then
    print_error "Failed to start OpenWebUI container. Checking logs:"
    # Get container ID to avoid logs error when run remotely
    container_id=$(podman ps -qa --filter "name=$OPENWEBUI_CONTAINER_NAME" 2>/dev/null)
    if [[ -n "$container_id" ]]; then
      podman logs "$container_id" 2>&1 || true
    else
      print_warning "Container ID not found for $OPENWEBUI_CONTAINER_NAME, unable to get logs"
    fi
    return 1
  fi

  # Update container package manager
  print_info "Update apt-get package manager..."
  podman exec "$OPENWEBUI_CONTAINER_NAME" apt-get update 2>/dev/null

  # Install hf_xet package to improve performance
  print_info "Installing performance enhancement package in the container..."
  podman exec "$OPENWEBUI_CONTAINER_NAME" pip install -q huggingface_hub[hf_xet] hf_xet 2>/dev/null || {
    print_warning "Could not install performance enhancement package, but OpenWebUI will still work"
  }

  # Install networking and system utilities
  print_info "Installing networking and system utilities in the container..."
  podman exec "$OPENWEBUI_CONTAINER_NAME" apt-get install -y iputils-ping lsof procps net-tools dnsutils 2>/dev/null || {
    print_warning "Could not install networking and system utilities, some diagnostic tools will not be available"
  }
  
  # Wait for OpenWebUI to fully initialize (can take a few seconds)
  print_info "Waiting for OpenWebUI to initialize (up to 30 seconds)..."
  local web_responsive=false
  local wait_count=30
  for i in {1..$wait_count}; do
    sleep 1
    # Check if the web server is responding using curl
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${OPENWEBUI_PORT}/" 2>/dev/null || echo "000")
    if [[ "$response_code" == "200" || "$response_code" == "302" || "$response_code" == "301" ]]; then
      print_success "OpenWebUI is responding on port ${OPENWWEBUI_PORT} (HTTP ${response_code})"
      web_responsive=true
      break
    else
      print_info "Waiting for OpenWebUI to respond... (attempt $i/${wait_count}, got HTTP ${response_code})"
    fi
    else
      # If neither curl nor wget are available, just wait
      print_info "Waiting for OpenWebUI to initialize... (attempt $i/${wait_count})"
    fi
    sleep 1
  done
  
  # Check connectivity status
  if [[ "$web_responsive" != "true" ]]; then
    print_warning "OpenWebUI container is not responding to web requests"
    print_info "Container logs for $OPENWEBUI_CONTAINER_NAME:"
    
    # Get container ID to avoid logs error when run remotely
    container_id=$(podman ps -q --filter "name=$OPENWEBUI_CONTAINER_NAME" 2>/dev/null)
    if [[ -n "$container_id" ]]; then
      podman logs "$container_id" --tail 20 2>&1 || true
    else
      print_warning "Container ID not found for $OPENWEBUI_CONTAINER_NAME, unable to get logs"
    fi
    
    print_info "Container network info for $OPENWEBUI_CONTAINER_NAME:"
    podman inspect "$OPENWEBUI_CONTAINER_NAME" -f '{{.NetworkSettings}}' 2>&1 || true
    print_warning "OpenWebUI may still initialize after some time. Try accessing it manually."
  fi

  print_success "OpenWebUI deployed successfully!"
  print_info "Access the WebUI at http://localhost:${OPENWEBUI_PORT}"
}