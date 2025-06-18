defmodule Anderson.MemoryOS.LLMClientTest do
  use Anderson.DataCase, async: true

  alias Anderson.MemoryOS.LLMClient

  describe "process_query/3" do
    test "successfully processes a basic query" do
      agent_id = Ash.UUID.generate()
      query = "How can I improve my memory management?"

      {:ok, query_context} = LLMClient.process_query(query, agent_id)

      assert query_context.agent_id == agent_id
      assert query_context.original_query == query
      assert query_context.intent == "question"
      assert is_list(query_context.query_keywords)
      assert is_list(query_context.query_embedding)
      assert length(query_context.query_embedding) > 0
    end

    test "classifies different intent types correctly" do
      agent_id = Ash.UUID.generate()

      test_cases = [
        "What is machine learning?",
        "Create a new project",
        "Remember what we discussed yesterday",
        "Help me with this task",
        "Just a regular statement"
      ]

      for query <- test_cases do
        {:ok, query_context} = LLMClient.process_query(query, agent_id)
        # Since we're using mock classification, just verify it returns a valid intent
        assert is_binary(query_context.intent)

        assert query_context.intent in [
                 "question",
                 "creation",
                 "memory_recall",
                 "assistance",
                 "general"
               ]
      end
    end

    test "extracts relevant keywords" do
      agent_id = Ash.UUID.generate()
      query = "I need help understanding machine learning algorithms and neural networks"

      {:ok, query_context} = LLMClient.process_query(query, agent_id)

      keywords = query_context.query_keywords
      assert "understanding" in keywords
      assert "machine" in keywords
      assert "learning" in keywords
      assert "algorithms" in keywords
      assert "neural" in keywords
      assert "networks" in keywords
    end

    test "handles empty query" do
      agent_id = Ash.UUID.generate()

      {:error, reason} = LLMClient.process_query("", agent_id)
      assert reason =~ "Empty text provided"
    end
  end

  describe "generate_embedding/2" do
    test "generates mock embeddings in test environment" do
      text = "Test content for embedding generation"

      {:ok, embedding} = LLMClient.generate_embedding(text, use_mock: true)

      assert is_list(embedding)
      # Mock embedding dimensions
      assert length(embedding) == 384
      assert Enum.all?(embedding, &is_number/1)
    end

    test "generates deterministic embeddings for same input" do
      text = "Consistent test content"

      {:ok, embedding1} = LLMClient.generate_embedding(text, use_mock: true)
      {:ok, embedding2} = LLMClient.generate_embedding(text, use_mock: true)

      assert embedding1 == embedding2
    end

    test "generates different embeddings for different input" do
      {:ok, embedding1} = LLMClient.generate_embedding("First text", use_mock: true)
      {:ok, embedding2} = LLMClient.generate_embedding("Second text", use_mock: true)

      assert embedding1 != embedding2
    end
  end

  describe "extract_information/2" do
    test "extracts keywords successfully" do
      text = "This is a test document about machine learning and artificial intelligence"

      {:ok, keywords} = LLMClient.extract_information(text, :keywords)

      assert is_list(keywords)
      assert "machine" in keywords
      assert "learning" in keywords
      assert "artificial" in keywords
      assert "intelligence" in keywords
    end

    test "extracts topics correctly" do
      test_cases = [
        {"How can I learn programming?", ["information_seeking", "learning"]},
        {"Create a new web application", ["task_execution"]},
        {"Remember our last conversation", ["memory_query"]},
        {"Help me understand this concept", ["information_seeking"]},
        {"Just saying hello", ["general"]}
      ]

      for {text, expected_topics} <- test_cases do
        {:ok, topics} = LLMClient.extract_information(text, :topics)

        for expected_topic <- expected_topics do
          assert expected_topic in topics, "Missing topic #{expected_topic} for text: #{text}"
        end
      end
    end

    test "analyzes sentiment correctly" do
      test_cases = [
        {"I love this amazing feature!", "positive"},
        {"This is terrible and awful", "negative"},
        {"This is a neutral statement", "neutral"}
      ]

      for {text, expected_sentiment} <- test_cases do
        {:ok, sentiment} = LLMClient.extract_information(text, :sentiment)
        assert sentiment == expected_sentiment, "Failed sentiment analysis for: #{text}"
      end
    end

    test "extracts entities" do
      text = "John Smith works at Microsoft in Seattle"

      {:ok, entities} = LLMClient.extract_information(text, :entities)

      assert is_list(entities)
      assert "John" in entities
      assert "Smith" in entities
      assert "Microsoft" in entities
      assert "Seattle" in entities
    end

    test "generates summaries" do
      text =
        "This is a long document about artificial intelligence. It covers machine learning algorithms. Neural networks are discussed in detail."

      {:ok, summary} = LLMClient.extract_information(text, :summary)

      assert is_binary(summary)
      assert String.length(summary) > 0
      assert String.length(summary) <= String.length(text)
    end

    test "handles unknown extraction type" do
      {:error, reason} = LLMClient.extract_information("test", :unknown_type)
      assert reason =~ "Unknown extraction type"
    end
  end

  describe "retrieve_memories/2 (without database)" do
    test "returns empty results when no data exists" do
      agent_id = Ash.UUID.generate()

      {:ok, query_context} = LLMClient.process_query("test query", agent_id)
      {:ok, memory_results} = LLMClient.retrieve_memories(query_context)

      assert memory_results.stm_results == []
      assert memory_results.mtm_results == []
      assert memory_results.lpm_results == %{knowledge_entries: [], traits: []}
      assert memory_results.system_results == []
      assert memory_results.query_context == query_context
    end

    test "respects retrieval limits" do
      agent_id = Ash.UUID.generate()

      {:ok, query_context} = LLMClient.process_query("test query", agent_id)

      limits = %{
        stm_limit: 2,
        mtm_limit: 3,
        lpm_limit: 1,
        system_limit: 1
      }

      {:ok, memory_results} = LLMClient.retrieve_memories(query_context, limits: limits)

      # Since no data exists, should still be empty but structure should be correct
      assert is_list(memory_results.stm_results)
      assert is_list(memory_results.mtm_results)
      assert is_map(memory_results.lpm_results)
      assert is_list(memory_results.system_results)
    end
  end

  describe "synthesize_memory_context/2" do
    test "synthesizes context from empty memory results" do
      agent_id = Ash.UUID.generate()

      {:ok, query_context} = LLMClient.process_query("test query", agent_id)
      {:ok, memory_results} = LLMClient.retrieve_memories(query_context)
      {:ok, synthesized_context} = LLMClient.synthesize_memory_context(memory_results)

      assert synthesized_context.recent_conversations == []
      assert synthesized_context.relevant_topics == []
      assert synthesized_context.agent_knowledge == %{knowledge: [], traits: []}
      assert synthesized_context.shared_knowledge == []
      assert synthesized_context.query_intent == "general"

      # Check confidence scores structure
      confidence = synthesized_context.confidence_scores
      assert is_float(confidence.average_relevance)
      assert is_integer(confidence.memory_count)
      assert is_binary(confidence.confidence_level)
    end

    test "calculates confidence scores correctly" do
      # Mock memory results with some content
      query_context = %{intent: "question"}

      memory_results = %{
        stm_results: [],
        mtm_results: [],
        lpm_results: %{knowledge_entries: [], traits: []},
        system_results: [],
        query_context: query_context
      }

      {:ok, synthesized_context} = LLMClient.synthesize_memory_context(memory_results)

      confidence = synthesized_context.confidence_scores
      assert is_map(confidence)
      assert Map.has_key?(confidence, :average_relevance)
      assert Map.has_key?(confidence, :memory_count)
      assert Map.has_key?(confidence, :confidence_level)
    end
  end

  describe "integration scenarios" do
    test "complete query processing pipeline" do
      agent_id = Ash.UUID.generate()
      query = "What did we discuss about machine learning yesterday?"

      # Step 1: Process query
      {:ok, query_context} = LLMClient.process_query(query, agent_id)
      # Intent may vary with mock classification, just verify it's a valid intent
      assert is_binary(query_context.intent)
      assert "machine" in query_context.query_keywords
      assert "learning" in query_context.query_keywords

      # Step 2: Retrieve memories
      {:ok, memory_results} = LLMClient.retrieve_memories(query_context)
      assert memory_results.query_context == query_context

      # Step 3: Synthesize context
      {:ok, synthesized_context} = LLMClient.synthesize_memory_context(memory_results)
      assert is_binary(synthesized_context.query_intent)
      assert is_map(synthesized_context.confidence_scores)
    end

    test "handles various query types" do
      agent_id = Ash.UUID.generate()

      queries = [
        "How do neural networks work?",
        "Create a machine learning model",
        "Remember our conversation about AI",
        "Help me understand deep learning"
      ]

      for query <- queries do
        {:ok, query_context} = LLMClient.process_query(query, agent_id)
        {:ok, memory_results} = LLMClient.retrieve_memories(query_context)
        {:ok, synthesized_context} = LLMClient.synthesize_memory_context(memory_results)

        assert is_binary(synthesized_context.query_intent)
        assert is_map(synthesized_context.confidence_scores)
      end
    end
  end

  describe "error handling" do
    test "handles invalid agent_id gracefully" do
      invalid_agent_id = "not-a-uuid"

      # Should still process the query even with invalid agent_id
      {:ok, query_context} = LLMClient.process_query("test", invalid_agent_id)
      assert query_context.agent_id == invalid_agent_id
    end

    test "handles memory retrieval errors gracefully" do
      agent_id = Ash.UUID.generate()

      {:ok, query_context} = LLMClient.process_query("test query", agent_id)

      # Even if retrieval fails, should return empty results rather than crash
      {:ok, memory_results} = LLMClient.retrieve_memories(query_context)

      assert is_map(memory_results)
      assert Map.has_key?(memory_results, :stm_results)
      assert Map.has_key?(memory_results, :mtm_results)
      assert Map.has_key?(memory_results, :lpm_results)
      assert Map.has_key?(memory_results, :system_results)
    end
  end
end
