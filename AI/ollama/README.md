# Ollama Vibe

A utility for installing and configuring Ollama with coding-optimized LLM models for "vibe coding" sessions. This project has been set up to run within a pyenv Python virtual environment for better isolation and dependency management.

## Features

- Automated installation of Ollama
- Pulls and configures coding-optimized LLM models:
  - CodeLlama 7B and 13B
  - DeepSeek Coder v2
  - Gemma 3 12B
- Creates convenient shell aliases for quick access
- Provides a comprehensive usage guide
- Runs within an isolated Python virtual environment

## How it Works

This project uses a hybrid approach to handle dependencies:

1. **Python Environment**: The installation script and management code run in an isolated pyenv virtual environment, providing consistent Python dependencies.

2. **Ollama Installation**: Ollama itself is installed as a system binary (not a Python package) via the official Ollama installer. This means:
   - The Ollama binary is placed in a system location (typically `/usr/local/bin/ollama`)
   - Ollama's models and data are stored in system locations (typically `~/.ollama`)
   - The Ollama binary can be used by other applications outside the virtual environment

3. **Shell Aliases**: The created aliases reference the system-installed Ollama binary, making them available regardless of whether you're in the virtual environment or not.

This approach keeps the Python code dependencies isolated while allowing Ollama to be used system-wide.

## Requirements

- macOS (Designed for MacBook)
- Internet connection (for downloading models)
- Bash or Zsh shell

## Installation

1. Clone this repository:

   ```bash
   git clone https://github.com/yourusername/ollama-vibe.git
   cd ollama-vibe
   ```

2. Run the installation script:

   ```bash
   chmod +x install.sh
   ./install.sh
   ```

   This script will:

   - Install pyenv if not already installed
   - Set up a Python 3.10 environment using pyenv
   - Create and activate a virtual environment
   - Install the ollama-vibe package
   - Run the setup process for Ollama and download models

## Usage

After installation, you can start coding sessions with:

- `vibecode` - Uses CodeLlama 7B (balanced speed and capability)
- `vibecode-pro` - Uses CodeLlama 13B (better for complex tasks)
- `vibecode-deep` - Uses DeepSeek Coder (specialized for coding tasks)

A detailed usage guide is created at `~/ollama-vibe-coding-guide.md`.

## Development

If you want to contribute or modify this project:

1. Activate the virtual environment:

   ```bash
   cd ollama-vibe
   source .venv/bin/activate
   ```

2. Make your changes to the code

3. Test your changes:
   ```bash
   python -m ollama_vibe.cli
   ```

## Acknowledgements

- [Ollama](https://ollama.com/) for making local LLMs accessible
- The teams behind CodeLlama, DeepSeek Coder, and Gemma models
