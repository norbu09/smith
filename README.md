# Smith

Smith is a sophisticated memory management system for AI agents, built on the Elixir/OTP ecosystem. It provides long-term, personalized memory capabilities that overcome the limitations of fixed context windows in Large Language Models (LLMs).

## Background

Smith implements the MemoryOS architecture, a sophisticated memory management system inspired by operating system principles, designed to address the limitations of Large Language Models (LLMs) regarding fixed context windows and inadequate memory management. Traditional LLMs struggle with long-term memory capabilities and personalization in extended interactions due to their fixed-length context windows, often leading to factual inconsistencies and reduced personalization in dialogues with significant temporal gaps.

### MemoryOS Architecture

MemoryOS introduces a hierarchical storage architecture composed of four core functional modules:

1. **Short-Term Memory (STM)**: Stores recent conversation data in a fixed-length queue, maintaining contextual coherence through dialogue chaining and summarization.
   - Stores real-time conversation data as "dialogue pages"
   - Implements a fixed-length queue (default: 7 pages)
   - Maintains meta-chains for contextual coherence

2. **Mid-Term Memory (MTM)**: Organizes information into topic-based segments using semantic similarity.
   - Groups related dialogue pages into "segments"
   - Uses vector embeddings and keyword analysis for topic grouping
   - Implements heat-based eviction and promotion policies

3. **Long-Term Personal Memory (LPM)**: Maintains persistent knowledge about entities and the agent itself.
   - Stores user and agent personas
   - Maintains knowledge bases and trait profiles
   - Enables personalized interactions over time

4. **System Memory**: Shared knowledge accessible across all agents in the system.
   - Stores globally relevant information
   - Enables knowledge sharing between agents

### Research Foundation

This implementation is based on academic research in memory systems for AI agents. The core algorithms and architecture are derived from the following works on hierarchical memory management:

1. The MemoryOS architecture is inspired by research in cognitive architectures and operating system principles applied to AI memory systems. The hierarchical organization (STM → MTM → LPM) draws from established cognitive science models of human memory.

2. The Fscore calculation for semantic segmentation is adapted from information retrieval and document clustering research, combining:
   - Vector space models for semantic similarity
   - Jaccard similarity for set-based comparison of keywords

3. The heat-based memory management system implements a variant of the Least Recently Used (LRU) algorithm, enhanced with frequency and recency factors inspired by caching strategies in operating systems.

The specific implementation details have been adapted for the Elixir/OTP ecosystem, taking advantage of its concurrency model and the Ash framework's declarative approach to building maintainable, scalable systems.

The system implements several key algorithms:

- **Fscore Calculation**: Combines semantic similarity and keyword overlap to group related content

  ```
  Fscore = cos(e_s, e_p) + FJacard(K_s, K_p)
  ```

  Where `e_s` and `e_p` are embedding vectors, and `K_s` and `K_p` are keyword sets.

- **Heat Score**: Determines memory importance based on:

  ```
  Heat = α·N_visit + β·L_interaction + γ·R_recency
  ```

  Where `N_visit` is visit count, `L_interaction` is interaction length, and `R_recency` is a time decay factor.

This implementation brings these research concepts into a production-ready system using modern Elixir technologies like the Ash framework and Phoenix LiveView.

## Features

- **Hierarchical Memory System**: Implements a multi-tiered memory architecture (STM, MTM, LPM) for efficient information management
- **Ash Framework Integration**: Built with the Ash framework for declarative, maintainable Elixir applications
- **Real-time Updates**: Powered by Phoenix LiveView for responsive, server-rendered UIs
- **Vector Search**: Utilizes PostgreSQL's pgvector extension for semantic similarity searches
- **Background Processing**: Leverages Oban for reliable background job processing
- **LLM Integration**: Seamlessly works with LLMs through the AshAI extension

## Installation

### Prerequisites

- Elixir 1.18+ and Erlang/OTP 27+
- PostgreSQL 13+ with the `vector` extension
- Node.js 16+ (for assets)

### Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/kittyfromouterspace/smith.git
   cd smith
   ```

2. Install dependencies:

   ```bash
   mix setup
   ```

3. Start the Phoenix server:

   ```bash
   mix phx.server
   ```

4. Visit [`localhost:4000`](http://localhost:4000) in your browser.

## Usage

### Basic Concepts

Smith implements a hierarchical memory system with three main components:

1. **Short-Term Memory (STM)**: Stores recent interactions in a fixed-size queue
2. **Mid-Term Memory (MTM)**: Groups related interactions into topics using semantic similarity
3. **Long-Term Personal Memory (LPM)**: Maintains persistent knowledge about entities and the agent itself
4. **System Memory**: Shared knowledge accessible across all agents

### Example: Creating a New Agent

```elixir
# Define a new agent configuration
config = %MemoryOS.Configuration{
  agent_type: "assistant",
  stm_capacity: 10,
  mtm_capacity: 200,
  heat_alpha: 1.0,
  heat_beta: 1.0,
  heat_gamma: 1.0,
  heat_threshold: 5.0
}

# Create the agent in the database
{:ok, agent} = MemoryOS.create_agent(config)
```

### Example: Processing an Interaction

```elixir
# Process a new user query
{:ok, response, memory_context} = MemoryOS.process_query(
  agent.id,
  "What's the weather like today?",
  %{user_id: "user123"}
)

# The response includes both the agent's response and relevant memories
IO.inspect(response)  # "I don't have access to real-time weather data..."
```

### Example: Searching Memory

```elixir
# Search for relevant memories
{:ok, results} = MemoryOS.search_memories(
  agent.id,
  "user's favorite color",
  %{user_id: "user123"}
)

# Results include relevant memories from all memory tiers
IO.inspect(Enum.map(results, & &1.content))
```

## Architecture

### Core Components

1. **Memory Storage**
   - STM: `MemoryOS.STM.DialoguePage`
   - MTM: `MemoryOS.MTM.DialogueSegment`
   - LPM: `MemoryOS.LPM.{ObjectPersona, AgentPersona}`
   - System: `MemoryOS.SystemMemory`

2. **Memory Management**
   - Automatic STM → MTM transfer when capacity is reached
   - Heat-based MTM → LPM promotion
   - Background processing via Oban workers

3. **LLM Integration**
   - Vector embeddings for semantic search
   - Prompt construction with relevant context
   - Response generation with memory augmentation

### Data Flow

1. **Ingestion**: New interactions are stored in STM
2. **Processing**: Background jobs analyze and organize memories
3. **Retrieval**: Relevant memories are retrieved based on context
4. **Generation**: The LLM generates responses using the memory context

## Configuration

### Environment Variables

- `OPENAI_API_KEY`: Required for LLM integrations
- `SECRET_KEY_BASE`: Used for signing/encryption

### Application Configuration

See `config/config.exs` for detailed configuration options, including:

- Memory capacities
- Similarity thresholds
- Heat score parameters
- LLM model selection

## Development

### Running Tests

```bash
mix test
```

### Code Formatting

```bash
mix format
```

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Phoenix](https://www.phoenixframework.org/)
- Powered by [Ash Framework](https://ash-hq.org/)
- inspired by research from (<https://github.com/BAI-LAB/MemoryOS>):
  @misc{kang2025memoryosaiagent,
      title={Memory OS of AI Agent},
      author={Jiazheng Kang and Mingming Ji and Zhe Zhao and Ting Bai},
      year={2025},
      eprint={2506.06326},
      archivePrefix={arXiv},
      primaryClass={cs.AI},
      url={<https://arxiv.org/abs/2506.06326}>,
  }
