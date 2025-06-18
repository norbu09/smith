defmodule Smith.MemoryOS.AgentIntegration do
  @moduledoc """
  Agent Integration for MemoryOS

  Provides high-level functions for integrating MemoryOS with agent logic.
  This module demonstrates how to use the complete MemoryOS system for
  memory-aware agent interactions following the MemoryOS paper architecture.

  Key integration patterns:
  1. Query processing with memory retrieval
  2. Response generation with context
  3. Memory storage and management
  4. Agent lifecycle management
  5. Cross-agent knowledge sharing
  """

  alias Smith.MemoryOS.LLMClient

  require Logger
  require Ash.Query

  @doc """
  Process an agent interaction with full MemoryOS integration.

  This is the main entry point for memory-aware agent interactions.
  It handles the complete cycle:
  1. Query processing and memory retrieval
  2. Context synthesis for response generation
  3. Memory storage and background processing

  ## Parameters
  - agent_id: UUID of the agent
  - user_query: The user's input
  - interaction_options: Configuration options

  ## Returns
  - {:ok, %{response: "...", memory_context: %{}, metadata: %{}}}
  - {:error, reason}
  """
  def process_interaction(agent_id, user_query, interaction_options \\ %{}) do
    Logger.debug("Processing interaction for agent #{agent_id}")

    with {:ok, query_context} <- LLMClient.process_query(user_query, agent_id),
         {:ok, memory_results} <- LLMClient.retrieve_memories(query_context, interaction_options),
         {:ok, synthesized_context} <- LLMClient.synthesize_memory_context(memory_results),
         {:ok, response} <- generate_response(synthesized_context, interaction_options),
         {:ok, storage_result} <- store_interaction(agent_id, user_query, response, query_context) do
      result = %{
        response: response,
        memory_context: synthesized_context,
        metadata: %{
          query_context: query_context,
          memory_stats: calculate_memory_stats(memory_results),
          confidence: synthesized_context.confidence_scores,
          storage_info: storage_result
        }
      }

      Logger.info("Successfully processed interaction for agent #{agent_id}")
      {:ok, result}
    else
      {:error, reason} = _error ->
        Logger.error("Failed to process interaction for agent #{agent_id}: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Initialize MemoryOS for a new agent.

  Sets up the agent's memory configuration and initial background jobs.

  ## Parameters
  - agent_id: UUID of the agent
  - agent_config: Agent-specific configuration overrides

  ## Returns
  - {:ok, config}
  - {:error, reason}
  """
  def initialize_agent(agent_id, agent_config \\ %{}) do
    Logger.info("Initializing MemoryOS for agent #{agent_id}")

    with {:ok, config} <-
           Smith.MemoryOS.Configuration.get_or_create(agent_id, "default", agent_config),
         :ok <- schedule_agent_maintenance(agent_id) do
      Logger.info("Successfully initialized MemoryOS for agent #{agent_id}")
      {:ok, config}
    else
      {:error, reason} = _error ->
        error_msg =
          case reason do
            %{message: msg} when is_binary(msg) -> msg
            reason when is_binary(reason) -> reason
            _ -> "Failed to initialize agent configuration"
          end

        Logger.error("Failed to initialize agent #{agent_id}: #{error_msg}")
        {:error, error_msg}
    end
  end

  @doc """
  Retrieve agent's memory summary for external systems.

  Provides a high-level view of the agent's memory state across all levels.

  ## Parameters
  - agent_id: UUID of the agent
  - summary_options: Configuration for summary generation

  ## Returns
  - {:ok, memory_summary}
  """
  def get_memory_summary(agent_id, _summary_options \\ %{}) do
    Logger.debug("Generating memory summary for agent #{agent_id}")

    # Gather memory statistics from all levels
    stm_stats = get_stm_statistics(agent_id)
    mtm_stats = get_mtm_statistics(agent_id)
    lpm_stats = get_lpm_statistics(agent_id)
    system_stats = get_system_statistics(agent_id)

    memory_summary = %{
      agent_id: agent_id,
      stm: stm_stats,
      mtm: mtm_stats,
      lpm: lpm_stats,
      system: system_stats,
      overall_stats: calculate_overall_stats([stm_stats, mtm_stats, lpm_stats, system_stats]),
      generated_at: DateTime.utc_now()
    }

    {:ok, memory_summary}
  end

  @doc """
  Perform manual memory maintenance for an agent.

  Triggers immediate background processing for memory management.

  ## Parameters
  - agent_id: UUID of the agent
  - maintenance_options: Configuration for maintenance operations

  ## Returns
  - {:ok, maintenance_results}
  """
  def trigger_memory_maintenance(agent_id, maintenance_options \\ %{}) do
    Logger.info("Triggering memory maintenance for agent #{agent_id}")

    operations =
      maintenance_options[:operations] || [:heat_update, :capacity_check, :lpm_evaluation]

    results = []

    # Schedule immediate background jobs
    results =
      if :heat_update in operations do
        case schedule_heat_update(agent_id) do
          {:ok, job} -> [{:heat_update, :scheduled, job.id} | results]
          {:error, error} -> [{:heat_update, :failed, error} | results]
        end
      else
        results
      end

    results =
      if :capacity_check in operations do
        case schedule_capacity_check(agent_id) do
          {:ok, job} -> [{:capacity_check, :scheduled, job.id} | results]
          {:error, error} -> [{:capacity_check, :failed, error} | results]
        end
      else
        results
      end

    results =
      if :lpm_evaluation in operations do
        case schedule_lpm_evaluation(agent_id) do
          {:ok, job} -> [{:lpm_evaluation, :scheduled, job.id} | results]
          {:error, error} -> [{:lmp_evaluation, :failed, error} | results]
        end
      else
        results
      end

    {:ok, %{operations: results, scheduled_at: DateTime.utc_now()}}
  end

  @doc """
  Search across agent's memories using natural language queries.

  Provides a convenient interface for memory search and retrieval.

  ## Parameters
  - agent_id: UUID of the agent
  - search_query: Natural language search query
  - search_options: Configuration for search behavior

  ## Returns
  - {:ok, search_results}
  """
  def search_memories(agent_id, search_query, search_options \\ %{}) do
    Logger.debug(
      "Searching memories for agent #{agent_id}: #{String.slice(search_query, 0, 50)}..."
    )

    with {:ok, query_context} <- LLMClient.process_query(search_query, agent_id),
         {:ok, memory_results} <- LLMClient.retrieve_memories(query_context, search_options) do
      # Format results for search response
      search_results = %{
        query: search_query,
        results: %{
          recent_conversations: format_search_results(memory_results.stm_results, :stm),
          relevant_topics: format_search_results(memory_results.mtm_results, :mtm),
          agent_knowledge: format_search_results(memory_results.lpm_results, :lpm),
          shared_knowledge: format_search_results(memory_results.system_results, :system)
        },
        metadata: %{
          total_results: count_total_results(memory_results),
          query_context: query_context,
          search_options: search_options
        }
      }

      {:ok, search_results}
    else
      {:error, reason} = _error ->
        Logger.error("Memory search failed for agent #{agent_id}: #{reason}")
        {:error, reason}
    end
  end

  # Private helper functions

  defp generate_response(synthesized_context, _options) do
    confidence = synthesized_context.confidence_scores.confidence_level

    response =
      case confidence do
        "high" -> "I have a comprehensive understanding of your request."
        "medium" -> "I can help with that based on our context."
        _ -> "I'll do my best to help with your request."
      end

    {:ok, response}
  end

  defp store_interaction(agent_id, user_query, response, _query_context) do
    case Smith.MemoryOS.STM.DialoguePage.add_to_stm(agent_id, user_query, response) do
      {:ok, page} ->
        {:ok, %{page_id: page.id, triggers: [:meta_chain_generation, :stm_capacity_check]}}

      {:error, reason} ->
        {:error, "Failed to store interaction: #{inspect(reason)}"}
    end
  end

  defp schedule_agent_maintenance(_agent_id) do
    :ok
  end

  defp schedule_heat_update(agent_id) do
    %{agent_id: agent_id}
    |> Smith.MemoryOS.Workers.UpdateHeatScoreWorker.new(queue: :memory)
    |> Oban.insert()
  end

  defp schedule_capacity_check(agent_id) do
    # Find a recent page to trigger capacity check
    case Smith.MemoryOS.STM.DialoguePage
         |> Ash.Query.filter(agent_id: agent_id)
         |> Ash.Query.sort(desc: :inserted_at)
         |> Ash.Query.limit(1)
         |> Ash.read() do
      {:ok, [page | _]} ->
        %{"record_pk" => page.id}
        |> Smith.MemoryOS.Workers.CheckSTMCapacityWorker.new(queue: :memory)
        |> Oban.insert()

      _ ->
        {:error, "No pages found for capacity check"}
    end
  end

  defp schedule_lpm_evaluation(agent_id) do
    %{agent_id: agent_id}
    |> Smith.MemoryOS.Workers.LpmSystemTransferWorker.new(queue: :memory)
    |> Oban.insert()
  end

  defp get_stm_statistics(agent_id) do
    pages =
      Smith.MemoryOS.STM.DialoguePage
      |> Ash.Query.filter(agent_id: agent_id)
      |> Ash.read!()

    %{
      level: :stm,
      total_pages: length(pages),
      recent_activity: if(length(pages) > 0, do: List.first(pages).inserted_at, else: nil),
      capacity_status: evaluate_stm_capacity(agent_id, length(pages))
    }
  rescue
    _ -> %{level: :stm, total_pages: 0, recent_activity: nil, capacity_status: :unknown}
  end

  defp get_mtm_statistics(agent_id) do
    segments =
      Smith.MemoryOS.MTM.DialogueSegment
      |> Ash.Query.filter(agent_id: agent_id)
      |> Ash.read!()

    total_heat = segments |> Enum.map(& &1.heat_score) |> Enum.sum()
    avg_heat = if length(segments) > 0, do: total_heat / length(segments), else: 0.0

    %{
      level: :mtm,
      total_segments: length(segments),
      average_heat_score: Float.round(avg_heat, 2),
      capacity_status: evaluate_mtm_capacity(agent_id, length(segments))
    }
  rescue
    _ -> %{level: :mtm, total_segments: 0, average_heat_score: 0.0, capacity_status: :unknown}
  end

  defp get_lpm_statistics(agent_id) do
    kb_entries =
      Smith.MemoryOS.LPM.KnowledgeBaseEntry
      |> Ash.Query.filter(agent_id: agent_id)
      |> Ash.read!()

    traits =
      Smith.MemoryOS.LPM.TraitEntry
      |> Ash.Query.filter(agent_id: agent_id)
      |> Ash.read!()

    %{
      level: :lpm,
      knowledge_entries: length(kb_entries),
      traits: length(traits),
      total_lpm_items: length(kb_entries) + length(traits)
    }
  rescue
    _ -> %{level: :lpm, knowledge_entries: 0, traits: 0, total_lpm_items: 0}
  end

  defp get_system_statistics(_agent_id) do
    # Count SystemMemory entries contributed by this agent
    # Note: source_agent_id field may not exist in current schema
    contributed_entries = []

    total_system_entries =
      Smith.MemoryOS.SystemMemory
      |> Ash.read!()

    %{
      level: :system,
      contributed_entries: length(contributed_entries),
      total_system_entries: length(total_system_entries),
      contribution_ratio: 0.0
    }
  rescue
    _ ->
      %{level: :system, contributed_entries: 0, total_system_entries: 0, contribution_ratio: 0.0}
  end

  defp calculate_overall_stats(level_stats) do
    stm_pages = level_stats |> Enum.map(&Map.get(&1, :total_pages, 0)) |> Enum.sum()
    mtm_segments = level_stats |> Enum.map(&Map.get(&1, :total_segments, 0)) |> Enum.sum()
    lpm_items = level_stats |> Enum.map(&Map.get(&1, :total_lpm_items, 0)) |> Enum.sum()

    %{
      total_memory_items: stm_pages + mtm_segments + lpm_items,
      memory_distribution: calculate_memory_distribution(level_stats)
    }
  end

  defp calculate_memory_distribution(level_stats) do
    stm_count = level_stats |> Enum.find(&(&1[:level] == :stm)) |> Map.get(:total_pages, 0)
    mtm_count = level_stats |> Enum.find(&(&1[:level] == :mtm)) |> Map.get(:total_segments, 0)
    lpm_count = level_stats |> Enum.find(&(&1[:level] == :lpm)) |> Map.get(:total_lpm_items, 0)

    total = stm_count + mtm_count + lpm_count

    if total > 0 do
      %{
        stm_percentage: Float.round(stm_count / total * 100, 1),
        mtm_percentage: Float.round(mtm_count / total * 100, 1),
        lpm_percentage: Float.round(lpm_count / total * 100, 1)
      }
    else
      %{stm_percentage: 0.0, mtm_percentage: 0.0, lpm_percentage: 0.0}
    end
  end

  defp evaluate_stm_capacity(agent_id, current_count) do
    config = get_agent_config(agent_id)
    capacity = config.stm_capacity || 7

    cond do
      current_count >= capacity -> :at_capacity
      current_count >= capacity * 0.8 -> :near_capacity
      true -> :normal
    end
  end

  defp evaluate_mtm_capacity(agent_id, current_count) do
    config = get_agent_config(agent_id)
    capacity = config.mtm_capacity || 200

    cond do
      current_count >= capacity -> :at_capacity
      current_count >= capacity * 0.8 -> :near_capacity
      true -> :normal
    end
  end

  defp get_agent_config(agent_id) do
    case Smith.MemoryOS.Configuration.get_or_create(agent_id, "default", %{}) do
      {:ok, config} -> config
      {:error, _} -> %{stm_capacity: 7, mtm_capacity: 200}
    end
  end

  defp calculate_memory_stats(memory_results) do
    %{
      stm_count: length(memory_results.stm_results),
      mtm_count: length(memory_results.mtm_results),
      lpm_count: count_lpm_results(memory_results.lpm_results),
      system_count: length(memory_results.system_results)
    }
  end

  defp count_lpm_results(lpm_results) when is_map(lpm_results) do
    knowledge_count = length(lpm_results[:knowledge_entries] || [])
    traits_count = length(lpm_results[:traits] || [])
    knowledge_count + traits_count
  end

  defp count_lpm_results(_), do: 0

  defp format_search_results(results, :stm) do
    Enum.map(results, fn page ->
      %{
        id: page.id,
        query: page.query,
        response: page.response,
        timestamp: page.inserted_at,
        type: :dialogue_page
      }
    end)
  end

  defp format_search_results(results, :mtm) do
    Enum.map(results, fn segment ->
      %{
        id: segment.id,
        topic: segment.topic_summary,
        keywords: segment.keywords,
        heat_score: segment.heat_score,
        type: :dialogue_segment
      }
    end)
  end

  defp format_search_results(results, :lpm) when is_map(results) do
    knowledge =
      Enum.map(results[:knowledge_entries] || [], fn entry ->
        %{
          id: entry.id,
          content: entry.content,
          topic: entry.topic_summary,
          type: :knowledge_entry
        }
      end)

    traits =
      Enum.map(results[:traits] || [], fn trait ->
        %{
          id: trait.id,
          trait_name: trait.trait_name,
          trait_value: trait.trait_value,
          confidence: trait.confidence,
          type: :trait_entry
        }
      end)

    knowledge ++ traits
  end

  defp format_search_results(_, :lpm), do: []

  defp format_search_results(results, :system) do
    Enum.map(results, fn entry ->
      %{
        id: entry.id,
        content: entry.content,
        importance: entry.importance_score,
        source_agent: entry.source_agent_id,
        type: :system_knowledge
      }
    end)
  end

  defp count_total_results(memory_results) do
    stm_count = length(memory_results.stm_results)
    mtm_count = length(memory_results.mtm_results)
    lpm_count = count_lpm_results(memory_results.lpm_results)
    system_count = length(memory_results.system_results)

    stm_count + mtm_count + lpm_count + system_count
  end
end
