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

### Phase 3: Memory Management Processes
- [ ] Implement STM-MTM transfer process with an Oban worker.
- [ ] Implement MTM management process (heat calculation, eviction) with a periodic Oban worker.
- [ ] Implement LPM to SystemMemory transfer process.

### Phase 4: Agent & LLM Integration
- [ ] Implement the `MemoryOS.LLMClient` module.
- [ ] Implement the multi-level memory retrieval process.
- [ ] Integrate MemoryOS with the agent logic using AshAI.

### Phase 5: Optimization & Testing
- [ ] Configure vector storage and embedding generation.
- [ ] Write unit tests for calculations and pure functions.
- [ ] Write integration tests for memory management flows.
- [ ] Document the final implementation.

## Current Goal

Phase 2 (Core Logic) has been completed! All MemoryOS algorithms from the paper have been implemented and integrated successfully.

**Next Steps**: Proceed to Phase 3 (Memory Management Processes) to implement STM-MTM transfer and background jobs.
