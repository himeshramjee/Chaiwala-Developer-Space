#!/bin/bash
# Ollama Vibe - Install Script with PyEnv Virtual Environment

set -e  # Exit on error

# Check if pyenv is installed
if ! command -v pyenv &>/dev/null; then
    echo "PyEnv is not installed. Installing..."
    curl https://pyenv.run | bash
    
    # Add pyenv to shell config
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
    echo 'eval "$(pyenv init -)"' >> ~/.zshrc
    
    # Source the updated config
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    
    echo "PyEnv installed. You may need to restart your shell."
fi

# Set Python version for this project
PYTHON_VERSION="3.10.0"

# Check if the Python version is installed with pyenv
if ! pyenv versions | grep -q $PYTHON_VERSION; then
    echo "Installing Python $PYTHON_VERSION with pyenv..."
    pyenv install $PYTHON_VERSION
fi

# Create project name for the virtual environment
PROJECT_NAME="ollama-vibe"

# Set the local Python version for this project
echo "Setting local Python version to $PYTHON_VERSION..."
cd "$(dirname "$0")"
pyenv local $PYTHON_VERSION

# Create and activate virtual environment
echo "Creating virtual environment..."
python -m venv .venv

# Activate virtual environment
echo "Activating virtual environment..."
source .venv/bin/activate

# Install dependencies and the project in development mode
echo "Installing project dependencies..."
pip install -e .

# Run the Ollama setup script
echo "Running Ollama Vibe setup script..."
python -m ollama_vibe.cli

echo "Installation complete! Your Ollama environment is ready."
echo "To use it in the future, run 'source .venv/bin/activate' in this directory."