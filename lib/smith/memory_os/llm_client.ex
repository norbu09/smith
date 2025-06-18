defmodule Smith.MemoryOS.LLMClient do
  @moduledoc """
  LLM Client for MemoryOS Integration

  Provides a unified interface for all LLM interactions within the MemoryOS system.
  Integrates with AshAI for structured LLM operations including:

  1. Memory retrieval query processing
  2. Knowledge synthesis and summarization
  3. Topic classification and keyword extraction
  4. Trait extraction and personality analysis
  5. Cross-agent knowledge evaluation

  All LLM operations are designed to support the MemoryOS paper algorithms
  with structured inputs and outputs for reliable memory management.
  """

  require Logger
  require Ash.Query

  @doc """
  Process a user query and generate appropriate memory retrieval context.

  This function analyzes a user query to extract:
  - Intent classification
  - Key topics and entities
  - Required information types
  - Memory search parameters

  ## Parameters
  - query: The user's input query string
  - agent_id: UUID of the requesting agent
  - context: Optional context from previous interactions

  ## Returns
  - {:ok, %{query_embedding: [...], query_keywords: [...], intent: "...", ...}}
  - {:error, reason}
  """
  def process_query(query, agent_id, context \\ %{}) do
    # Extract embeddings for similarity search
    with {:ok, embedding} <- generate_embedding(query),
         {:ok, keywords} <- extract_keywords(query),
         {:ok, intent} <- classify_intent(query) do
      query_context = %{
        query_embedding: embedding,
        query_keywords: keywords,
        intent: intent,
        agent_id: agent_id,
        original_query: query,
        conversation_context: context
      }

      {:ok, query_context}
    else
      {:error, reason} -> {:error, "Failed to process query: #{reason}"}
    end
  end

  @doc """
  Perform multi-level memory retrieval based on processed query context.

  Implements the MemoryOS paper's hierarchical memory search:
  1. STM: Recent dialogue pages
  2. MTM: Relevant dialogue segments using Fscore
  3. LPM: Agent-specific knowledge and traits
  4. SystemMemory: Cross-agent shared knowledge

  ## Parameters
  - query_context: Result from process_query/3
  - retrieval_options: Configuration for memory search

  ## Returns
  - {:ok, %{stm_results: [...], mtm_results: [...], lpm_results: [...], system_results: [...]}}
  """
  def retrieve_memories(query_context, retrieval_options \\ %{}) do
    agent_id = query_context.agent_id

    # Configure retrieval limits
    limits =
      Map.merge(
        %{
          stm_limit: 5,
          mtm_limit: 10,
          lpm_limit: 8,
          system_limit: 3
        },
        retrieval_options[:limits] || %{}
      )

    # Parallel memory retrieval
    retrieval_tasks = [
      Task.async(fn -> retrieve_stm_memories(agent_id, query_context, limits.stm_limit) end),
      Task.async(fn -> retrieve_mtm_memories(agent_id, query_context, limits.mtm_limit) end),
      Task.async(fn -> retrieve_lpm_memories(agent_id, query_context, limits.lpm_limit) end),
      Task.async(fn -> retrieve_system_memories(query_context, limits.system_limit) end)
    ]

    # Wait for all retrieval tasks
    [stm_results, mtm_results, lpm_results, system_results] =
      Task.await_many(retrieval_tasks, 30_000)

    memory_results = %{
      stm_results: stm_results,
      mtm_results: mtm_results,
      lpm_results: lpm_results,
      system_results: system_results,
      query_context: query_context
    }

    {:ok, memory_results}
  end

  @doc """
  Synthesize retrieved memories into a coherent context for response generation.

  Combines results from all memory levels and creates a structured context
  that can be used for LLM response generation.

  ## Parameters
  - memory_results: Output from retrieve_memories/2
  - synthesis_options: Configuration for memory synthesis

  ## Returns
  - {:ok, synthesized_context}
  """
  def synthesize_memory_context(memory_results, _synthesis_options \\ %{}) do
    # Rank and filter memories by relevance
    ranked_memories = rank_memories_by_relevance(memory_results)

    # Create structured context
    context = %{
      recent_conversations: format_stm_context(memory_results.stm_results),
      relevant_topics: format_mtm_context(memory_results.mtm_results),
      agent_knowledge: format_lpm_context(memory_results.lpm_results),
      shared_knowledge: format_system_context(memory_results.system_results),
      query_intent: memory_results.query_context.intent,
      confidence_scores: calculate_confidence_scores(ranked_memories)
    }

    {:ok, context}
  end

  @doc """
  Extract structured information from dialogue content.

  Used by workers for meta chain generation and knowledge extraction.

  ## Parameters
  - content: Text content to analyze
  - extraction_type: :keywords, :topics, :sentiment, :entities, etc.

  ## Returns
  - {:ok, extracted_data}
  """
  def extract_information(content, extraction_type) do
    case extraction_type do
      :keywords -> extract_keywords(content)
      :topics -> extract_topics(content)
      :sentiment -> analyze_sentiment(content)
      :entities -> extract_entities(content)
      :summary -> generate_summary(content)
      _ -> {:error, "Unknown extraction type: #{extraction_type}"}
    end
  end

  @doc """
  Generate embeddings for text content using the configured embedding model.

  ## Parameters
  - text: Content to embed
  - model_options: Optional model configuration

  ## Returns
  - {:ok, embedding_vector}
  - {:error, reason}
  """
  def generate_embedding(text, model_options \\ %{}) do
    # Use real embedding generation with Smith.OpenAiEmbeddingModel
    if is_nil(text) or (is_binary(text) and String.length(text) == 0) do
      {:error, "Empty text provided"}
    else
      use_mock =
        model_options[:use_mock] || Application.get_env(:smith, :use_mock_embeddings, false)

      if use_mock do
        # Use mock embedding for testing/development
        mock_embedding = generate_mock_embedding(text)
        {:ok, mock_embedding}
      else
        # Use real OpenAI embedding model
        case Smith.OpenAiEmbeddingModel.generate([text], model_options) do
          {:ok, [embedding]} -> {:ok, embedding}
          {:ok, embeddings} when is_list(embeddings) -> {:ok, List.first(embeddings)}
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end

  # Private implementation functions

  defp retrieve_stm_memories(agent_id, _query_context, limit) do
    # Retrieve recent dialogue pages for the agent
    Smith.MemoryOS.STM.DialoguePage
    |> Ash.Query.filter(agent_id: agent_id)
    |> Ash.Query.sort(desc: :inserted_at)
    |> Ash.Query.limit(limit)
    |> Ash.read!()
  rescue
    _ -> []
  end

  defp retrieve_mtm_memories(agent_id, query_context, limit) do
    # Retrieve dialogue segments using Fscore similarity
    Smith.MemoryOS.MTM.DialogueSegment
    |> Ash.Query.filter(agent_id: agent_id)
    |> Ash.Query.load(fscore: query_context)
    |> Ash.Query.sort(desc: :heat_score)
    |> Ash.Query.limit(limit)
    |> Ash.read!()
  rescue
    _ -> []
  end

  defp retrieve_lpm_memories(agent_id, _query_context, limit) do
    # Retrieve knowledge base entries and traits for the agent
    kb_entries =
      Smith.MemoryOS.LPM.KnowledgeBaseEntry
      |> Ash.Query.filter(agent_id: agent_id)
      |> Ash.Query.limit(limit)
      |> Ash.read!()

    traits =
      Smith.MemoryOS.LPM.TraitEntry
      |> Ash.Query.filter(agent_id: agent_id)
      |> Ash.Query.limit(limit)
      |> Ash.read!()

    %{knowledge_entries: kb_entries, traits: traits}
  rescue
    _ -> %{knowledge_entries: [], traits: []}
  end

  defp retrieve_system_memories(_query_context, limit) do
    # Retrieve cross-agent shared knowledge
    Smith.MemoryOS.SystemMemory
    |> Ash.Query.sort(desc: :importance_score)
    |> Ash.Query.limit(limit)
    |> Ash.read!()
  rescue
    _ -> []
  end

  defp extract_keywords(text) do
    # Simple keyword extraction - in production would use NLP models
    keywords =
      text
      |> String.downcase()
      |> String.replace(~r/[^\w\s]/, "")
      |> String.split()
      |> Enum.filter(&(String.length(&1) > 3))
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_word, freq} -> -freq end)
      |> Enum.take(10)
      |> Enum.map(fn {word, _freq} -> word end)

    {:ok, keywords}
  end

  defp extract_topics(text) do
    # Simple topic classification
    text_lower = String.downcase(text)

    topics = []

    topics =
      if String.contains?(text_lower, ["help", "how", "what", "explain"]),
        do: ["information_seeking" | topics],
        else: topics

    topics =
      if String.contains?(text_lower, ["create", "make", "build", "implement"]),
        do: ["task_execution" | topics],
        else: topics

    topics =
      if String.contains?(text_lower, ["remember", "recall", "memory", "past"]),
        do: ["memory_query" | topics],
        else: topics

    topics =
      if String.contains?(text_lower, ["learn", "understand", "know"]),
        do: ["learning" | topics],
        else: topics

    topics = if Enum.empty?(topics), do: ["general"], else: topics
    {:ok, topics}
  end

  defp analyze_sentiment(text) do
    # Simple sentiment analysis
    text_lower = String.downcase(text)

    positive_indicators = ["good", "great", "excellent", "love", "like", "amazing", "wonderful"]
    negative_indicators = ["bad", "terrible", "hate", "dislike", "awful", "horrible"]

    positive_count = Enum.count(positive_indicators, &String.contains?(text_lower, &1))
    negative_count = Enum.count(negative_indicators, &String.contains?(text_lower, &1))

    sentiment =
      cond do
        positive_count > negative_count -> "positive"
        negative_count > positive_count -> "negative"
        true -> "neutral"
      end

    {:ok, sentiment}
  end

  defp extract_entities(text) do
    # Simple entity extraction - in production would use NER models
    # For now, just extract capitalized words as potential entities
    entities =
      text
      |> String.split()
      |> Enum.filter(&String.match?(&1, ~r/^[A-Z][a-z]+/))
      |> Enum.uniq()

    {:ok, entities}
  end

  defp generate_summary(text) do
    # Simple summarization - first sentence or truncated version
    sentences = String.split(text, ~r/[.!?]+/)

    summary =
      if length(sentences) > 0 do
        sentences |> List.first() |> String.trim()
      else
        String.slice(text, 0, 100) <> "..."
      end

    {:ok, summary}
  end

  defp classify_intent(query) do
    query_lower = String.downcase(query)

    intent =
      cond do
        String.contains?(query_lower, ["?", "how", "what", "why", "when", "where"]) ->
          "question"

        String.contains?(query_lower, ["create", "make", "build", "generate"]) ->
          "creation"

        String.contains?(query_lower, ["remember", "recall", "what did", "previously"]) ->
          "memory_recall"

        String.contains?(query_lower, ["help", "assist", "support"]) ->
          "assistance"

        true ->
          "general"
      end

    {:ok, intent}
  end

  defp generate_mock_embedding(text) do
    # Generate a deterministic mock embedding based on text hash
    hash = :erlang.phash2(text, 1000)

    # Create a 384-dimensional mock embedding (common dimension size)
    0..383
    |> Enum.map(fn i ->
      # Use text hash and index to generate pseudo-random but deterministic values
      :math.sin((hash + i) / 100.0) * 0.5
    end)
  end

  defp rank_memories_by_relevance(memory_results) do
    # Simple relevance ranking - in production would use sophisticated scoring
    all_memories = [
      {memory_results.stm_results, :stm, 1.0},
      {memory_results.mtm_results, :mtm, 0.8},
      {memory_results.lpm_results, :lpm, 0.6},
      {memory_results.system_results, :system, 0.4}
    ]

    all_memories
    |> Enum.flat_map(fn {memories, type, base_score} ->
      memories
      |> Enum.with_index()
      |> Enum.map(fn {memory, index} ->
        # Decay score by position
        score = base_score * (1.0 / (index + 1))
        {memory, type, score}
      end)
    end)
    |> Enum.sort_by(fn {_memory, _type, score} -> -score end)
  end

  defp format_stm_context(stm_results) do
    Enum.map(stm_results, fn page ->
      %{
        query: page.query,
        response: page.response,
        timestamp: page.inserted_at,
        type: :recent_conversation
      }
    end)
  end

  defp format_mtm_context(mtm_results) do
    Enum.map(mtm_results, fn segment ->
      %{
        topic: segment.topic_summary,
        keywords: segment.keywords,
        heat_score: segment.heat_score,
        type: :topic_segment
      }
    end)
  end

  defp format_lpm_context(lpm_results) do
    %{
      knowledge:
        Enum.map(lpm_results.knowledge_entries || [], fn entry ->
          %{
            content: entry.content,
            topic: entry.topic_summary,
            keywords: entry.keywords,
            type: :agent_knowledge
          }
        end),
      traits:
        Enum.map(lpm_results.traits || [], fn trait ->
          %{
            trait_name: trait.trait_name,
            trait_value: trait.trait_value,
            confidence: trait.confidence,
            type: :personality_trait
          }
        end)
    }
  end

  defp format_system_context(system_results) do
    Enum.map(system_results, fn entry ->
      %{
        content: entry.content,
        importance: entry.importance_score,
        source_agent: entry.source_agent_id,
        type: :shared_knowledge
      }
    end)
  end

  defp calculate_confidence_scores(ranked_memories) do
    total_memories = length(ranked_memories)

    if total_memories > 0 do
      avg_score =
        ranked_memories
        |> Enum.map(fn {_memory, _type, score} -> score end)
        |> Enum.sum()
        |> Kernel./(total_memories)

      %{
        average_relevance: avg_score,
        memory_count: total_memories,
        confidence_level:
          case avg_score do
            score when score > 0.7 -> "high"
            score when score > 0.4 -> "medium"
            _ -> "low"
          end
      }
    else
      %{average_relevance: 0.0, memory_count: 0, confidence_level: "none"}
    end
  end
end
