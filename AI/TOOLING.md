# Notes on AI Tools to support the full SDLC cycle

## AI Assisted Areas for Engineers

1. Analysis
   1. Brainstorming, Design and Analysis of Product PRDs, Engineering 1-Pagers, Solutins Architecture and System Designs
   1. Code Project Analysis
      1. Talk to your code base
      1. Code Style linting, Coding Patterns, Project structure discovery
      1. Code discovery e.g. explain code paths/business logic without knowing where to look, code refactoring with test updates & quality checks, debugging
1. Coding
   1. IDE / CLI / Desktop Coding Agents
   1. Generate off mockups, wireframes, PRDs, user stories, code comments, code patterns
   1. Entire solutions, configurations, classes, methods, signle lines
   1. Build, resolve compile errors
   1. Generate Unit, integration and end-to-end tests
   1. Identify and fix code smells, test coverage, security vulnerabilities
1. Documentation
   1. Generate at Code level, ReadMe, Runbook
1. Workflow integrations
   1. Work tracking e.g. Jira
   1. CI/CD Pipelines with proactive monitoring and fixing e.g. push code, build server fails, AI auto generates PR fix
   1. Builds & Deployments e.g. Git workflows, PR deployments, Code Qualtiy & Security Scans, Integration & QA environments
1. AI Interactions
   1. Textual by default
   1. Voice options growing e.g. Whisper
   1. Workflows based on integrated AI Tools in context of "AI Agents", generally based on Model Context Protocol (MCP - [github](https://github.com/modelcontextprotocol))

## LLM Access

1.  Local
    - Small "Laptop" Models coupled with local or web RAG, e.g. Gwen for coding
      - May provide significant local/offline capabilities
    - [lmstudio](https://lmstudio.ai/)
      - LM Studio is a local LLM development environment that allows users to run and fine-tune LLMs on their own machines (managing models, datasets, and training processes).
      - Designed for making it easier for developers to work with LLMs without extensive technical knowledge.
    - [olama](https://github.com/ollama)
      - Command line tool for running LLMs locally
      - Provides a simple interface for downloading, running, and managing LLMs on your local machine.
      - open-source platform that enables users to run LLMs locally on their machines. It is particularly focused on privacy, efficiency, and flexibility.
    - [openwebui](https://github.com/open-webui)
      - OpenWebUI is a graphical interface to interact with LLMs through visual model selection and parameter adjustments.
1.  Hosted
    - [Anthropic Claude](https://docs.anthropic.com)
    - [DeepSeek](https://deepseek.ai/)
    - [Google Gemma](https://ai.google.dev/gemma)
    - [OpenAI](https://openai.com)
    - [Cohere](https://cohere.ai/)
    - [Meta LLaMA](https://ai.facebook.com/llama/)
    - [Mistral](https://mistral.ai/)
1.  IDE Integration
    - [Claude Code CLI](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code)
    - [CLINE](https://github.com/cline/cline)
    - [Codeium](https://codeium.com/)
