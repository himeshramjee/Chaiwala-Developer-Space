#!/bin/bash
# Ollama Vibe - Ollama Installation Functions

# Start Ollama service and ensure it's responsive
start_ollama_service() {
  print_step "Starting Ollama Service"
  
  # First check if API is already responding
  if curl -s --max-time 2 "http://localhost:${OLLAMA_PORT}/api/version" &>/dev/null; then
    print_success "Ollama API is already running and responding"
    return 0
  fi
  
  # Check if process is running but API is not responsive
  if pgrep -x "ollama" > /dev/null; then
    print_info "Ollama process is running but API is not responding. Stopping it first..."
    if is_macos; then
      killall ollama 2>/dev/null || true
    else
      sudo systemctl stop ollama 2>/dev/null || killall ollama 2>/dev/null || true
    fi
    sleep 2
  fi
  
  # Start Ollama with environment variable for host binding
  print_info "Starting Ollama with: OLLAMA_HOST=0.0.0.0:${OLLAMA_PORT} ollama serve"
  
  # Run the serve command with environment variable in the background
  nohup env OLLAMA_HOST="0.0.0.0:${OLLAMA_PORT}" ollama serve > /dev/null 2>&1 &
  
  # Capture the PID for user info
  local OLLAMA_PID=$!
  print_info "Ollama started with PID: $OLLAMA_PID"
  
  # If the PID is 0 or not a valid process, it means the command failed
  if ! ps -p $OLLAMA_PID > /dev/null 2>&1; then
    print_error "Failed to start Ollama process."
    print_info "Try running manually to see errors: OLLAMA_HOST=0.0.0.0:${OLLAMA_PORT} ollama serve"
    return 1
  fi
  
  # Wait for the API to become responsive
  print_info "Waiting for Ollama API to respond (up to 15 seconds)..."
  local api_responding=false
  for i in {1..15}; do
    sleep 1
    if curl -s --max-time 1 "http://localhost:${OLLAMA_PORT}/api/version" &>/dev/null; then
      print_success "Ollama API is responding after $i seconds"
      api_responding=true
      break
    else
      echo -n "."
    fi
  done
  echo # Add newline after dots
  
  if ! $api_responding; then
    print_error "Failed to verify Ollama API is responding."
    print_info "Please try starting Ollama manually with: OLLAMA_HOST=0.0.0.0:${OLLAMA_PORT} ollama serve"
    # Kill the process that we started since it's not responsive
    kill $OLLAMA_PID 2>/dev/null || true
    return 1
  fi
  
  print_success "Ollama service is running and API is responding"
  return 0
}

# Install Ollama
install_ollama() {
  print_step "Installing Ollama"

  if is_ollama_installed; then
    print_info "Ollama is already installed."
    
    # Check if API is already responding
    print_info "Checking if Ollama API is responsive..."
    if curl -s --max-time 2 "http://localhost:${OLLAMA_PORT}/api/version" &>/dev/null; then
      print_success "Ollama API is running and responding"
    else
      print_warning "Ollama is installed but API is not responding."
      start_ollama_service
    fi
    
    return 0
  fi

  if is_macos; then
    # MacOS: Install via Homebrew
    if ! is_homebrew_installed; then
      print_error "Homebrew is required to install Ollama on macOS."
      print_info "Please install Homebrew first: https://brew.sh"
      exit 1
    fi
    
    print_info "Installing Ollama via Homebrew..."
    brew install ollama
  else
    # Linux: Use the official install script
    print_info "Downloading and installing Ollama using the official script..."
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  
  if ! is_ollama_installed; then
    print_error "Failed to install Ollama."
    exit 1
  fi

  print_success "Ollama installed successfully!"

  # Start Ollama service
  start_ollama_service
}

# Download and install LLM models
install_models() {
  print_step "Installing LLM models"

  # First check if Ollama is responsive
  print_info "Checking if Ollama API is responsive..."
  if ! curl -s --max-time 2 "http://localhost:${OLLAMA_PORT}/api/version" &>/dev/null; then
    print_warning "Ollama API is not responding. Attempting to start Ollama service..."
    
    # Try to start the service
    if ! start_ollama_service; then
      print_error "Failed to start Ollama service. Cannot proceed with model installation."
      print_info "Please try starting Ollama manually with: OLLAMA_HOST=0.0.0.0:${OLLAMA_PORT} ollama serve"
      print_info "Then run the install script again."
      exit 1
    fi
  else
    print_success "Ollama API is responding"
  fi

  # First, check for existing models
  print_info "Checking for existing models..."
  local existing_models
  existing_models=$(ollama list 2>/dev/null || echo "")
  
  local all_successful=true
  for model in "${MODELS_ARRAY[@]}"; do
    # Check if model already exists
    if echo "$existing_models" | grep -q "$model"; then
      print_info "Model $model is already installed, skipping"
      continue
    fi
    
    print_info "Pulling model: $model"
    ollama pull "$model"
    pull_result=$?
    if [ $pull_result -ne 0 ]; then
      print_error "Failed to pull model: ${model}. Error code: $pull_result"
      print_info "Trying alternative approach: check if model exists but wasn't detected..."
      
      # Try to run the model as a test - if it exists this should work
      if ollama run "$model" "test" --nowordwrap 2>/dev/null; then
        print_success "Model $model appears to be working despite pull error"
      else
        all_successful=false
      fi
    fi
  done

  if $all_successful; then
    print_success "All models installed successfully!"
    return 0
  else
    print_warning "Some models failed to install"
    return 1
  fi
}