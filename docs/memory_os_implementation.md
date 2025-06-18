# MemoryOS Implementation Documentation

## Overview

This document provides comprehensive documentation for the MemoryOS implementation in the Anderson project. The implementation follows the research paper "MemoryOS: A Memory-Driven Architecture for Large Language Models" and provides a complete hierarchical memory system for AI agents.

## Architecture

### Memory Hierarchy

The MemoryOS system implements a four-level memory hierarchy:

1. **STM (Short-Term Memory)** - Recent dialogue pages
2. **MTM (Medium-Term Memory)** - Dialogue segments with heat-based management  
3. **LPM (Long-Term Personal Memory)** - Agent-specific knowledge and traits
4. **SystemMemory** - Cross-agent shared knowledge

### Core Components

#### 1. Domain Structure (`lib/anderson/memory_os/`)

- **domain.ex** - Main Ash domain configuration
- **configuration.ex** - Agent-specific memory configuration
- **calculations.ex** - Core MemoryOS algorithms from the research paper

#### 2. Memory Resources

##### STM Resources (`stm/`)
- **dialogue_page.ex** - Individual conversation pages with automatic embedding generation

##### MTM Resources (`mtm/`)  
- **dialogue_segment.ex** - Groups of related pages with Fscore and heat calculations

##### LPM Resources (`lpm/`)
- **agent_persona.ex** - Agent personality and behavior configuration
- **knowledge_base_entry.ex** - Structured knowledge entries
- **object_persona.ex** - Object-specific memory associations
- **trait_entry.ex** - Agent characteristics and preferences

##### SystemMemory
- **system_memory.ex** - Cross-agent shared knowledge repository

#### 3. Background Processing (`workers/`)

- **check_stm_capacity_worker.ex** - STM capacity monitoring and MTM transfer
- **update_heat_score_worker.ex** - Heat score calculation and memory eviction
- **update_meta_chain_worker.ex** - LLM-based dialogue analysis
- **lpm_system_transfer_worker.ex** - Cross-agent knowledge promotion
- **periodic_jobs.ex** - Automated maintenance scheduling

#### 4. Agent Integration

- **llm_client.ex** - Memory-aware query processing and retrieval
- **agent_integration.ex** - High-level agent interaction API

## Core Algorithms

### Fscore Calculation
```
Fscore = cos(e_s, e_p) + FJacard(K_s, K_p)
```
Where:
- `e_s`, `e_p` are embedding vectors for segment and page
- `K_s`, `K_p` are keyword sets for segment and page
- Implemented in `Calculations.calculate_fscore/4`

### Heat Score Calculation
```
Heat = α·N_visit + β·L_interaction + γ·R_recency
```
Where:
- `N_visit` = number of times segment was accessed
- `L_interaction` = number of dialogue pages in segment
- `R_recency = exp(-Δt / μ)` with μ = 1e+7 seconds
- Default coefficients: α = β = γ = 1.0
- Implemented in `Calculations.calculate_heat_score/6`

### Similarity Metrics

#### Cosine Similarity
```elixir
# For embedding vectors
cosine_sim = dot_product(v1, v2) / (magnitude(v1) * magnitude(v2))
```

#### Jaccard Similarity  
```elixir
# For keyword sets
jaccard_sim = |intersection(K1, K2)| / |union(K1, K2)|
```

## API Usage

### Basic Agent Interaction

```elixir
# Initialize an agent
{:ok, config} = Anderson.MemoryOS.AgentIntegration.initialize_agent(agent_id)

# Process a user interaction
{:ok, result} = Anderson.MemoryOS.AgentIntegration.process_interaction(
  agent_id, 
  "How does machine learning work?"
)

# Access response and memory context
response = result.response
memory_context = result.memory_context
metadata = result.metadata
```

### Memory Management

```elixir
# Get memory summary
{:ok, summary} = Anderson.MemoryOS.AgentIntegration.get_memory_summary(agent_id)

# Trigger maintenance
{:ok, maintenance} = Anderson.MemoryOS.AgentIntegration.trigger_memory_maintenance(agent_id)

# Search memories
{:ok, search_results} = Anderson.MemoryOS.AgentIntegration.search_memories(
  agent_id, 
  "What did we discuss about AI?"
)
```

