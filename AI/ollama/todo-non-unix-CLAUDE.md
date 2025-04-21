# Windows Support for Ollama Vibe

## Current Limitations

The current implementation of Ollama Vibe is designed specifically for macOS and Linux systems, with several components that don't directly translate to Windows:

1. **Bash Scripts**: The entire project is built around bash scripts, which aren't natively supported on Windows.
2. **Podman Dependency**: Windows support for Podman differs from macOS/Linux implementations.
3. **Ollama Installation**: Ollama has a different installation process on Windows.
4. **File Paths and Environment**: Windows uses different path separators and environment variable conventions.
5. **Process Management**: Commands for starting/stopping services differ on Windows.

## Implementation Plan

### 1. Script Architecture Changes

**Create a more flexible multi-platform architecture:**

Instead of embedding platform-specific code throughout the codebase, use a high-level unix/non-unix split:

```
ollama-vibe/
├── unix/
│   ├── install.sh
│   ├── uninstall.sh
│   └── utilities/
│       ├── cli_utilities.sh
│       ├── constants.sh
│       ├── diagnose_openwebui.sh
│       ├── install_ollama.sh
│       ├── install_openwebui.sh
│       └── install_podman.sh
│
├── windows/
│   ├── install.ps1
│   ├── uninstall.ps1
│   └── utilities/
│       ├── cli_utilities.ps1
│       ├── constants.ps1
│       ├── diagnose_openwebui.ps1
│       ├── install_ollama.ps1
│       ├── install_openwebui.ps1
│       └── install_podman.ps1
│
└── shared/
    ├── models.json        # Shared model definitions
    ├── version.txt        # Platform-agnostic version information
    └── README.md          # Universal documentation
```

This structure completely separates platform-specific implementations while sharing common configuration data. It also makes it clearer to users which version they should use based on their operating system.

### 2. Ollama Installation for Windows

- Use the official Windows installer for Ollama (downloadable from ollama.com)
- PowerShell script to:
  1. Check if Ollama is already installed
  2. Download the latest Windows installer
  3. Run the installer with appropriate flags
  4. Configure Ollama to listen on all interfaces (similar to OLLAMA_HOST=0.0.0.0)
  5. Create Windows service for Ollama (for persistence across reboots)

### 3. Podman Installation for Windows

Podman is the only container solution we'll support (no Docker alternatives). Windows has two Podman options:

1. **Windows Subsystem for Linux (WSL2) + Podman**:
   - Check for WSL2 installation, install if missing
   - Install Podman in WSL2 (similar to Linux implementation)
   - Configure networking to allow host Windows to access WSL2 containers

2. **Native Windows Podman**:
   - Install using the Windows installer from podman.io
   - Configure as a Windows service
   - Set up appropriate networking for container-to-host communication
   - Adjust PowerShell commands to use native Windows Podman syntax

### 4. Path and Environment Handling

- Rewrite path handling for Windows:
  ```powershell
  # Unix
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  
  # Windows PowerShell equivalent
  $SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
  ```

- Convert environment variable syntax:
  ```powershell
  # Unix
  OLLAMA_HOST=0.0.0.0 ollama serve
  
  # Windows PowerShell equivalent 
  $env:OLLAMA_HOST="0.0.0.0"; ollama serve
  ```

- Handle file paths consistently:
  ```powershell
  # Use Join-Path for cross-platform compatibility
  $configPath = Join-Path -Path $SCRIPT_DIR -ChildPath "config"
  ```

### 5. Process Management

- Replace Unix process checking with Windows equivalents:
  ```powershell
  # Unix
  pgrep -x "ollama"
  
  # Windows PowerShell equivalent
  Get-Process -Name "ollama" -ErrorAction SilentlyContinue
  ```

- Service management:
  ```powershell
  # For Windows service control
  Start-Service -Name "Ollama"
  Stop-Service -Name "Ollama"
  Get-Service -Name "Ollama" | Select-Object Status
  ```

### 6. Networking Configuration

- Windows networking configuration for container-to-host communication:
  1. Use host IP address instead of `host.containers.internal` which may not be available
  2. Configure Windows Firewall rules to allow traffic on ports 11434 (Ollama) and 8080 (OpenWebUI)
  3. Handle WSL2-specific networking if using WSL2-based Podman

### 7. OpenWebUI Configuration

- The Podman container for OpenWebUI remains the same
- The networking configuration needs changes:
  ```powershell
  # Get Windows host IP for container communication
  $hostIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "vEthernet (WSL)" -ErrorAction SilentlyContinue).IPAddress
  
  # If using native Windows Podman, get the regular host IP
  if (-not $hostIP) {
      $hostIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex (Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.InterfaceDescription -notlike "*Virtual*"} | Select-Object -First 1).ifIndex).IPAddress
  }
  ```

### 8. Testing Plan

1. Test on Windows 10 and Windows 11
2. Test both Podman approaches:
   - WSL2-based Podman
   - Native Windows Podman
3. Verify networking between components
4. Verify model downloads and performance
5. Validate OpenWebUI connectivity
6. Test with all supported models including the large 70B models

### 9. User Experience Improvements

- Add Windows-specific troubleshooting section
- Include how to run PowerShell scripts (execution policy issues)
- Document Windows Defender and firewall configuration
- Add Windows-specific performance recommendations
- Create Windows-specific diagrams for architecture understanding

### 10. Implementation Priorities

1. Create basic PowerShell framework with utilities
2. Implement Ollama installation and configuration
3. Implement WSL2+Podman solution (most compatible with existing code)
4. Implement native Windows Podman support (for users without WSL2)
5. Build OpenWebUI integration
6. Develop diagnostic tools
7. Create comprehensive documentation

## Technical Challenges

1. **WSL2 Networking**: The networking between Windows and WSL2 can be complex
2. **PowerShell Security**: Default execution policy may block scripts
3. **Windows Firewall**: May require explicit rules for components to communicate
4. **Performance Overhead**: WSL2 may introduce some performance overhead
5. **Path Translation**: File paths between Windows and WSL2 require translation
6. **Native Podman Differences**: Native Windows Podman has some differences from Linux Podman

## Recommended Approach

The recommended approach is a two-pronged implementation:

1. **Primary: WSL2 + Podman** - Leverage WSL2 and Podman within WSL2, as this will allow reuse of much of the existing Linux-specific code, with Windows PowerShell scripts handling the Windows-specific aspects of installation and configuration.

2. **Secondary: Native Windows Podman** - For users who cannot or prefer not to use WSL2, provide a native Windows implementation using the official Windows Podman installer.

The high-level unix/non-unix directory split will make it clear which implementation users should use and will simplify maintenance by keeping platform-specific code completely separated.

## Shared Configuration

Where possible, platform-agnostic configuration should be stored in shared files to maintain consistency:

- Model definitions
- Version information
- Default resource allocations
- Documentation

This will ensure that all platforms provide a consistent experience despite the implementation differences.