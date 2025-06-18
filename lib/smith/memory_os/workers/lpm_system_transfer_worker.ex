defmodule Smith.MemoryOS.Workers.LpmSystemTransferWorker do
  @moduledoc """
  LPM to SystemMemory Transfer Worker

  Implements the MemoryOS paper algorithm for promoting high-importance
  knowledge from agent-specific Long-term Persona Memory (LPM) to the
  global SystemMemory. This worker:

  1. Analyzes LPM entries for cross-agent importance
  2. Identifies knowledge with high general utility
  3. Promotes qualified entries to SystemMemory
  4. Maintains agent attribution and source tracking
  5. Manages SystemMemory capacity through importance-based eviction
  """

  use Oban.Worker, queue: :memory, max_attempts: 3

  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"knowledge_entry_id" => entry_id}}) do
    # Process a specific knowledge base entry for SystemMemory promotion
    case Smith.MemoryOS.LPM.KnowledgeBaseEntry.by_id(entry_id) do
      {:ok, entry} ->
        evaluate_and_promote_entry(entry)

      {:error, error} ->
        {:error, "Failed to load knowledge entry: #{inspect(error)}"}
    end
  end

  def perform(%Oban.Job{args: %{"agent_id" => agent_id}}) do
    # Periodic evaluation of all LPM entries for an agent
    evaluate_agent_lpm_for_promotion(agent_id)
  end

  def perform(%Oban.Job{args: %{"operation" => "maintenance"}}) do
    # System-wide maintenance: capacity management and importance scoring
    perform_system_memory_maintenance()
  end

  defp evaluate_and_promote_entry(entry) do
    # Calculate importance score for SystemMemory promotion
    importance_score = calculate_system_importance(entry)
    config = get_system_config()
    importance_threshold = config.system_memory_importance_threshold

    if importance_score >= importance_threshold do
      promote_to_system_memory(entry, importance_score)
    else
      {:ok, "Entry #{entry.id} does not meet SystemMemory importance threshold"}
    end
  end

  defp evaluate_agent_lpm_for_promotion(agent_id) do
    # Get all knowledge base entries for this agent
    entries =
      Smith.MemoryOS.LPM.KnowledgeBaseEntry
      |> Ash.Query.filter(agent_id == ^agent_id)
      |> Ash.read!()

    promoted_count =
      Enum.reduce(entries, 0, fn entry, acc ->
        case evaluate_and_promote_entry(entry) do
          {:ok, _message} -> acc
          {:promoted, _} -> acc + 1
          {:error, _} -> acc
        end
      end)

    {:ok,
     "Evaluated #{length(entries)} LPM entries for agent #{agent_id}, promoted #{promoted_count}"}
  end

  defp calculate_system_importance(entry) do
    # Multi-factor importance scoring for SystemMemory promotion

    # Factor 1: Cross-agent relevance (simulated)
    cross_agent_score = calculate_cross_agent_relevance(entry)

    # Factor 2: Knowledge uniqueness and utility
    utility_score = calculate_utility_score(entry)

    # Factor 3: Reference frequency and validation
    reference_score = calculate_reference_score(entry)

    # Factor 4: Content complexity and depth
    complexity_score = calculate_content_complexity(entry)

    # Weighted combination
    importance_score =
      0.3 * cross_agent_score +
        0.3 * utility_score +
        0.2 * reference_score +
        0.2 * complexity_score

    Float.round(importance_score, 4)
  end

  defp calculate_cross_agent_relevance(entry) do
    # Simulate cross-agent relevance by analyzing content generality
    content = entry.content
    keywords = entry.keywords || []

    # Check for general vs agent-specific content
    general_indicators = [
      "general",
      "common",
      "standard",
      "typical",
      "universal",
      "basic",
      "fundamental",
      "principle",
      "rule",
      "fact",
      "concept"
    ]

    specific_indicators = [
      "personal",
      "prefer",
      "my",
      "i",
      "me",
      "custom",
      "specific",
      "individual",
      "unique",
      "particular"
    ]

    content_lower = String.downcase(content)

    general_matches = Enum.count(general_indicators, &String.contains?(content_lower, &1))
    specific_matches = Enum.count(specific_indicators, &String.contains?(content_lower, &1))

    # Higher score for more general content
    base_score = general_matches / max(general_matches + specific_matches, 1)

    # Boost for knowledge-dense keywords
    knowledge_keywords = ["algorithm", "process", "method", "technique", "strategy", "approach"]
    knowledge_boost = Enum.count(keywords, &(&1 in knowledge_keywords)) * 0.1

    min(base_score + knowledge_boost, 1.0)
  end

  defp calculate_utility_score(entry) do
    # Assess practical utility and actionability
    content = entry.content
    content_lower = String.downcase(content)

    # Look for actionable content
    actionable_indicators = [
      "how to",
      "steps",
      "process",
      "method",
      "technique",
      "approach",
      "solution",
      "fix",
      "resolve",
      "implement",
      "execute",
      "perform"
    ]

    # Look for informational content
    informational_indicators = [
      "definition",
      "explanation",
      "concept",
      "theory",
      "principle",
      "fact",
      "data",
      "information",
      "knowledge",
      "understanding"
    ]

    actionable_score =
      Enum.count(actionable_indicators, &String.contains?(content_lower, &1)) * 0.1

    informational_score =
      Enum.count(informational_indicators, &String.contains?(content_lower, &1)) * 0.05

    # Content length factor (longer content often more comprehensive)
    length_factor = min(String.length(content) / 1000.0, 1.0)

    min(actionable_score + informational_score + length_factor, 1.0)
  end

  defp calculate_reference_score(entry) do
    # In a full implementation, this would track how often the entry
    # has been referenced or validated by other agents or systems
    # For now, use creation time as a proxy (older = more stable)

    days_since_creation = DateTime.diff(DateTime.utc_now(), entry.inserted_at, :day)

    # Entries that have existed longer have higher reference scores
    reference_score = min(days_since_creation / 30.0, 1.0)

    # Boost for entries with more keywords (indicates more indexing)
    keyword_boost = min(length(entry.keywords || []) / 10.0, 0.3)

    min(reference_score + keyword_boost, 1.0)
  end

  defp calculate_content_complexity(entry) do
    # Assess content depth and complexity
    content = entry.content

    # Word count factor
    word_count = content |> String.split() |> length()
    word_score = min(word_count / 100.0, 0.5)

    # Technical term density
    technical_terms = [
      "algorithm",
      "implementation",
      "architecture",
      "framework",
      "protocol",
      "optimization",
      "configuration",
      "integration",
      "methodology",
      "analysis"
    ]

    content_lower = String.downcase(content)
    technical_score = Enum.count(technical_terms, &String.contains?(content_lower, &1)) * 0.1

    # Sentence complexity (longer sentences suggest more complex ideas)
    sentences = String.split(content, ~r/[.!?]+/)

    avg_sentence_length =
      if length(sentences) > 0 do
        total_words = sentences |> Enum.map(&(String.split(&1) |> length())) |> Enum.sum()
        total_words / length(sentences)
      else
        0
      end

    sentence_complexity = min(avg_sentence_length / 20.0, 0.3)

    min(word_score + technical_score + sentence_complexity, 1.0)
  end

  defp promote_to_system_memory(entry, importance_score) do
    # Create SystemMemory entry from LPM entry
    case Smith.MemoryOS.SystemMemory.contribute(
           entry.content,
           entry.agent_id,
           importance_score
         ) do
      {:ok, system_entry} ->
        # Mark the LPM entry as promoted
        entry
        |> Ash.Changeset.for_update(:update)
        |> Ash.Changeset.change_attribute(:promoted_to_system, true)
        |> Ash.Changeset.change_attribute(:system_memory_id, system_entry.id)
        |> Ash.update!()

        {:promoted,
         "Promoted LPM entry #{entry.id} to SystemMemory with importance #{importance_score}"}

      {:error, error} ->
        {:error, "Failed to promote entry to SystemMemory: #{inspect(error)}"}
    end
  end

  defp perform_system_memory_maintenance() do
    # Get system configuration
    config = get_system_config()
    max_entries = config.system_memory_max_entries || 1000

    # Get all system memory entries ordered by importance
    entries =
      Smith.MemoryOS.SystemMemory
      |> Ash.Query.sort(desc: :importance_score)
      |> Ash.read!()

    entries_count = length(entries)

    if entries_count > max_entries do
      # Evict lowest importance entries
      entries_to_evict =
        entries
        |> Enum.drop(max_entries)
        |> length()

      evicted_entries =
        entries
        |> Enum.reverse()
        |> Enum.take(entries_to_evict)

      Enum.each(evicted_entries, fn entry ->
        # Archive before deletion
        archive_system_memory_entry(entry)
        Smith.MemoryOS.SystemMemory.destroy(entry.id)
      end)

      {:ok, "Evicted #{entries_to_evict} low-importance entries from SystemMemory"}
    else
      {:ok, "SystemMemory capacity (#{entries_count}/#{max_entries}) within limits"}
    end
  end

  defp archive_system_memory_entry(entry) do
    # In a full implementation, this would archive the entry
    # For now, just log the eviction
    require Logger

    Logger.info(
      "Evicting SystemMemory entry #{entry.id} with importance #{entry.importance_score}"
    )
  end

  defp get_system_config do
    # Get system-wide configuration
    %{
      system_memory_importance_threshold:
        Application.get_env(:smith, :memory_os)[:default_importance_threshold] || 0.8,
      system_memory_max_entries: 1000
    }
  end
end