### Direct LLM Client Usage

```elixir
# Process a query
{:ok, query_context} = Anderson.MemoryOS.LLMClient.process_query(query, agent_id)

# Retrieve memories
{:ok, memory_results} = Anderson.MemoryOS.LLMClient.retrieve_memories(query_context)

# Synthesize context
{:ok, context} = Anderson.MemoryOS.LLMClient.synthesize_memory_context(memory_results)
```

## Configuration

### Development Configuration

```elixir
# config/dev.exs
config :anderson,
  # Use mock embeddings unless OpenAI API key is available
  use_mock_embeddings: System.get_env("OPENAI_API_KEY") == nil,
  openai_api_key: System.get_env("OPENAI_API_KEY")
```

### Test Configuration

```elixir
# config/test.exs
config :anderson,
  # Always use mock embeddings in test environment
  use_mock_embeddings: true,
  openai_api_key: nil
```

### Memory Capacity Defaults

```elixir
# Per-agent configurable capacities
%{
  stm_capacity: 10,          # Recent dialogue pages
  mtm_capacity: 150,         # Medium-term segments
  lpm_capacity: 500,         # Long-term knowledge entries
  system_capacity: 1000,     # Shared system knowledge
  heat_threshold: 0.7,       # Heat score for LPM promotion
  similarity_threshold: 0.8   # Similarity for segment grouping
}
```

## Background Processing

### Automatic Memory Management

The system automatically manages memory through Oban-based background workers:

1. **STM Capacity Check** - Monitors STM size and transfers pages to MTM
2. **Heat Score Updates** - Recalculates heat scores and manages eviction
3. **Meta Chain Analysis** - Uses LLM to enhance dialogue understanding
4. **LPM Promotion** - Promotes hot segments to long-term memory
5. **System Transfer** - Shares valuable knowledge across agents

### Maintenance Scheduling

```elixir
# Periodic maintenance (every 30 minutes)
%{
  heat_updates: "*/30 * * * *",      # Update heat scores
  capacity_checks: "*/15 * * * *",   # Check STM capacity
  lpm_transfers: "0 */2 * * *",      # LPM evaluation every 2 hours
  system_sync: "0 4 * * *"           # Daily system knowledge sync
}
```

## Testing

### Running Tests

```bash
# Run all MemoryOS tests
mix test test/anderson/memory_os/

# Run specific test suites
mix test test/anderson/memory_os/calculations_test.exs
mix test test/anderson/memory_os/llm_client_test.exs
mix test test/anderson/memory_os/agent_integration_test.exs
```

### Test Coverage

- **Calculations**: All MemoryOS paper algorithms with mathematical verification
- **LLM Client**: Query processing, memory retrieval, and context synthesis
- **Agent Integration**: Complete interaction flows and error handling
- **Background Workers**: Memory management and maintenance operations

## Embedding Models

### OpenAI Integration

The system supports real OpenAI embeddings when an API key is provided:

```elixir
# Anderson.OpenAiEmbeddingModel
- Model: "text-embedding-3-large"
- Dimensions: 3072
- Automatic retry and error handling
```

### Mock Embeddings

For development and testing, deterministic mock embeddings are generated:

```elixir
# Mock embedding characteristics
- Dimensions: 384
- Deterministic based on text content
- Suitable for testing similarity calculations
```

## Performance Considerations

### Memory Efficiency

- **Lazy Loading**: Related data loaded only when needed
- **Batch Processing**: Background workers process multiple items efficiently
- **Capacity Limits**: Automatic eviction prevents unbounded growth

### Scalability

- **Agent Isolation**: Each agent has independent memory spaces
- **Background Processing**: Heavy operations moved to background jobs
- **Database Indexing**: Optimized queries for memory retrieval

## Error Handling

### Graceful Degradation

- **Missing Embeddings**: Falls back to keyword-only similarity
- **API Failures**: Uses cached or mock data when possible
- **Capacity Exceeded**: Automatic cleanup and user notification

