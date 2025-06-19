# Smith MemoryOS Usage Rules

This document provides comprehensive guidance for effectively using the Smith MemoryOS library - a sophisticated memory management system for AI agents built on Elixir/OTP using the Ash framework.

## Core Concepts

Smith implements the MemoryOS architecture with a hierarchical memory system:

- **Short-Term Memory (STM)**: Recent conversation data stored as dialogue pages (7 pages max)
- **Mid-Term Memory (MTM)**: Topic-based segments using semantic similarity (200 segments max)
- **Long-Term Personal Memory (LPM)**: Persistent knowledge about entities and agent personas
- **System Memory**: Cross-agent shared knowledge store

## Working with Memory Resources

### Memory Configuration

All memory operations start with creating a Configuration resource:

```elixir
config = Smith.MemoryOS.create_configuration!(%{
  agent_type: "assistant",
  stm_capacity: 7,
  mtm_capacity: 200,
  heat_alpha: 1.0,
  heat_beta: 1.0,
  heat_gamma: 1.0,
  heat_threshold: 5.0
})
```

### Short-Term Memory (STM)

STM stores recent conversation data as dialogue pages:

```elixir
# Create a new dialogue page
dialogue_page = Smith.MemoryOS.STM.create_dialogue_page!(%{
  query: "What's the weather like today?",
  response: "I don't have access to real-time weather data...",
  timestamp: DateTime.utc_now(),
  agent_id: agent_id,
  user_id: user_id
})

# Retrieve all STM pages for an agent
stm_pages = Smith.MemoryOS.STM.list_dialogue_pages!(
  filter: [agent_id: agent_id],
  sort: [timestamp: :desc]
)
```

### Mid-Term Memory (MTM)

MTM organizes related dialogue pages into semantic segments:

```elixir
# Create a dialogue segment
segment = Smith.MemoryOS.MTM.create_dialogue_segment!(%{
  topic: "Weather Discussion",
  summary: "User asking about weather conditions",
  agent_id: agent_id,
  heat_score: 0.0
})

# Search segments by semantic similarity
relevant_segments = Smith.MemoryOS.MTM.search_by_similarity!(
  "weather forecast",
  limit: 5
)
```

### Long-Term Personal Memory (LPM)

LPM maintains persistent knowledge about users and agents:

```elixir
# Create object persona (user profile)
user_persona = Smith.MemoryOS.LPM.create_object_persona!(%{
  name: "John Doe",
  persona_type: "user",
  static_attributes: %{
    "age" => 30,
    "location" => "San Francisco"
  },
  agent_id: agent_id
})

# Create agent persona
agent_persona = Smith.MemoryOS.LPM.create_agent_persona!(%{
  name: "Assistant",
  persona_type: "assistant",
  role: "helpful_assistant",
  agent_id: agent_id
})

# Add knowledge base entries
kb_entry = Smith.MemoryOS.LPM.create_knowledge_base_entry!(%{
  content: "User prefers morning meetings",
  category: "preferences",
  agent_id: agent_id,
  object_persona_id: user_persona.id
})
```

### System Memory

System Memory stores cross-agent knowledge:

```elixir
# Contribute to system memory
system_entry = Smith.MemoryOS.contribute_system_memory!(
  "Python is a programming language",
  agent_id,
  0.8  # importance score
)

# Search system memory
relevant_knowledge = Smith.MemoryOS.search_system_memory_by_similarity!(
  "programming languages",
  limit: 10
)
```

## Memory Operations and Algorithms

### Fscore Calculation

The system uses Fscore for semantic segmentation:

```
Fscore = cos(e_s, e_p) + FJacard(K_s, K_p)
```

Where:
- `e_s` and `e_p` are embedding vectors
- `K_s` and `K_p` are keyword sets
- `FJacard` is Jaccard similarity

### Heat Score Management

Heat scores determine memory importance:

```
Heat = α·N_visit + β·L_interaction + γ·R_recency
```

Where:
- `N_visit`: Number of retrievals
- `L_interaction`: Length of interaction
- `R_recency`: Time decay factor

### Memory Transfer Processes

#### STM → MTM Transfer

Automatically triggered when STM reaches capacity (7 pages):

```elixir
# This happens automatically via background workers
# The oldest dialogue page is transferred to MTM using FIFO
```

#### MTM → LPM Promotion

Segments with high heat scores (>5.0) are promoted to LPM:

```elixir
# Background workers handle this automatically
# High-heat segments update user/agent personas
```

## Background Processing

Smith uses Oban for background memory management:

### Key Workers

1. **CheckStmCapacityWorker**: Monitors STM capacity and triggers transfers
2. **UpdateHeatScoreWorker**: Recalculates heat scores for MTM segments
3. **LpmSystemTransferWorker**: Handles MTM→LPM promotions
4. **UpdateMetaChainWorker**: Maintains dialogue chain coherence

### Configuring Background Jobs

```elixir
# In your config/config.exs
config :smith, Oban,
  repo: Smith.Repo,
  queues: [memory: 10, default: 5],
  plugins: [Oban.Plugins.Pruner]
```

## Vector Search and Embeddings

### Setting Up Embeddings

Smith automatically generates embeddings for content using AshAI:

```elixir
# Embeddings are generated automatically when content is created
# No manual intervention needed for most use cases

# The system uses OpenAI embeddings by default
# Configure in your environment:
# OPENAI_API_KEY=your_api_key
```

### Semantic Search

Use vector similarity for memory retrieval:

