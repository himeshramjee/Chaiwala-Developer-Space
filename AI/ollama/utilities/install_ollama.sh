#!/bin/bash
# Ollama Vibe - Ollama Installation Functions

# Start Ollama service and ensure it's responsive
start_ollama_service() {
  print_step "Starting Ollama Service"
  

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
  
  print_info "Ollam should be ready to serve. Testing /api/generate endpoint..."
  ollama list

  HANDSHAKE_MODEL="codellama:7b"
  HANDSHAKE_PROMPT="Hello CAI ($HANDSHAKE_MODEL)! Are you ready to build cool value?"
  print_info "> $HANDSHAKE_PROMPT"
  curl -X POST http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"$HANDSHAKE_MODEL\", \"prompt\": \"$HANDSHAKE_PROMPT\", \"stream\": false}" \
    | jq '.response'


  print_success "Ollama service is running, API is responding and models can be served".
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