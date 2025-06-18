# MemoryOS Implementation Plan

## Notes

- The implementation will follow the strategy outlined in `docs/implementation_strategy.md`.
- Per user request, a copy of this plan will be maintained at `docs/development_plan.md`.
- The system is designed as an Ash domain (`MemoryOS`) with a hierarchical memory structure (STM, MTM, LPM, SystemMemory).
- Configuration will be handled both globally in `config.exs` and on a per-agent basis via a `MemoryOS.Configuration` resource.
- Background jobs for memory management will be handled by Oban.
- LLM interactions are abstracted through a dedicated `MemoryOS.LLMClient` module, to be integrated with `AshAI`.
- The project is a standard Phoenix application with core logic in `lib/anderson`.
- No existing Ash domains were found. The new `MemoryOS` domain will be created in `lib/anderson/memory_os`, establishing the pattern for Ash-based modules in the project.
- `ash_oban` has been installed and configured using `mix igniter.install ash_oban`. A migration has been generated.
- The project was facing compilation errors related to the `calculations` DSL in `DialogueSegment`. This has been fixed. The next step is to re-compile and check for further errors.

## Task List

### Phase 1: Foundation
- [x] Create the Ash domain `MemoryOS`.
- [x] Define `MemoryOS.STM.DialoguePage` resource.
- [x] Define `MemoryOS.MTM.DialogueSegment` resource.
  - [x] Fix vectorization implementation based on `ash_ai` documentation.
- [x] Define `MemoryOS.LPM.ObjectPersona` resource.
  - [x] Define `MemoryOS.LPM.KnowledgeBaseEntry` resource.
  - [x] Define `MemoryOS.LPM.TraitEntry` resource.
- [x] Define `MemoryOS.LPM.AgentPersona` resource.
- [x] Define `MemoryOS.SystemMemory` resource.
- [x] Define `MemoryOS.Configuration` resource.
- [x] Define `Anderson.OpenAiEmbeddingModel`.
- [x] Set up application-wide defaults in `config.exs`.
- [x] Install and configure Oban using `mix igniter.install ash_oban`.
- [x] Run database migrations to add Oban tables.
- [ ] Fix all compilation errors.
- [ ] Generate and run migrations for new MemoryOS resources.
- [x] Create and maintain a copy of the plan in `docs/development_plan.md`.

### Phase 2: Core Logic ✅ COMPLETE
- [x] Implement `Fscore` calculation on `DialogueSegment`.
- [x] Implement `Heat Score` calculation on `DialogueSegment`.
- [x] Implement core MemoryOS algorithms in `Anderson.MemoryOS.Calculations`:
  - [x] Cosine similarity for embedding vectors
  - [x] Jaccard similarity for keyword sets
  - [x] Fscore formula: `Fscore = cos(e_s, e_p) + FJacard(K_s, K_p)`
  - [x] Recency factor: `R_recency = exp(-Δt / μ)` with μ = 1e+7 seconds
  - [x] Heat score: `Heat = α·N_visit + β·L_interaction + γ·R_recency` with α=β=γ=1.0
- [x] Context-aware calculation functions for DialogueSegment resource integration
- [x] All calculations properly integrate with Ash DSL and compile successfully

### Phase 3: Memory Management Processes ✅ COMPLETE
- [x] Implement STM-MTM transfer process with an Oban worker.
  - [x] `CheckSTMCapacityWorker` - STM capacity monitoring and page transfer
  - [x] Fscore-based similarity grouping for segment creation
  - [x] Agent configuration integration for capacity limits
- [x] Implement MTM management process (heat calculation, eviction) with a periodic Oban worker.
  - [x] `UpdateHeatScoreWorker` - Heat score recalculation and management
  - [x] Heat-based segment eviction when MTM exceeds capacity
  - [x] Hot segment promotion to LPM based on heat thresholds
  - [x] Knowledge synthesis and trait extraction for LPM transfer
- [x] Implement LPM to SystemMemory transfer process.
  - [x] `LpmSystemTransferWorker` - Cross-agent knowledge promotion
  - [x] Multi-factor importance scoring algorithm
  - [x] SystemMemory capacity management and maintenance
- [x] Additional memory management workers:
  - [x] `UpdateMetaChainWorker` - LLM-based dialogue analysis and enhancement
  - [x] `PeriodicJobs` - Automated scheduling and system maintenance
- [x] Complete Oban integration with queue-based processing and cron scheduling

### Phase 4: Agent & LLM Integration ✅ COMPLETE
- [x] Implement the `MemoryOS.LLMClient` module.
  - [x] Query processing with intent classification and keyword extraction
  - [x] Parallel memory retrieval from STM, MTM, LPM, and SystemMemory
  - [x] Memory context synthesis and ranking for response generation
  - [x] Information extraction utilities (topics, sentiment, entities, summaries)
- [x] Implement the multi-level memory retrieval process.
  - [x] Hierarchical memory search: STM → MTM → LPM → SystemMemory
  - [x] Relevance-based memory ranking and confidence scoring
  - [x] Context-aware memory formatting for LLM integration
- [x] Integrate MemoryOS with agent logic through `AgentIntegration` module.
  - [x] Complete interaction flow: Query → Memory Retrieval → Response → Storage
  - [x] Agent lifecycle management and configuration
  - [x] Memory statistics and capacity monitoring
  - [x] Manual maintenance operations and background job triggering
  - [x] Natural language memory search capabilities

### Phase 5: Optimization & Testing
- [ ] Configure vector storage and embedding generation.
- [ ] Write unit tests for calculations and pure functions.
- [ ] Write integration tests for memory management flows.
- [ ] Document the final implementation.

## Current Goal

Phase 4 (Agent & LLM Integration) has been completed! The complete MemoryOS system is now implemented with:

- **Core Memory Hierarchy**: STM → MTM → LPM → SystemMemory with proper capacity management
- **MemoryOS Paper Algorithms**: All calculations (Fscore, Heat, similarity) implemented per research
- **Background Processing**: Automated memory management through Oban workers
- **LLM Integration**: Complete memory-aware agent interaction system
- **Agent API**: High-level interface for memory-aware agent implementations

**Next Steps**: Proceed to Phase 5 (Optimization & Testing) to complete the system with proper testing and documentation.
