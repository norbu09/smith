defmodule Anderson.MemoryOS.Workers.UpdateMetaChainWorker do
  @moduledoc """
  Meta Chain Generation Worker

  Generates LLM-based meta information for dialogue pages including:

  1. Topic classification and tagging
  2. Keyword extraction
  3. Sentiment analysis
  4. Context summarization
  5. Relationship mapping to existing knowledge

  This worker enhances raw dialogue data with structured metadata
  to improve similarity calculations and memory organization.
  """

  use Oban.Worker, queue: :memory, max_attempts: 3

  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"record_pk" => page_id}}) do
    case Anderson.MemoryOS.STM.DialoguePage.by_id(page_id) do
      {:ok, page} ->
        generate_meta_chain(page)

      {:error, error} ->
        {:error, "Failed to load dialogue page: #{inspect(error)}"}
    end
  end

  defp generate_meta_chain(page) do
    # In a full implementation, this would use LLM services
    # For now, we'll implement basic text analysis

    # Extract topics and keywords
    topics = extract_topics(page)
    keywords = extract_keywords(page)
    sentiment = analyze_sentiment(page)
    summary = generate_summary(page)

    # Update the page with meta information
    changeset =
      page
      |> Ash.Changeset.for_update(:update)
      |> Ash.Changeset.change_attribute(:meta_chain, %{
        topics: topics,
        keywords: keywords,
        sentiment: sentiment,
        summary: summary,
        generated_at: DateTime.utc_now()
      })

    case Ash.update(changeset) do
      {:ok, updated_page} ->
        {:ok, "Generated meta chain for page #{updated_page.id}"}

      {:error, error} ->
        {:error, "Failed to update page with meta chain: #{inspect(error)}"}
    end
  end

  defp extract_topics(page) do
    # Simple topic extraction based on content analysis
    text = "#{page.query} #{page.response}"

    # Basic topic classification based on keywords
    topics = []

    topics =
      if String.contains?(String.downcase(text), ["memory", "remember", "recall"]) do
        ["memory_management" | topics]
      else
        topics
      end

    topics =
      if String.contains?(String.downcase(text), ["help", "how", "what", "why"]) do
        ["information_seeking" | topics]
      else
        topics
      end

    topics =
      if String.contains?(String.downcase(text), ["task", "do", "complete", "finish"]) do
        ["task_oriented" | topics]
      else
        topics
      end

    topics =
      if String.contains?(String.downcase(text), ["conversation", "chat", "talk"]) do
        ["conversational" | topics]
      else
        topics
      end

    if Enum.empty?(topics), do: ["general"], else: topics
  end

  defp extract_keywords(page) do
    # Enhanced keyword extraction
    text = "#{page.query} #{page.response}"

    # Split into words and filter
    words =
      text
      |> String.downcase()
      |> String.replace(~r/[^\w\s]/, "")
      |> String.split()
      |> Enum.filter(&(String.length(&1) > 3))
      |> Enum.reject(&(&1 in common_stopwords()))

    # Get word frequencies
    word_frequencies = Enum.frequencies(words)

    # Return top keywords by frequency
    word_frequencies
    |> Enum.sort_by(fn {_word, freq} -> -freq end)
    |> Enum.take(10)
    |> Enum.map(fn {word, _freq} -> word end)
  end

  defp analyze_sentiment(page) do
    # Basic sentiment analysis
    text = "#{page.query} #{page.response}"
    text_lower = String.downcase(text)

    positive_words = [
      "good",
      "great",
      "excellent",
      "amazing",
      "wonderful",
      "perfect",
      "love",
      "like",
      "enjoy",
      "happy",
      "pleased"
    ]

    negative_words = [
      "bad",
      "terrible",
      "awful",
      "horrible",
      "hate",
      "dislike",
      "angry",
      "frustrated",
      "disappointed",
      "sad"
    ]

    positive_count = Enum.count(positive_words, &String.contains?(text_lower, &1))
    negative_count = Enum.count(negative_words, &String.contains?(text_lower, &1))

    cond do
      positive_count > negative_count -> "positive"
      negative_count > positive_count -> "negative"
      true -> "neutral"
    end
  end

  defp generate_summary(page) do
    # Generate a concise summary of the interaction
    query_length = String.length(page.query)
    response_length = String.length(page.response)

    # Extract key phrases (simplified)
    query_words = page.query |> String.split() |> length()
    response_words = page.response |> String.split() |> length()

    interaction_type =
      cond do
        String.contains?(String.downcase(page.query), ["?", "how", "what", "why", "when", "where"]) ->
          "question"

        String.contains?(String.downcase(page.query), ["please", "can you", "could you"]) ->
          "request"

        response_words > query_words * 2 ->
          "detailed_response"

        true ->
          "general_interaction"
      end

    %{
      interaction_type: interaction_type,
      query_length: query_length,
      response_length: response_length,
      query_words: query_words,
      response_words: response_words,
      complexity: calculate_complexity(page)
    }
  end

  defp calculate_complexity(page) do
    # Simple complexity score based on various factors
    query_complexity = String.length(page.query) / 100.0
    response_complexity = String.length(page.response) / 100.0

    # Check for technical terms or complex concepts
    text = "#{page.query} #{page.response}"

    technical_terms = [
      "algorithm",
      "database",
      "system",
      "process",
      "implementation",
      "configuration"
    ]

    technical_score =
      Enum.count(technical_terms, &String.contains?(String.downcase(text), &1)) * 0.2

    total_complexity = query_complexity + response_complexity + technical_score

    cond do
      total_complexity < 1.0 -> "low"
      total_complexity < 3.0 -> "medium"
      true -> "high"
    end
  end

  defp common_stopwords do
    [
      "the",
      "and",
      "or",
      "but",
      "in",
      "on",
      "at",
      "to",
      "for",
      "of",
      "with",
      "by",
      "this",
      "that",
      "these",
      "those",
      "is",
      "are",
      "was",
      "were",
      "be",
      "been",
      "have",
      "has",
      "had",
      "will",
      "would",
      "could",
      "should",
      "may",
      "might",
      "can",
      "do",
      "does",
      "did",
      "get",
      "got",
      "go",
      "went",
      "come",
      "came",
      "make",
      "made",
      "take",
      "took",
      "see",
      "saw",
      "know",
      "knew",
      "think",
      "thought",
      "say",
      "said",
      "tell",
      "told",
      "ask",
      "asked",
      "give",
      "gave",
      "find",
      "found",
      "use",
      "used",
      "work",
      "worked",
      "try",
      "tried",
      "help",
      "helped",
      "start",
      "started",
      "stop",
      "stopped",
      "run",
      "ran",
      "play",
      "played",
      "turn",
      "turned",
      "show",
      "showed",
      "move",
      "moved",
      "live",
      "lived",
      "feel",
      "felt",
      "put",
      "keep",
      "kept",
      "let",
      "mean",
      "meant"
    ]
  end
end