```elixir
# Search across all memory tiers
results = Smith.MemoryOS.search_memories!(
  agent_id,
  "user's favorite activities",
  %{
    stm_limit: 5,
    mtm_limit: 10,
    lpm_limit: 15
  }
)
```

## Integration Patterns

### Phoenix LiveView Integration

```elixir
defmodule SmithWeb.ChatLive do
  use SmithWeb, :live_view

  def handle_event("send_message", %{"message" => message}, socket) do
    agent_id = socket.assigns.agent_id
    user_id = socket.assigns.user_id
    
    # Process the message through MemoryOS
    response = Smith.MemoryOS.process_interaction!(
      agent_id,
      user_id,
      message
    )
    
    {:noreply, assign(socket, :messages, [response | socket.assigns.messages])}
  end
end
```

### Agent Integration

```elixir
defmodule MyApp.Assistant do
  def process_query(agent_id, user_id, query) do
    # Retrieve relevant memories
    context = Smith.MemoryOS.retrieve_context!(agent_id, query)
    
    # Generate response using LLM with memory context
    response = generate_response(query, context)
    
    # Store the interaction
    Smith.MemoryOS.store_interaction!(
      agent_id,
      user_id,
      query,
      response
    )
    
    response
  end
end
```

## Configuration Management

### Memory Thresholds

```elixir
# Configure memory system parameters
config :smith, Smith.MemoryOS,
  stm_capacity: 7,
  mtm_capacity: 200,
  lpm_kb_capacity: 100,
  lpm_traits_capacity: 100,
  fscore_threshold: 0.6,
  heat_threshold: 5.0,
  heat_alpha: 1.0,
  heat_beta: 1.0,
  heat_gamma: 1.0,
  time_constant: 1.0e7
```

### LLM Configuration

```elixir
# Configure LLM clients
config :smith, Smith.MemoryOS.LLMClient,
  default_model: "gpt-4",
  temperature: 0.7,
  max_tokens: 1000,
  embedding_model: "text-embedding-3-large"
```

## Testing Memory Operations

### Unit Testing

```elixir
defmodule Smith.MemoryOSTest do
  use Smith.DataCase
  
  test "stores and retrieves dialogue pages" do
    config = create_test_configuration()
    
    page = Smith.MemoryOS.STM.create_dialogue_page!(%{
      query: "test query",
      response: "test response",
      agent_id: config.agent_id
    })
    
    assert page.query == "test query"
  end
end
```

### Integration Testing

```elixir
test "memory transfer workflow" do
  agent_id = create_test_agent()
  
  # Fill STM to capacity
  for i <- 1..8 do
    Smith.MemoryOS.STM.create_dialogue_page!(%{
      query: "query #{i}",
      response: "response #{i}",
      agent_id: agent_id
    })
  end
  
  # Verify transfer occurred
  assert Smith.MemoryOS.STM.count_pages(agent_id) == 7
  assert Smith.MemoryOS.MTM.count_segments(agent_id) > 0
end
```

## Performance Optimization

### Batch Operations

```elixir
# Process multiple interactions efficiently
interactions = [
  %{query: "q1", response: "r1"},
  %{query: "q2", response: "r2"}
]

Smith.MemoryOS.batch_store_interactions!(agent_id, user_id, interactions)
```

### Memory Cleanup

```elixir
# Periodically clean up old, low-heat memories
Smith.MemoryOS.cleanup_old_memories!(
  agent_id,
  older_than: ~D[2024-01-01],
  min_heat_score: 1.0
)
```

## Error Handling

### Common Error Patterns

```elixir
case Smith.MemoryOS.create_dialogue_page(params) do
  {:ok, page} -> 
    # Success
    page
    
  {:error, %Ash.Error.Invalid{} = error} ->
    # Validation error
    handle_validation_error(error)
    
  {:error, %Ash.Error.Framework{} = error} ->
    # Framework error
    handle_framework_error(error)
end
```

### Monitoring and Observability

```elixir
# Add telemetry for memory operations
:telemetry.attach(
  "memory-metrics",
  [:smith, :memory_os, :operation],
  &MyApp.Telemetry.handle_memory_event/4,
  %{}
)
```

## Best Practices

1. **Use code interfaces**: Always use domain code interfaces rather than direct Ash calls
2. **Batch operations**: Use batch operations for better performance when processing multiple items
3. **Monitor heat scores**: Keep track of memory heat scores to understand system behavior
4. **Configure thresholds**: Tune memory thresholds based on your use case requirements
5. **Test memory flows**: Write comprehensive tests for memory transfer and retrieval workflows
6. **Handle embeddings**: Ensure proper error handling for embedding generation failures
7. **Use background jobs**: Leverage Oban workers for memory management operations
8. **Monitor capacity**: Set up alerts for memory capacity limits

## Troubleshooting

### Common Issues

1. **Embeddings not generating**: Check OpenAI API key configuration
2. **Memory transfers not occurring**: Verify Oban is running and configured properly
3. **High memory usage**: Tune capacity limits and cleanup policies
4. **Slow semantic search**: Ensure proper indexing on vector columns
5. **Heat score calculation errors**: Verify time constants and coefficient values

### Debugging Tools

```elixir
# Check memory system status
Smith.MemoryOS.system_status(agent_id)

# Analyze heat score distribution
Smith.MemoryOS.analyze_heat_scores(agent_id)

# View memory transfer logs
Smith.MemoryOS.get_transfer_history(agent_id, limit: 10)
```

This comprehensive guide should help you effectively use the Smith MemoryOS library for building sophisticated AI agents with advanced memory capabilities.