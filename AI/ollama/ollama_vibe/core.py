#!/usr/bin/env python3
"""
Ollama Setup Script for MacBook
-------------------------------
This script installs and configures Ollama with coding-optimized models
for interactive "vibe coding" sessions.
"""

import os
import subprocess
import sys
import time

def print_step(message):
    """Print a step message with formatting."""
    print("\n" + "=" * 60)
    print(f"  {message}")
    print("=" * 60)
    
def run_command(command, description=None, check=True, shell=True):
    """Run a shell command with nice output formatting."""
    if description:
        print(f"\n> {description}")
    
    print(f"$ {command}")
    
    try:
        result = subprocess.run(command, shell=shell, check=check, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.stdout:
            print(result.stdout)
        return result
    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")
        print(f"Command output: {e.stderr}")
        if check:
            sys.exit(1)
        return e

def is_ollama_installed():
    """Check if Ollama is already installed."""
    result = run_command("which ollama", check=False)
    return result.returncode == 0

def install_ollama():
    """Install Ollama using the official installation script."""
    print_step("Installing Ollama")
    
    if is_ollama_installed():
        print("Ollama is already installed! Checking version...")
        run_command("ollama --version")
        return
    
    print("Installing Ollama...")
    curl_command = 'curl -fsSL https://ollama.com/install.sh | sh'
    run_command(curl_command, "Downloading and running the Ollama installer")
    
    # Verify installation
    if not is_ollama_installed():
        print("Installation seems to have failed. Please try installing manually:")
        print("curl -fsSL https://ollama.com/install.sh | sh")
        sys.exit(1)
        
    print("✅ Ollama installed successfully!")

def start_ollama_service():
    """Start the Ollama service."""
    print_step("Starting Ollama service")
    
    # Check if Ollama is already running
    ps_result = run_command("pgrep ollama", check=False)
    
    if ps_result.returncode == 0:
        print("Ollama service is already running!")
    else:
        print("Starting Ollama service...")
        # Run Ollama in the background
        run_command("ollama serve &", "Starting Ollama service")
        
        # Give it a moment to start up
        print("Waiting for Ollama service to start...")
        time.sleep(3)
    
    print("✅ Ollama service is running!")

def pull_coding_models():
    """Pull recommended models for coding."""
    print_step("Pulling recommended coding models")
    
    # List of recommended models for coding
    coding_models = [
        {
            "name": "codellama:7b",
            "description": "Meta's CodeLlama 7B - Good balance of capability and speed"
        },
        {
            "name": "codellama:13b",
            "description": "Meta's CodeLlama 13B - Better at understanding complex code"
        },
        {
            "name": "deepseek-coder-v2:16b",
            "description": "DeepSeek Coder v2 - Specialized for coding tasks"
        },
        {
            "name": "gemma3:12b",
            "description": "Google Gemma 3 - Good for code generation and understanding"
        }
    ]
    
    # Get list of already pulled models
    list_result = run_command("ollama list", "Checking for already pulled models")
    pulled_models = list_result.stdout.lower() if list_result.stdout else ""
    
    for model in coding_models:
        model_name = model["name"]
        if model_name.lower() in pulled_models:
            print(f"Model {model_name} is already pulled.")
            continue
            
        print(f"\nPulling {model_name} - {model['description']}")
        print("This may take a while depending on your internet connection...")
        run_command(f"ollama pull {model_name}", check=False)

def create_vibe_coding_alias():
    """Create a convenient alias for vibe coding."""
    print_step("Creating convenient aliases for vibe coding")
    
    # Check which shell the user is using
    shell_env = os.environ.get("SHELL", "")
    
    if "zsh" in shell_env:
        rc_file = os.path.expanduser("~/.zshrc")
    elif "bash" in shell_env:
        rc_file = os.path.expanduser("~/.bashrc")
    else:
        # Default to bash if we can't determine
        rc_file = os.path.expanduser("~/.bashrc")
    
    # Create aliases
    aliases = [
        'alias vibecode="ollama run codellama:7b"',
        'alias vibecode-pro="ollama run codellama:13b"',
        'alias vibecode-deep="ollama run deepseek-coder:6.7b"'
    ]
    
    # Check if aliases already exist
    try:
        with open(rc_file, 'r') as f:
            content = f.read()
            
        # Add only aliases that don't already exist
        new_aliases = [alias for alias in aliases if alias not in content]
        
        if not new_aliases:
            print(f"Aliases already exist in {rc_file}")
            return
            
        with open(rc_file, 'a') as f:
            f.write("\n# Ollama vibe coding aliases\n")
            for alias in new_aliases:
                f.write(f"{alias}\n")
                
        print(f"✅ Added aliases to {rc_file}")
        print("To use them in the current terminal session, run:")
        print(f"source {rc_file}")
        
    except Exception as e:
        print(f"Error adding aliases to {rc_file}: {e}")
        print("You can manually add these aliases:")
        for alias in aliases:
            print(alias)

def create_usage_guide():
    """Create a usage guide file."""
    print_step("Creating usage guide")
    
    guide = """# Ollama Vibe Coding Guide

## Quick Start
Run one of these commands to start a vibe coding session:

- `vibecode` - Uses CodeLlama 7B (balanced speed and capability)
- `vibecode-pro` - Uses CodeLlama 13B (better for complex tasks)
- `vibecode-deep` - Uses DeepSeek Coder (specialized for coding tasks)

## Example Prompts

- "Write a Python function to extract all emails from a text file"
- "Help me refactor this code: [paste your code]"
- "Explain how this regex works: ^(\w+)@[a-zA-Z_]+?\.[a-zA-Z]{2,3}$"
- "Debug this function: [paste your function]"
- "Suggest a better way to implement this algorithm"

## Tips for Better Results

1. **Provide context** - Explain what you're trying to achieve
2. **Use specific examples** - Include sample inputs/outputs
3. **Iterate gradually** - Build on previous responses
4. **Remember context limits** - Summarize long back-and-forths
5. **Try different models** - Each model has different strengths

## Advanced Usage

Get a list of all available models:
```
ollama list
```

Pull additional models:
```
ollama pull [model-name]
```

Run with specific parameters:
```
ollama run codellama:13b --temperature 0.7
```

## Troubleshooting

- If responses are slow, try a smaller model
- If responses are low quality, try a larger model or provide more context
- Restart Ollama if it becomes unresponsive: `pkill ollama && ollama serve`
"""
    
    guide_path = os.path.expanduser("~/ollama-vibe-coding-guide.md")
    
    try:
        with open(guide_path, 'w') as f:
            f.write(guide)
        print(f"✅ Created usage guide at {guide_path}")
    except Exception as e:
        print(f"Error creating guide: {e}")
        print("Here's the guide content you can save manually:")
        print(guide)

def setup_ollama_vibe():
    """Main function to run the setup."""
    print_step("Ollama Vibe Coding Setup")
    
    # Install Ollama
    install_ollama()
    
    # Start Ollama service
    start_ollama_service()
    
    # Pull coding models
    pull_coding_models()
    
    # Create aliases
    create_vibe_coding_alias()
    
    # Create usage guide
    create_usage_guide()
    
    print_step("Setup Complete!")
    print("""
🎉 Your vibe coding environment is ready!

To start a vibe coding session (after reloading your shell):
- Type 'vibecode' for a balanced experience
- Type 'vibecode-pro' for more complex tasks
- Type 'vibecode-deep' for specialized coding help

A usage guide has been created at: ~/ollama-vibe-coding-guide.md

Enjoy your vibe coding sessions!
""")
