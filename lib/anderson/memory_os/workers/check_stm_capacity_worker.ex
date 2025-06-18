defmodule Anderson.MemoryOS.Workers.CheckSTMCapacityWorker do
  @moduledoc """
  STM-MTM Transfer Worker

  Implements the MemoryOS paper algorithm for transferring dialogue pages
  from STM to MTM when STM reaches capacity. This worker:

  1. Checks if agent's STM exceeds capacity limits
  2. Identifies oldest pages for transfer
  3. Groups pages into segments using Fscore similarity
  4. Creates new DialogueSegments or adds to existing ones
  5. Updates page references and removes from STM
  """

  use Oban.Worker, queue: :memory, max_attempts: 3

  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"record_pk" => page_id}}) do
    # Load the dialogue page that triggered this check
    case Anderson.MemoryOS.STM.DialoguePage.by_id(page_id) do
      {:ok, page} ->
        check_and_transfer_stm_capacity(page.agent_id)

      {:error, error} ->
        {:error, "Failed to load dialogue page: #{inspect(error)}"}
    end
  end

  defp check_and_transfer_stm_capacity(agent_id) do
    # Get agent's configuration
    config = get_agent_config(agent_id)
    stm_capacity = config.stm_capacity

    # Get all STM pages for this agent, ordered by creation time
    stm_pages = Anderson.MemoryOS.STM.DialoguePage
    |> Ash.Query.filter(agent_id == ^agent_id and is_nil(dialogue_segment_id))
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.read!()

    pages_count = length(stm_pages)

    if pages_count > stm_capacity do
      # Calculate how many pages to transfer
      pages_to_transfer_count = pages_count - stm_capacity
      pages_to_transfer = Enum.take(stm_pages, pages_to_transfer_count)

      # Transfer pages to MTM using MemoryOS algorithms
      Enum.each(pages_to_transfer, &transfer_page_to_mtm/1)

      {:ok, "Transferred #{pages_to_transfer_count} pages from STM to MTM for agent #{agent_id}"}
    else
      {:ok, "STM capacity (#{pages_count}/#{stm_capacity}) within limits for agent #{agent_id}"}
    end
  end

  defp transfer_page_to_mtm(page) do
    # Step 1: Find the best existing segment for this page using Fscore
    best_segment = find_best_segment_for_page(page)

    case best_segment do
      {:ok, segment} ->
        # Add page to existing segment
        case Ash.update(segment, :add_page_to_segment, %{id: segment.id, page_id: page.id}) do
          {:ok, _updated_segment} -> :ok
          {:error, error} -> {:error, "Failed to add page to segment: #{inspect(error)}"}
        end

      {:not_found, _reason} ->
        # Create a new segment from this page
        case Anderson.MemoryOS.MTM.DialogueSegment.create_from_page(page.id) do
          {:ok, _segment} ->
            :ok

          {:error, error} ->
            {:error, "Failed to create segment from page: #{inspect(error)}"}
        end
    end
  end

  defp find_best_segment_for_page(page) do
    # Get agent's configuration for Fscore threshold
    config = get_agent_config(page.agent_id)
    fscore_threshold = config.mtm_fscore_threshold

    # Get all existing segments for this agent
    segments = Anderson.MemoryOS.MTM.DialogueSegment
    |> Ash.Query.filter(agent_id == ^page.agent_id)
    |> Ash.read!()

    if Enum.empty?(segments) do
      {:not_found, "No existing segments for agent"}
    else
      # Calculate Fscore for each segment
      # Note: In a full implementation, we would extract embeddings and keywords from the page
      # For now, we use a simplified approach based on text similarity

      segment_scores = Enum.map(segments, fn segment ->
        # Prepare context for similarity calculation
        context = %{
          query_embedding: extract_page_embedding(page),
          query_keywords: extract_page_keywords(page)
        }

        # Load the segment with Fscore calculation
        segment_with_fscore = Anderson.MemoryOS.MTM.DialogueSegment
        |> Ash.Query.filter(id == ^segment.id)
        |> Ash.Query.load(fscore: context)
        |> Ash.read_one!()

        {segment, segment_with_fscore.fscore || 0.0}
      end)

      # Find the segment with the highest Fscore above threshold
      best_match = segment_scores
      |> Enum.filter(fn {_segment, score} -> score >= fscore_threshold end)
      |> Enum.max_by(fn {_segment, score} -> score end, fn -> nil end)

      case best_match do
        {segment, _score} ->
          {:ok, segment}

        nil ->
          {:not_found, "No segment above Fscore threshold #{fscore_threshold}"}
      end
    end
  end

  defp extract_page_embedding(_page) do
    # In a full implementation, this would use the embedding model
    # to generate embeddings from page.query and page.response
    # For now, return a placeholder
    []
  end

  defp extract_page_keywords(page) do
    # In a full implementation, this would use LLM to extract keywords
    # from page.query and page.response
    # For now, return simple word extraction
    text = "#{page.query} #{page.response}"
    text
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    |> Enum.filter(&(String.length(&1) > 3))
    |> Enum.uniq()
    |> Enum.take(10)  # Limit to 10 keywords
  end

  defp get_agent_config(agent_id) do
    # Get or create configuration for this agent with defaults
    case Anderson.MemoryOS.Configuration.get_or_create(agent_id, "default", %{}) do
      {:ok, config} -> config
      {:error, _} ->
        # Fallback to application defaults
        %{
          stm_capacity: Application.get_env(:anderson, :memory_os)[:default_stm_capacity] || 7,
          mtm_fscore_threshold: Application.get_env(:anderson, :memory_os)[:default_fscore_threshold] || 0.6
        }
    end
  end
end
