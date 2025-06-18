defmodule Smith.MemoryOS.CalculationsTest do
  use ExUnit.Case, async: true

  alias Smith.MemoryOS.Calculations

  doctest Calculations

  describe "cosine_similarity/2" do
    test "returns 1.0 for identical vectors" do
      vector = [1.0, 2.0, 3.0]
      assert Calculations.cosine_similarity(vector, vector) == 1.0
    end

    test "returns 0.0 for orthogonal vectors" do
      vector_a = [1.0, 0.0]
      vector_b = [0.0, 1.0]
      assert Calculations.cosine_similarity(vector_a, vector_b) == 0.0
    end

    test "returns -1.0 for opposite vectors" do
      vector_a = [1.0, 0.0]
      vector_b = [-1.0, 0.0]
      assert Calculations.cosine_similarity(vector_a, vector_b) == -1.0
    end

    test "handles normalized vectors correctly" do
      # Two unit vectors at 60 degree angle should have cosine similarity of 0.5
      vector_a = [1.0, 0.0]
      vector_b = [0.5, :math.sqrt(3) / 2]
      result = Calculations.cosine_similarity(vector_a, vector_b)
      assert abs(result - 0.5) < 0.0001
    end

    test "returns 0.0 for zero vectors" do
      assert Calculations.cosine_similarity([0.0, 0.0], [1.0, 1.0]) == 0.0
      assert Calculations.cosine_similarity([1.0, 1.0], [0.0, 0.0]) == 0.0
      assert Calculations.cosine_similarity([0.0, 0.0], [0.0, 0.0]) == 0.0
    end

    test "handles different vector lengths" do
      vector_a = [1.0, 2.0]
      vector_b = [2.0, 4.0]
      # These vectors are parallel, should have similarity of 1.0
      result = Calculations.cosine_similarity(vector_a, vector_b)
      assert abs(result - 1.0) < 0.0001
    end
  end

  describe "jaccard_similarity/2" do
    test "returns 1.0 for identical sets" do
      set_a = ["word1", "word2", "word3"]
      set_b = ["word1", "word2", "word3"]
      assert Calculations.jaccard_similarity(set_a, set_b) == 1.0
    end

    test "returns 0.0 for disjoint sets" do
      set_a = ["word1", "word2"]
      set_b = ["word3", "word4"]
      assert Calculations.jaccard_similarity(set_a, set_b) == 0.0
    end

    test "calculates correct similarity for overlapping sets" do
      set_a = ["word1", "word2", "word3"]
      set_b = ["word2", "word3", "word4"]
      # Intersection: ["word2", "word3"] = 2 elements
      # Union: ["word1", "word2", "word3", "word4"] = 4 elements
      # Jaccard: 2/4 = 0.5
      assert Calculations.jaccard_similarity(set_a, set_b) == 0.5
    end

    test "handles empty sets" do
      assert Calculations.jaccard_similarity([], []) == 0.0
      assert Calculations.jaccard_similarity([], ["word1"]) == 0.0
      assert Calculations.jaccard_similarity(["word1"], []) == 0.0
    end

    test "handles duplicate elements" do
      set_a = ["word1", "word1", "word2"]
      set_b = ["word2", "word2", "word3"]
      # Should treat as ["word1", "word2"] and ["word2", "word3"]
      # Intersection: ["word2"] = 1 element
      # Union: ["word1", "word2", "word3"] = 3 elements
      # Jaccard: 1/3 ≈ 0.333
      result = Calculations.jaccard_similarity(set_a, set_b)
      assert abs(result - 0.3333333333333333) < 0.0001
    end
  end

  describe "calculate_fscore/4" do
    test "calculates correct Fscore using paper formula" do
      # Fscore = cos(e_s, e_p) + FJacard(K_s, K_p)
      page_embedding = [1.0, 0.0]
      # 60 degree angle, cos = 0.5
      segment_embedding = [0.5, :math.sqrt(3) / 2]
      page_keywords = ["memory", "agent"]
      # Jaccard = 1/3 ≈ 0.333
      segment_keywords = ["memory", "system"]

      expected_fscore = 0.5 + 0.3333333333333333

      result =
        Calculations.calculate_fscore(
          page_embedding,
          segment_embedding,
          page_keywords,
          segment_keywords
        )

      assert abs(result - expected_fscore) < 0.0001
    end

    test "handles identical embeddings and keywords" do
      embedding = [1.0, 2.0, 3.0]
      keywords = ["word1", "word2", "word3"]

      # cos(identical) + jaccard(identical) = 1.0 + 1.0 = 2.0
      result = Calculations.calculate_fscore(embedding, embedding, keywords, keywords)
      assert result == 2.0
    end

    test "handles completely different content" do
      page_embedding = [1.0, 0.0]
      # Opposite vectors, cos = -1.0
      segment_embedding = [-1.0, 0.0]
      page_keywords = ["word1", "word2"]
      # Disjoint sets, jaccard = 0.0
      segment_keywords = ["word3", "word4"]

      # cos(-1.0) + jaccard(0.0) = -1.0 + 0.0 = -1.0
      result =
        Calculations.calculate_fscore(
          page_embedding,
          segment_embedding,
          page_keywords,
          segment_keywords
        )

      assert result == -1.0
    end
  end

  describe "calculate_recency_factor/2" do
    test "returns 1.0 for zero time difference" do
      now = DateTime.utc_now()
      result = Calculations.calculate_recency_factor(now)
      assert result == 1.0
    end

    test "decreases exponentially with time" do
      one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

      result = Calculations.calculate_recency_factor(one_hour_ago)

      # Should be exp(-3600 / 1e7) = exp(-0.00036) ≈ 0.9996
      expected = :math.exp(-3600 / 1.0e7)
      assert abs(result - expected) < 0.0001
    end

    test "approaches 0 for very old timestamps" do
      # Much older than μ
      very_old = DateTime.add(DateTime.utc_now(), -100_000_000, :second)

      result = Calculations.calculate_recency_factor(very_old)

      # Should be very close to 0
      assert result < 0.0001
    end

    test "handles custom time constant" do
      one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)
      # Different μ value
      time_constant = 5.0e6

      result = Calculations.calculate_recency_factor(one_hour_ago, time_constant)
      expected = :math.exp(-3600 / time_constant)
      assert abs(result - expected) < 0.0001
    end
  end

  describe "calculate_heat_score/6" do
    test "calculates heat using paper formula" do
      # Heat = α·N_visit + β·L_interaction + γ·R_recency
      # With α = β = γ = 1.0 (from paper)

      visit_count = 5
      interaction_count = 100
      recency_factor = 0.95

      expected_heat = 1.0 * visit_count + 1.0 * interaction_count + 1.0 * recency_factor

      result =
        Calculations.calculate_heat_score(
          visit_count,
          interaction_count,
          recency_factor,
          1.0,
          1.0,
          1.0
        )

      assert abs(result - expected_heat) < 0.0001
    end

    test "uses correct coefficients" do
      visit_count = 10
      interaction_count = 50
      recency_factor = 0.9

      alpha = 2.0
      beta = 0.5
      gamma = 3.0

      expected_heat = alpha * visit_count + beta * interaction_count + gamma * recency_factor

      result =
        Calculations.calculate_heat_score(
          visit_count,
          interaction_count,
          recency_factor,
          alpha,
          beta,
          gamma
        )

      assert abs(result - expected_heat) < 0.0001
    end

    test "handles zero values correctly" do
      result = Calculations.calculate_heat_score(0, 0, 1.0, 1.0, 1.0, 1.0)

      # Should be 0 + 0 + 1.0 (recency factor) = 1.0
      assert result == 1.0
    end
  end

  describe "segment_fscore/2" do
    test "calculates Fscore for dialogue segment context" do
      # Mock segment data
      segment = %{
        # Orthogonal to context vector
        embedding: [0.0, 1.0],
        keywords: ["memory", "system"]
      }

      context = %{
        query_embedding: [1.0, 0.0],
        # Jaccard = 1/3
        query_keywords: ["memory", "agent"]
      }

      result = Calculations.segment_fscore(segment, context)
      # cos + jaccard
      expected = 0.0 + 0.3333333333333333

      assert abs(result - expected) < 0.0001
    end

    test "handles missing context gracefully" do
      segment = %{embedding: [1.0, 1.0], keywords: ["test"]}
      empty_context = %{}

      # Should handle missing fields without crashing
      result = Calculations.segment_fscore(segment, empty_context)
      assert is_float(result)
    end
  end

  describe "segment_heat_score/2" do
    test "calculates heat score for dialogue segment" do
      # Mock segment with last_accessed
      # 2 hours ago
      last_accessed = DateTime.add(DateTime.utc_now(), -7200, :second)

      segment = %{
        visit_count: 3,
        # 5 pages for interaction length
        dialogue_pages: [1, 2, 3, 4, 5],
        last_accessed: last_accessed
      }

      result = Calculations.segment_heat_score(segment)

      # Should use default coefficients α = β = γ = 1.0
      # Heat = visit_count + page_count + recency_factor
      assert is_float(result)
      assert result > 0
    end

    test "uses custom coefficients" do
      last_accessed = DateTime.add(DateTime.utc_now(), -3600, :second)

      segment = %{
        visit_count: 2,
        dialogue_pages: [1, 2],
        last_accessed: last_accessed
      }

      context = %{alpha: 2.0, beta: 0.5, gamma: 3.0}

      result = Calculations.segment_heat_score(segment, context)

      # Should calculate with custom coefficients
      assert is_float(result)
      assert result > 0
    end
  end

  describe "edge cases and error handling" do
    test "handles very large numbers" do
      large_vector = Enum.map(1..1000, fn i -> Float.round(i * 1.5, 2) end)
      result = Calculations.cosine_similarity(large_vector, large_vector)
      assert abs(result - 1.0) < 0.0001
    end

    test "handles very small numbers" do
      small_vector = [1.0e-10, 2.0e-10, 3.0e-10]
      result = Calculations.cosine_similarity(small_vector, small_vector)
      assert result == 1.0
    end

    test "handles mixed positive and negative values" do
      vector_a = [1.0, -2.0, 3.0, -4.0]
      vector_b = [-1.0, 2.0, -3.0, 4.0]

      result = Calculations.cosine_similarity(vector_a, vector_b)
      # Opposite vectors
      assert result == -1.0
    end

    test "jaccard similarity handles various data types as strings" do
      set_a = [1, 2, 3]
      set_b = [2, 3, 4]

      # Should convert to strings and calculate
      result = Calculations.jaccard_similarity(set_a, set_b)
      # 2 common elements out of 4 total
      assert result == 0.5
    end
  end
end
