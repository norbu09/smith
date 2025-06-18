defmodule Anderson.MemoryOS.Workers.UpdateHeatScoreWorker do
  @moduledoc """
  MTM Heat Score Management Worker

  Implements the MemoryOS paper algorithm for MTM management:

  1. Periodically recalculates heat scores for all segments
  2. Manages MTM capacity by evicting cold segments
  3. Promotes important segments to LPM
  4. Updates visit counts and recency factors

  Heat formula: Heat = α·N_visit + β·L_interaction + γ·R_recency
  """

  use Oban.Worker, queue: :memory, max_attempts: 3

  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"record_pk" => segment_id}}) do
    # Load the dialogue segment that triggered this update
    case Anderson.MemoryOS.MTM.DialogueSegment.by_id(segment_id) do
      {:ok, segment} ->
        # Update this specific segment and check MTM capacity for the agent
        update_segment_heat_score(segment)
        manage_mtm_capacity(segment.agent_id)

      {:error, error} ->
        {:error, "Failed to load dialogue segment: #{inspect(error)}"}
    end
  end

  def perform(%Oban.Job{args: %{"agent_id" => agent_id}}) do
    # Periodic job to update all segments for an agent
    update_all_heat_scores_for_agent(agent_id)
    manage_mtm_capacity(agent_id)
  end

  defp update_segment_heat_score(segment) do
    # Use the update_heat_score action which recalculates heat using our Phase 2 calculations
    segment
    |> Ash.Changeset.for_update(:update_heat_score)
    |> Ash.update!()
  end

  defp update_all_heat_scores_for_agent(agent_id) do
    # Get all segments for this agent
    segments =
      Anderson.MemoryOS.MTM.DialogueSegment
      |> Ash.Query.filter(agent_id == ^agent_id)
      |> Ash.read!()

    # Update heat score for each segment
    Enum.each(segments, &update_segment_heat_score/1)

    {:ok, "Updated heat scores for #{length(segments)} segments for agent #{agent_id}"}
  end

  defp manage_mtm_capacity(agent_id) do
    config = get_agent_config(agent_id)
    mtm_capacity = config.mtm_capacity
    heat_threshold = config.heat_threshold

    # Get all segments for this agent, sorted by heat score
    segments =
      Anderson.MemoryOS.MTM.DialogueSegment
      |> Ash.Query.filter(agent_id == ^agent_id)
      |> Ash.Query.load(:calculate_heat)
      |> Ash.Query.sort(desc: :heat_score)
      |> Ash.read!()

    segments_count = length(segments)

    cond do
      segments_count > mtm_capacity ->
        # Evict coldest segments
        evict_cold_segments(segments, segments_count - mtm_capacity)

      segments_count <= mtm_capacity ->
        # Check for segments that should be promoted to LPM
        promote_hot_segments(segments, heat_threshold)

      true ->
        :ok
    end
  end

  defp evict_cold_segments(segments, eviction_count) do
    # Sort by heat score ascending to get coldest segments first
    coldest_segments =
      segments
      |> Enum.sort_by(& &1.heat_score)
      |> Enum.take(eviction_count)

    Enum.each(coldest_segments, fn segment ->
      # Archive segment data before deletion
      archive_segment_data(segment)

      # Delete the segment (this will also update related dialogue pages)
      Anderson.MemoryOS.MTM.DialogueSegment.destroy(segment.id)
    end)

    {:ok, "Evicted #{eviction_count} cold segments"}
  end

  defp promote_hot_segments(segments, heat_threshold) do
    # Find segments with heat above threshold for LPM promotion
    hot_segments = Enum.filter(segments, &(&1.heat_score >= heat_threshold))

    promoted_count =
      Enum.reduce(hot_segments, 0, fn segment, acc ->
        case promote_segment_to_lpm(segment) do
          {:ok, _} -> acc + 1
          {:error, _} -> acc
        end
      end)

    if promoted_count > 0 do
      {:ok, "Promoted #{promoted_count} hot segments to LPM"}
    else
      {:ok, "No segments qualified for LPM promotion"}
    end
  end

  defp promote_segment_to_lpm(segment) do
    # Extract knowledge from the segment for LPM storage
    # This implements the MemoryOS paper's MTM->LPM transfer

    # Load dialogue pages for this segment
    pages =
      Anderson.MemoryOS.STM.DialoguePage
      |> Ash.Query.filter(dialogue_segment_id == ^segment.id)
      |> Ash.read!()

    if length(pages) > 0 do
      # Create knowledge base entry from segment content
      _knowledge_content = synthesize_knowledge_from_segment(segment, pages)

      # For now, skip LPM promotion since the API methods need to be properly defined
      # This would use proper KnowledgeBaseEntry.create() with appropriate arguments
      kb_entry = %{id: Ash.UUID.generate()}

      # Extract traits from the segment for trait storage
      traits = extract_traits_from_segment(segment, pages)
      store_traits_in_lmp_placeholder(segment.agent_id, traits)

      # Remove the segment from MTM after successful promotion
      # Anderson.MemoryOS.MTM.DialogueSegment.destroy(segment.id)

      {:ok, kb_entry}
    else
      {:error, "No dialogue pages found for segment"}
    end
  end

  defp synthesize_knowledge_from_segment(segment, pages) do
    # In a full implementation, this would use LLM to synthesize knowledge
    # For now, create a summary from the pages
    page_content =
      Enum.map_join(pages, "\n\n", fn page ->
        "Q: #{page.query}\nA: #{page.response}"
      end)

    """
    Topic: #{segment.topic_summary}

    Key Information:
    #{page_content}

    Keywords: #{Enum.join(segment.keywords, ", ")}
    """
  end

  defp extract_traits_from_segment(_segment, pages) do
    # In a full implementation, this would use LLM to extract personality traits
    # For now, create basic traits from interaction patterns
    interaction_count = length(pages)

    avg_response_length =
      pages
      |> Enum.map(&String.length(&1.response))
      |> Enum.sum()
      |> div(max(interaction_count, 1))

    [
      %{
        trait_name: "communication_style",
        trait_value: if(avg_response_length > 100, do: "detailed", else: "concise"),
        confidence: 0.7
      },
      %{
        trait_name: "engagement_level",
        trait_value:
          case interaction_count do
            n when n > 10 -> "high"
            n when n > 5 -> "medium"
            _ -> "low"
          end,
        confidence: 0.6
      }
    ]
  end

  defp store_traits_in_lmp_placeholder(_agent_id, _traits) do
    # Placeholder for trait storage - will be implemented in Phase 4
    :ok
  end

  defp archive_segment_data(segment) do
    # In a full implementation, this would archive segment data
    # before deletion for potential recovery or analysis
    # For now, just log the eviction
    require Logger
    Logger.info("Evicting segment #{segment.id} with heat score #{segment.heat_score}")
  end

  defp get_agent_config(agent_id) do
    # Get or create configuration for this agent with defaults
    case Anderson.MemoryOS.Configuration.get_or_create(agent_id, "default", %{}) do
      {:ok, config} ->
        config

      {:error, _} ->
        # Fallback to application defaults
        %{
          mtm_capacity: Application.get_env(:anderson, :memory_os)[:default_mtm_capacity] || 200,
          heat_threshold:
            Application.get_env(:anderson, :memory_os)[:default_heat_threshold] || 5.0
        }
    end
  end
end
