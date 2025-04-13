# Ollama Vibe

A bash utility for installing and configuring Ollama with coding-optimized LLM models for "vibe coding" sessions.

## Features

- Automated installation of Ollama as a local service using the official Ollama installer script
- Pulls and configures coding-optimized LLM models:
  - Qwen2.5 Coder 14B
  - CodeLlama 7B
  - DeepSeek Coder v2 16B
  - Gemma 3 12B
  - Llama 3.3 70B
- Installs OpenWebUI for a graphical interface to manage models (using Podman)
- Provides a comprehensive usage guide

## How it Works

Ollama Vibe provides a one-command installation experience that:

1. Installs Ollama on your system using the official installer
2. Configures Ollama to accept connections on all interfaces
3. Installs Podman (if not already installed) to run container workloads
4. Sets up an optimized Podman machine with appropriate resource allocation
5. Deploys OpenWebUI in a Podman container for a graphical interface
6. Downloads and prepares optimized coding models
7. Sets up proper networking between components for container-to-host communication

All of this is handled automatically with appropriate error checking and user feedback throughout the process. The installer is designed to work with existing Podman setups and will use your currently running Podman machine if one exists.

## Requirements

- **Operating System**: macOS or Linux
- **Hardware**: 
  - Minimum 8GB RAM (16GB+ recommended)
  - 20GB free disk space for models
  - x86_64 or ARM64 architecture
- **macOS Dependencies**: 
  - Homebrew (for Podman installation)
- **Linux Dependencies**:
  - APT or DNF package manager (for Podman installation)
  - sudo privileges

## Installation

Run the following command in your terminal:

```bash
# For macOS or Linux
bash install.sh
```

The installation script will guide you through the process and provide feedback on each step.

### Advanced Installation Options

You can customize the installation with environment variables:

```bash
# Install specific models only (space-separated list)
MODELS="codellama:7b gemma2:12b" bash install.sh

# Force reinstall of OpenWebUI without prompting
FORCE_REINSTALL=true bash install.sh

# Set a specific shell config file
SHELL_CONFIG_FILE="$HOME/.custom_rc" bash install.sh
```

### Compatibility Notes

- **macOS**: The script will use your existing Podman machine if one is already running. Podman on macOS can only run one machine at a time.
- **Linux**: The script works with both apt and dnf-based distributions.

### Container Architecture

Ollama Vibe uses a simplified containerization approach:

- **Automatic Resource Allocation**: Podman machine is configured with optimized CPU and memory settings based on your system
- **Modern Container Networking**: Uses Podman's built-in DNS resolution for container-to-host communication
- **Single Port Mapping**: Maps only the essential port 8080 from the container to the host
- **Simple Deployment**: Works with existing Podman installations and machines

## Usage

After installation:

1. **Access Ollama via Terminal**:
   ```bash
   # Run a model directly
   ollama run codellama:7b
   
   # List available models
   ollama list
   ```

2. **Access via OpenWebUI**:
   - Open your browser and navigate to `http://localhost:8080`
   - Create an account or continue as guest
   - Connect to your local Ollama instance (should be automatic)
   - Start chats with any of the installed models

3. **For Development Workflows**:
   - Use the models for coding assistance, debugging, and documentation
   - Connect to Ollama API at `http://localhost:11434` for application integrations

## Troubleshooting

### Ollama Service Issues

If Ollama fails to start:
```bash
# Check Ollama service status
pgrep -x ollama

# Start Ollama manually (listening on all interfaces)
ollama serve --host 0.0.0.0

# Or use the wrapper script created during installation
./ollama-serve.sh

# To check Ollama API status
curl http://localhost:11434/api/version
```

### OpenWebUI Connection Issues

If OpenWebUI can't connect to Ollama:
```bash
# Check if Ollama is listening on 0.0.0.0
ps aux | grep ollama

# Verify networking between Podman and host
podman inspect ollama-webui | grep IPAddress
```

### Common Installation Issues

#### "Proxy Already Running" Error

If you encounter a "proxy already running" error:
```bash
# Stop the installation and try again with a different port
OPENWEBUI_PORT=8081 bash install.sh

# Or manually fix by cleaning up existing ports
lsof -i :8080  # Find processes using port 8080
kill -9 [PID]  # Kill the process

# Check for existing Podman containers
podman ps -a
podman rm -f openwebui  # Remove existing container if needed

# Restart with different port to avoid conflicts
OPENWEBUI_PORT=8081 bash install.sh
```

#### "Unable to start podman-machine" Error

If you see errors related to Podman machine:
```bash
# Check which Podman machines exist and their status
podman machine list

# If you have multiple machines, ensure only one is running
podman machine stop [other-machine-name]

# If you want to remove an existing machine
podman machine rm [machine-name]

# The script will use any running machine automatically
```

#### Gateway IP Detection Issues

If OpenWebUI can't connect to Ollama:
```bash
# Get the Podman gateway IP
podman machine inspect | grep Gateway

# Then manually set this when running the install
OLLAMA_GATEWAY_IP=192.168.x.x bash install.sh
```

### Model Download Issues

If model downloads fail:
```bash
# Check network connection
ping ollama.com

# Try manual download
ollama pull codellama:7b
```

## Uninstallation

To remove Ollama Vibe and its components:

```bash
bash uninstall.sh
```

The uninstaller provides several options:
- Keep or remove the Ollama binary
- Keep or remove downloaded models
- Multiple Podman management options:
  - Keep everything
  - Stop machines but keep Podman
  - Remove machines but keep Podman
  - Completely remove Podman

For additional support, please open an issue on GitHub.

## Acknowledgements

- [Ollama](https://ollama.com/) for making local LLMs accessible
- [OpenWebUI](https://github.com/open-webui/open-webui) for the web interface
- [Podman](https://podman.io/) for the daemonless container engine
- The teams behind these amazing models:
  - [Qwen2.5 Coder](https://ollama.com/library/qwen2.5-coder)
  - [CodeLlama](https://ollama.com/library/codellama)
  - [DeepSeek Coder](https://ollama.com/library/deepseek-coder)
  - [Gemma](https://ollama.com/library/gemma)
  - [Llama 3](https://ollama.com/library/llama3)
