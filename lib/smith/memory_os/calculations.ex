defmodule Smith.MemoryOS.Calculations do
  @moduledoc """
  Utility module for MemoryOS calculations.

  Contains implementations for similarity metrics and other utility calculations
  used across the MemoryOS resources.

  Implements algorithms from the MemoryOS paper:
  - Fscore = cos(e_s, e_p) + FJacard(K_s, K_p)
  - Heat = α · N_visit + β · L_interaction + γ · R_recency
  """

  @doc """
  Calculate Jaccard similarity between two sets of keywords.

  Jaccard similarity is defined as the size of the intersection divided by the size of the union.

  ## Parameters
  - segment_keywords: List of keywords from segment
  - query_keywords: List of keywords from query/page

  ## Returns
  - Float: Jaccard similarity score between 0.0 and 1.0
  """
  def jaccard_similarity(segment_keywords, query_keywords)
      when is_list(segment_keywords) and is_list(query_keywords) do
    segment_set = MapSet.new(segment_keywords)
    query_set = MapSet.new(query_keywords)

    intersection = MapSet.intersection(segment_set, query_set)
    union = MapSet.union(segment_set, query_set)

    intersection_size = MapSet.size(intersection)
    union_size = MapSet.size(union)

    if union_size == 0 do
      0.0
    else
      intersection_size / union_size
    end
  end

  # Legacy version for backward compatibility
  def jaccard_similarity(segment, context) do
    segment_keywords = segment.keywords || []
    query_keywords = context[:query_keywords] || []
    jaccard_similarity(segment_keywords, query_keywords)
  end

  @doc """
  Calculate cosine similarity between two embedding vectors.

  Cosine similarity is the dot product of normalized vectors.

  ## Parameters
  - embedding1: First embedding vector (list of floats)
  - embedding2: Second embedding vector (list of floats)

  ## Returns
  - Float: Cosine similarity score between -1.0 and 1.0
  """
  def cosine_similarity(embedding1, embedding2)
      when is_list(embedding1) and is_list(embedding2) do
    if length(embedding1) != length(embedding2) or length(embedding1) == 0 do
      0.0
    else
      # Calculate dot product
      dot_product =
        Enum.zip(embedding1, embedding2)
        |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)

      # Calculate magnitudes
      magnitude1 = :math.sqrt(Enum.reduce(embedding1, 0.0, fn x, acc -> acc + x * x end))
      magnitude2 = :math.sqrt(Enum.reduce(embedding2, 0.0, fn x, acc -> acc + x * x end))

      if magnitude1 == 0.0 or magnitude2 == 0.0 do
        0.0
      else
        dot_product / (magnitude1 * magnitude2)
      end
    end
  end

  @doc """
  Calculate Fscore based on MemoryOS paper.

  Fscore = cos(e_s, e_p) + FJacard(K_s, K_p)

  ## Parameters
  - segment_embedding: Segment's embedding vector
  - query_embedding: Query/page embedding vector
  - segment_keywords: Segment's keywords list
  - query_keywords: Query/page keywords list

  ## Returns
  - Float: Combined Fscore (typically 0.0 to 2.0)
  """
  def calculate_fscore(segment_embedding, query_embedding, segment_keywords, query_keywords) do
    cosine_sim = cosine_similarity(segment_embedding, query_embedding)
    jaccard_sim = jaccard_similarity(segment_keywords, query_keywords)

    cosine_sim + jaccard_sim
  end

  @doc """
  Calculate recency factor based on exponential decay.

  R_recency = exp(-Δt / μ)

  ## Parameters
  - last_accessed: DateTime when segment was last accessed
  - time_constant: μ parameter (default: 1.0e7 seconds as per paper)

  ## Returns
  - Float: Recency factor between 0.0 and 1.0
  """
  def calculate_recency_factor(last_accessed, time_constant \\ 1.0e7) do
    delta_t = DateTime.diff(DateTime.utc_now(), last_accessed, :second)
    :math.exp(-delta_t / time_constant)
  end

  @doc """
  Calculate heat score based on MemoryOS paper.

  Heat = α · N_visit + β · L_interaction + γ · R_recency

  ## Parameters
  - visit_count: Number of times segment has been retrieved
  - interaction_count: Number of dialogue pages in segment
  - recency_factor: Time decay coefficient
  - alpha: Weight for visit count (default: 1.0)
  - beta: Weight for interaction count (default: 1.0)
  - gamma: Weight for recency (default: 1.0)

  ## Returns
  - Float: Heat score
  """
  def calculate_heat_score(
        visit_count,
        interaction_count,
        recency_factor,
        alpha \\ 1.0,
        beta \\ 1.0,
        gamma \\ 1.0
      ) do
    alpha * visit_count + beta * interaction_count + gamma * recency_factor
  end

  @doc """
  Placeholder calculation that returns 0.0.

  Used as a temporary implementation for calculations that will be properly implemented later.
  """
  def placeholder_calculation(_resource, _context) do
    0.0
  end

  @doc """
  Context-aware cosine similarity calculation for DialogueSegment.

  Extracts embeddings from segment and context, then calculates cosine similarity.

  ## Parameters
  - segment: DialogueSegment resource with embedding attribute
  - context: Map containing query_embedding

  ## Returns
  - Float: Cosine similarity score
  """
  def segment_cosine_similarity(segment, context) do
    segment_embedding = segment.embedding || []
    query_embedding = context[:query_embedding] || []

    cosine_similarity(segment_embedding, query_embedding)
  end

  @doc """
  Context-aware Jaccard similarity calculation for DialogueSegment.

  Extracts keywords from segment and context, then calculates Jaccard similarity.

  ## Parameters
  - segment: DialogueSegment resource with keywords attribute
  - context: Map containing query_keywords

  ## Returns
  - Float: Jaccard similarity score
  """
  def segment_jaccard_similarity(segment, context) do
    segment_keywords = segment.keywords || []
    query_keywords = context[:query_keywords] || []

    jaccard_similarity(segment_keywords, query_keywords)
  end

  @doc """
  Context-aware Fscore calculation for DialogueSegment.

  Implements the MemoryOS paper formula: Fscore = cos(e_s, e_p) + FJacard(K_s, K_p)

  ## Parameters
  - segment: DialogueSegment resource
  - context: Map containing query_embedding and query_keywords

  ## Returns
  - Float: Combined Fscore
  """
  def segment_fscore(segment, context) do
    cosine_sim = segment_cosine_similarity(segment, context)
    jaccard_sim = segment_jaccard_similarity(segment, context)

    cosine_sim + jaccard_sim
  end

  @doc """
  Context-aware heat score calculation for DialogueSegment.

  Implements the MemoryOS paper formula: Heat = α·N_visit + β·L_interaction + γ·R_recency

  ## Parameters
  - segment: DialogueSegment resource
  - context: Map with optional alpha, beta, gamma coefficients

  ## Returns
  - Float: Heat score
  """
  def segment_heat_score(segment, context \\ %{}) do
    alpha = context[:alpha] || 1.0
    beta = context[:beta] || 1.0
    gamma = context[:gamma] || 1.0

    visit_count = segment.visit_count || 0
    # Calculate page count from loaded relationship
    page_count =
      if segment.dialogue_pages do
        length(segment.dialogue_pages)
      else
        0
      end

    recency_factor = calculate_recency_factor(segment.last_accessed)

    calculate_heat_score(visit_count, page_count, recency_factor, alpha, beta, gamma)
  end
end
