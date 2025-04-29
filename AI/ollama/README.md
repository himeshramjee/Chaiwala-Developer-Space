# Ollama Vibe

A bash utility for installing and configuring Ollama with coding-optimized LLM models for "vibe coding" sessions.

> **Note**: Currently supports macOS and Linux. Windows support is planned - see `todo-non-unix-CLAUDE.md` for implementation details.

## Features

- Automated installation of Ollama as a local service using the official Ollama installer script
- Pulls and configures coding-optimized LLM models:
  - Qwen2.5 Coder 14B
  - CodeLlama 7B
  - DeepSeek Coder v2 16B
  - Gemma 3 12B
  - Llama 3.3 70B (requires 32GB+ RAM and significant disk space)
- Installs OpenWebUI for a graphical interface to manage models (using Podman)
- Provides a comprehensive usage guide
- Includes diagnostic tools for troubleshooting

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

## Project Structure

```
ollama/
├── install.sh                # Main installation script
├── uninstall.sh              # Uninstallation script
└── utilities/
    ├── cli_utilities.sh      # Terminal formatting and OS detection functions
    ├── constants.sh          # Configuration parameters and model definitions
    ├── diagnose_openwebui.sh # Diagnostic tool for connection issues
    ├── install_ollama.sh     # Ollama installation functionality
    ├── install_openwebui.sh  # OpenWebUI container setup
    └── install_podman.sh     # Podman installation and machine management
```

## Requirements

- **Operating System**: macOS or Linux
- **Hardware**:
  - Minimum 8GB RAM for basic models
  - 16GB RAM recommended for most models
  - 32GB+ RAM for larger models (especially Llama 3.3 70B)
  - 20GB free disk space for base models
  - 50GB+ free disk space for all models including Llama 3.3 70B
  - x86_64 or ARM64 architecture
- **macOS Dependencies**:
  - Homebrew (for Podman installation)
  - macOS 11 (Big Sur) or newer
- **Linux Dependencies**:
  - APT or DNF package manager (for Podman installation)
  - sudo privileges
  - Kernel 4.18 or newer recommended

## Compatible Versions

- **Ollama**: v0.1.28 or newer (tested up to latest release)
- **Podman**: v4.7.0 or newer
- **OpenWebUI**: v0.2.13 or newer (using latest image from ghcr.io/open-webui/open-webui)

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
MODELS="codellama:7b gemma3:12b" bash install.sh

# Force reinstall of OpenWebUI without prompting
FORCE_REINSTALL=true bash install.sh

# Set a specific shell config file
SHELL_CONFIG_FILE="$HOME/.custom_rc" bash install.sh

# Use a custom port for OpenWebUI (default: 8080)
OPENWEBUI_PORT=8081 bash install.sh

# Manually specify the Podman gateway IP for macOS
OLLAMA_GATEWAY_IP=192.168.x.x bash install.sh
```

### Compatibility Notes

- **macOS**: The script will use your existing Podman machine if one is already running. Podman on macOS can only run one machine at a time.
- **Linux**: The script works with both apt and dnf-based distributions.

### Container Networking

Ollama Vibe uses a container networking approach designed for reliability:

- **Automatic Resource Allocation**: Podman machine is configured with optimized CPU and memory settings based on your system
- **Container-to-Host Communication**: Uses Podman's `host.containers.internal` DNS resolution to allow the OpenWebUI container to connect to the Ollama service running on your host
- **Single Port Mapping**: Maps only the essential port 8080 from the container to the host
- **Simple Deployment**: Works with existing Podman installations and machines
- **Gateway IP Detection**: Automatically detects the appropriate gateway IP for container-to-host communication on macOS

## Usage

After installation:

1. **Access Ollama via Terminal**:
   ```bash
   # Run a model directly
   ollama run codellama:7b
   
   # List available models
   ollama list
   
   # Run with specific parameters
   ollama run gemma3:12b --temperature 0.7
   
   # Get model info
   ollama info deepseek-coder-v2:16b

   # Start the Ollama service on all interfaces (if not running)
   OLLAMA_HOST=0.0.0.0:11434 ollama serve
   ```

2. **Access via OpenWebUI**:
   - Open your browser and navigate to `http://localhost:8080`
   - Create an account or continue as guest
   - Connect to your local Ollama instance (should be automatic)
   - Start chats with any of the installed models
   - Create custom presets for different tasks

3. **For Development Workflows**:
   - Use the models for coding assistance, debugging, and documentation
   - Connect to Ollama API at `http://localhost:11434` for application integrations
   - Use the APIs for custom integrations with development tools

## Diagnostic Tool

If you encounter issues with the installation or connection between components, use the included diagnostic tool:

```bash
bash utilities/diagnose_openwebui.sh
```

This tool will:
- Check Podman and container status
- Verify Ollama API availability
- Test network connectivity between components
- Check container environment variables
- Provide detailed recommendations for fixing issues

## Troubleshooting

### Ollama Service Issues

If Ollama fails to start:
```bash
# Check Ollama service status
pgrep -x ollama

# Start Ollama manually (listening on all interfaces)
OLLAMA_HOST=0.0.0.0:11434 ollama serve

# To check Ollama API status
curl http://localhost:11434/api/version
```

### OpenWebUI Connection Issues

If OpenWebUI can't connect to Ollama:
```bash
# Check if Ollama is listening on 0.0.0.0
ps aux | grep ollama

# Verify networking between Podman and host
podman inspect openwebui | grep IPAddress

# Check for common log errors
podman logs openwebui | grep -i error
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

#### Common Log Error Messages

Here are some common error messages you might see in the logs and what they mean:

- `connection reset by peer`: OpenWebUI cannot connect to Ollama API
- `no such host`: DNS resolution issue between container and host
- `connection refused`: Ollama is not running or not listening on the correct interface
- `error pulling model`: Network connectivity issue or insufficient disk space

### Model Download Issues

If model downloads fail:
```bash
# Check network connection
ping ollama.com

# Check disk space availability
df -h ~/.ollama

# Try manual download with more verbose output
ollama pull codellama:7b -v

# Check model status
ollama list
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

## Future Development

See `todo-non-unix-CLAUDE.md` for details on planned Windows support implementation.

## Acknowledgements

- [Ollama](https://ollama.com/) for making local LLMs accessible
- [OpenWebUI](https://github.com/open-webui/open-webui) for the web interface
- [Podman](https://podman.io/) for the daemonless container engine
- The teams behind these amazing models:
  - [Qwen2.5 Coder](https://ollama.com/library/qwen2.5-coder)
  - [CodeLlama](https://ollama.com/library/codellama)
  - [DeepSeek Coder](https://ollama.com/library/deepseek-coder)
  - [Gemma](https://ollama.com/library/gemma)
  - [Llama 3.3](https://ollama.com/library/llama3)