### Logging and Monitoring

- **Structured Logging**: Comprehensive logging at appropriate levels
- **Error Context**: Detailed error information for debugging
- **Performance Metrics**: Memory usage and processing time tracking

## Integration Examples

### Custom Agent Implementation

```elixir
defmodule MyApp.CustomAgent do
  alias Anderson.MemoryOS.AgentIntegration

  def start_conversation(agent_id) do
    # Initialize the agent's memory system
    {:ok, _config} = AgentIntegration.initialize_agent(agent_id)
    
    # Agent is ready for interactions
    :ok
  end
  
  def handle_user_message(agent_id, message) do
    case AgentIntegration.process_interaction(agent_id, message) do
      {:ok, %{response: response, memory_context: context}} ->
        # Use memory context to inform response generation
        enhanced_response = enhance_with_context(response, context)
        {:ok, enhanced_response}
        
      {:error, reason} ->
        {:error, "Failed to process message: #{reason}"}
    end
  end
  
  defp enhance_with_context(response, context) do
    # Use memory context to provide more relevant responses
    relevant_topics = context.relevant_topics
    agent_knowledge = context.agent_knowledge
    
    # Enhance response based on memory context
    response
  end
end
```

### Phoenix LiveView Integration

```elixir
defmodule MyAppWeb.ChatLive do
  use MyAppWeb, :live_view
  alias Anderson.MemoryOS.AgentIntegration

  def mount(_params, %{"user_id" => user_id}, socket) do
    # Initialize agent memory for this user session
    {:ok, _config} = AgentIntegration.initialize_agent(user_id)
    
    {:ok, assign(socket, agent_id: user_id, messages: [])}
  end
  
  def handle_event("send_message", %{"message" => message}, socket) do
    agent_id = socket.assigns.agent_id
    
    case AgentIntegration.process_interaction(agent_id, message) do
      {:ok, %{response: response}} ->
        updated_messages = [
          %{role: :user, content: message},
          %{role: :assistant, content: response} | socket.assigns.messages
        ]
        
        {:noreply, assign(socket, messages: updated_messages)}
        
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to process message")}
    end
  end
end
```

## Future Enhancements

### Planned Features

1. **Multi-Modal Memory** - Support for images, documents, and structured data
2. **Memory Compression** - Advanced techniques for long-term storage optimization
3. **Cross-Agent Learning** - Improved knowledge sharing and transfer learning
4. **Real-time Analytics** - Dashboard for memory usage and performance monitoring
5. **Custom Similarity Metrics** - Domain-specific similarity calculations

### Research Integration

The implementation stays close to the original MemoryOS research while providing practical extensions:

- **Paper Compliance**: All core algorithms implemented as specified
- **Production Ready**: Error handling, testing, and monitoring
- **Extensible Design**: Easy to add new memory types and processing logic
- **Performance Optimized**: Background processing and efficient data structures

## Troubleshooting

### Common Issues

1. **Embedding Generation Failures**
   - Check OpenAI API key configuration
   - Verify network connectivity
   - Use mock embeddings for development

2. **Memory Capacity Issues**
   - Monitor STM/MTM capacity through summaries
   - Adjust capacity limits in agent configuration
   - Trigger manual maintenance if needed

3. **Background Job Failures**
   - Check Oban configuration and database connectivity
   - Review worker logs for specific error details
   - Ensure database migrations are up to date

### Debug Commands

```elixir
# Check agent memory status
{:ok, summary} = Anderson.MemoryOS.AgentIntegration.get_memory_summary(agent_id)

# Trigger immediate maintenance
{:ok, result} = Anderson.MemoryOS.AgentIntegration.trigger_memory_maintenance(agent_id)

# Search for specific memories
{:ok, results} = Anderson.MemoryOS.AgentIntegration.search_memories(agent_id, "search term")
```

This completes the documentation for the MemoryOS implementation. The system provides a complete, production-ready memory architecture for AI agents following the research paper specifications while adding practical enhancements for real-world usage. 