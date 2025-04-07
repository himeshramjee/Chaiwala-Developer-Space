# CLAUDE.md - Project Information

## Project: Ollama Vibe

A bash utility for installing and configuring Ollama with coding-optimized LLM models.

## Commands

- No formal build/lint/test commands yet (bash-based project)
- Static checking: `shellcheck utilities/*.sh` (if shellcheck is installed)

## Code Style Guidelines

- Shell: Follow Google's Shell Style Guide
- Prefix functions with descriptive verbs (is*, get*, install*, configure*)
- Use UPPER_CASE for constants/environment variables
- Use snake_case for functions and variables
- Add error handling with proper exit codes and messages using print_error()
- Document functions with comments for complex logic
- Verify OS compatibility with is_macos() and is_linux() functions
- Use functions from cli_utilities.sh for consistent output formatting
- Keep line length < 100 characters when possible
- Ensure separation of concerns in functions and separate files
