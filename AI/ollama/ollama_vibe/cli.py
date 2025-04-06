#!/usr/bin/env python3
"""
Ollama Vibe CLI - Main entry point for the Ollama Vibe tool.
"""

import sys
from .core import setup_ollama_vibe

def main():
    """Main entry point."""
    try:
        setup_ollama_vibe()
        return 0
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
