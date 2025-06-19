# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Smith is a sophisticated memory management system for AI agents built on Elixir/OTP using the Ash framework. It implements the MemoryOS architecture - a hierarchical memory system inspired by operating system principles to overcome LLM context window limitations.

### Core Architecture

The system implements a 4-tier hierarchical memory architecture:

1. **Short-Term Memory (STM)**: Recent conversation data stored as "dialogue pages" in a fixed-length queue (7 pages)
2. **Mid-Term Memory (MTM)**: Topic-based segments using semantic similarity grouping (max 200 segments)  
3. **Long-Term Personal Memory (LPM)**: Persistent knowledge about entities and agent personas
4. **System Memory**: Shared knowledge accessible across all agents

All memory tiers use vector embeddings for semantic search via PostgreSQL's pgvector extension.

## Development Commands

### Setup & Installation
```bash
mix setup                    # Install deps, setup database, build assets
mix deps.get                 # Install dependencies only
mix igniter.install --yes <dependency>  # Install igniter-compatible deps
```

### Development Server
```bash
mix phx.server              # Start Phoenix server (localhost:4000)
```

### Database Operations
```bash
mix ash.setup               # Setup Ash resources and database
mix ecto.reset              # Drop and recreate database
mix ecto.migrate            # Run migrations
```

### Code Quality
```bash
mix compile --warnings-as-errors  # Compile with warnings as errors
mix test                    # Run test suite
mix format                  # Format code
mix usage_rules.sync        # Update AGENTS.md after adding dependencies
```

### Background Jobs
Background processing is handled by Oban. Jobs are defined in the `workers/` directory and managed through Ash's oban integration.

## Technology Stack

### Core Framework
- **Ash Framework**: Declarative resource-based architecture for all domain logic
- **Phoenix 1.8**: Web framework with LiveView for real-time UI updates
- **Elixir 1.18+/OTP 27+**: Runtime with native JSON support
- **PostgreSQL 13+**: Database with pgvector extension for vector operations

### Key Dependencies
- **AshAI**: LLM integration and agent orchestration
- **AshPostgres**: Database integration
- **AshOban**: Background job processing
- **Req**: HTTP client for external API calls
- **Tailwind 4.0**: CSS framework (no config file, CSS-based theming)

### Memory & AI
- **Vector Embeddings**: Uses OpenAI embedding model via AshAI
- **LLM Integration**: Configurable LLM clients for text generation
- **Semantic Search**: Cosine similarity and Jaccard similarity for memory retrieval

## Code Structure

### Domain Organization
```
lib/smith/memory_os/
├── domain.ex              # Main Ash domain definition
├── configuration.ex       # Agent configuration resource
├── system_memory.ex       # Cross-agent knowledge store
├── stm/                   # Short-term memory resources
├── mtm/                   # Mid-term memory resources  
├── lpm/                   # Long-term personal memory resources
└── workers/               # Background job workers
```

### Key Algorithms
- **Fscore Calculation**: `cos(e_s, e_p) + FJacard(K_s, K_p)` for semantic segmentation
- **Heat Score**: `α·N_visit + β·L_interaction + γ·R_recency` for memory importance
- **Memory Transfer**: STM→MTM via FIFO, MTM→LPM via heat-based promotion

## Development Guidelines

### Resource Patterns
- All domain logic uses Ash resources with actions, not Phoenix contexts
- Use `code_interface` blocks for programmatic resource access
- Leverage `vectorize` blocks for automatic embedding generation
- Background jobs via `oban` blocks with Ash triggers

### Phoenix Integration
- Use LiveView for all interactive components
- Forms handled via `ash_phoenix` form helpers
- State updates via Ash's pub/sub integration
- Components in `core_components.ex` - extend rather than recreate

### Memory System Specifics
- Memory operations are async via Oban workers
- Embeddings generated automatically on content changes
- Heat scores updated periodically via background jobs
- Semantic search uses vector similarity with configurable thresholds

### Testing Strategy
- Prefer doctests for library functions
- Unit tests for all backend memory algorithms
- No LiveView testing - focus on resource/action testing
- Mock LLM services for integration tests

## Configuration

Key configuration in `config/*.exs`:
- Memory capacities (STM: 7, MTM: 200, LPM queues: 100)
- Similarity thresholds (Fscore: 0.6, Heat: 5.0)
- LLM model selection and API keys
- Vector embedding dimensions (90 for user traits)

## Important Notes

- Always read `docs/index.md` and `docs/background.md` for project context
- Check `AGENTS.md` for current dependency documentation
- Keep files under 300 LOC - break into smaller modules
- Use Ash extensions for domain-specific functionality
- Vector operations are handled by Ash.Vector - no separate pgvector imports needed
- Research foundation based on MemoryOS paper (arXiv:2506.06326)