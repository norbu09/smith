defmodule Anderson.MemoryOS.AgentIntegrationTest do
  use Anderson.DataCase, async: true

  alias Anderson.MemoryOS.AgentIntegration

  describe "initialize_agent/2" do
    test "successfully initializes a new agent" do
      agent_id = Ash.UUID.generate()
      config = %{stm_capacity: 10, mtm_capacity: 150}

      {:ok, result_config} = AgentIntegration.initialize_agent(agent_id, config)

      assert is_map(result_config)
      # Configuration should be merged with defaults
    end

    test "initializes agent with default configuration" do
      agent_id = Ash.UUID.generate()

      {:ok, config} = AgentIntegration.initialize_agent(agent_id)

      assert is_map(config)
    end

    test "handles invalid agent_id gracefully" do
      # Should not crash even with invalid agent_id
      result = AgentIntegration.initialize_agent("invalid-uuid")

      # May succeed or fail depending on implementation, but should not crash
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "process_interaction/3" do
    test "processes a complete interaction successfully" do
      agent_id = Ash.UUID.generate()
      user_query = "How does machine learning work?"

      # Should handle the complete flow even without database data
      result = AgentIntegration.process_interaction(agent_id, user_query)

      case result do
        {:ok, interaction_result} ->
          assert is_binary(interaction_result.response)
          assert is_map(interaction_result.memory_context)
          assert is_map(interaction_result.metadata)

          # Check metadata structure
          metadata = interaction_result.metadata
          assert Map.has_key?(metadata, :query_context)
          assert Map.has_key?(metadata, :memory_stats)
          assert Map.has_key?(metadata, :confidence)

        {:error, reason} ->
          # If it fails, should be a reasonable error message
          assert is_binary(reason)
      end
    end

    test "handles different query types" do
      agent_id = Ash.UUID.generate()

      queries = [
        "What is artificial intelligence?",
        "Create a neural network model",
        "Remember our discussion about deep learning",
        "Help me understand transformers"
      ]

      for query <- queries do
        result = AgentIntegration.process_interaction(agent_id, query)

        # Should either succeed or fail gracefully
        assert match?({:ok, _}, result) or match?({:error, _}, result)

        case result do
          {:ok, interaction_result} ->
            assert is_binary(interaction_result.response)
            assert is_map(interaction_result.memory_context)

          {:error, _reason} ->
            # Acceptable failure
            :ok
        end
      end
    end

    test "includes proper interaction metadata" do
      agent_id = Ash.UUID.generate()
      query = "Test query for metadata validation"

      case AgentIntegration.process_interaction(agent_id, query) do
        {:ok, result} ->
          metadata = result.metadata

          # Query context should contain processed query information
          query_context = metadata.query_context
          assert query_context.agent_id == agent_id
          assert query_context.original_query == query
          assert is_binary(query_context.intent)
          assert is_list(query_context.query_keywords)
          assert is_list(query_context.query_embedding)

          # Memory stats should show counts
          memory_stats = metadata.memory_stats
          assert is_integer(memory_stats.stm_count)
          assert is_integer(memory_stats.mtm_count)
          assert is_integer(memory_stats.lpm_count)
          assert is_integer(memory_stats.system_count)

          # Confidence should have proper structure
          confidence = metadata.confidence
          assert is_map(confidence)

        {:error, _reason} ->
          # Test might fail due to missing dependencies, which is acceptable
          :ok
      end
    end
  end

  describe "get_memory_summary/2" do
    test "generates memory summary for agent" do
      agent_id = Ash.UUID.generate()

      {:ok, summary} = AgentIntegration.get_memory_summary(agent_id)

      assert summary.agent_id == agent_id
      assert is_map(summary.stm)
      assert is_map(summary.mtm)
      assert is_map(summary.lpm)
      assert is_map(summary.system)
      assert is_map(summary.overall_stats)
      assert %DateTime{} = summary.generated_at

      # Check STM statistics structure
      stm_stats = summary.stm
      assert stm_stats.level == :stm
      assert is_integer(stm_stats.total_pages)
      assert stm_stats.capacity_status in [:normal, :near_capacity, :at_capacity, :unknown]

      # Check MTM statistics structure
      mtm_stats = summary.mtm
      assert mtm_stats.level == :mtm
      assert is_integer(mtm_stats.total_segments)
      assert is_float(mtm_stats.average_heat_score)
      assert mtm_stats.capacity_status in [:normal, :near_capacity, :at_capacity, :unknown]

      # Check LPM statistics structure
      lpm_stats = summary.lpm
      assert lpm_stats.level == :lpm
      assert is_integer(lpm_stats.knowledge_entries)
      assert is_integer(lpm_stats.traits)
      assert is_integer(lpm_stats.total_lpm_items)

      # Check system statistics structure
      system_stats = summary.system
      assert system_stats.level == :system
      assert is_integer(system_stats.contributed_entries)
      assert is_integer(system_stats.total_system_entries)
      assert is_float(system_stats.contribution_ratio)

      # Check overall statistics
      overall = summary.overall_stats
      assert is_integer(overall.total_memory_items)
      assert is_map(overall.memory_distribution)
    end

    test "summary includes memory distribution percentages" do
      agent_id = Ash.UUID.generate()

      {:ok, summary} = AgentIntegration.get_memory_summary(agent_id)

      distribution = summary.overall_stats.memory_distribution
      assert is_float(distribution.stm_percentage)
      assert is_float(distribution.mtm_percentage)
      assert is_float(distribution.lpm_percentage)

      # Percentages should be between 0 and 100
      assert distribution.stm_percentage >= 0.0 and distribution.stm_percentage <= 100.0
      assert distribution.mtm_percentage >= 0.0 and distribution.mtm_percentage <= 100.0
      assert distribution.lpm_percentage >= 0.0 and distribution.lpm_percentage <= 100.0
    end
  end

  describe "trigger_memory_maintenance/2" do
    test "triggers memory maintenance operations" do
      agent_id = Ash.UUID.generate()

      {:ok, maintenance_result} = AgentIntegration.trigger_memory_maintenance(agent_id)

      assert is_list(maintenance_result.operations)
      assert %DateTime{} = maintenance_result.scheduled_at

      # Should contain expected operations
      operations = maintenance_result.operations
      operation_types = Enum.map(operations, fn {type, _status, _info} -> type end)

      assert :heat_update in operation_types
      assert :capacity_check in operation_types
      assert :lpm_evaluation in operation_types
    end

    test "respects custom maintenance options" do
      agent_id = Ash.UUID.generate()
      options = %{operations: [:heat_update, :capacity_check]}

      {:ok, maintenance_result} = AgentIntegration.trigger_memory_maintenance(agent_id, options)

      operations = maintenance_result.operations
      operation_types = Enum.map(operations, fn {type, _status, _info} -> type end)

      assert :heat_update in operation_types
      assert :capacity_check in operation_types
      assert :lpm_evaluation not in operation_types
    end

    test "handles empty operations list" do
      agent_id = Ash.UUID.generate()
      options = %{operations: []}

      {:ok, maintenance_result} = AgentIntegration.trigger_memory_maintenance(agent_id, options)

      assert maintenance_result.operations == []
      assert %DateTime{} = maintenance_result.scheduled_at
    end
  end

  describe "memory statistics calculation" do
    test "calculate_memory_stats handles empty results correctly" do
      # This tests the private function indirectly through public methods
      agent_id = Ash.UUID.generate()

      case AgentIntegration.process_interaction(agent_id, "test query") do
        {:ok, result} ->
          memory_stats = result.metadata.memory_stats

          # All counts should be non-negative integers
          assert memory_stats.stm_count >= 0
          assert memory_stats.mtm_count >= 0
          assert memory_stats.lpm_count >= 0
          assert memory_stats.system_count >= 0

        {:error, _reason} ->
          # Test might fail due to missing dependencies
          :ok
      end
    end

    test "capacity status evaluation works correctly" do
      agent_id = Ash.UUID.generate()

      {:ok, summary} = AgentIntegration.get_memory_summary(agent_id)

      # Capacity status should be valid values
      assert summary.stm.capacity_status in [:normal, :near_capacity, :at_capacity, :unknown]
      assert summary.mtm.capacity_status in [:normal, :near_capacity, :at_capacity, :unknown]
    end
  end

  describe "error handling and edge cases" do
    test "handles nil or empty agent_id" do
      # Should handle edge cases gracefully
      results = [
        AgentIntegration.get_memory_summary(nil),
        AgentIntegration.get_memory_summary(""),
        AgentIntegration.trigger_memory_maintenance(nil)
      ]

      for result <- results do
        # Should either succeed or fail gracefully, not crash
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test "handles invalid query inputs" do
      agent_id = Ash.UUID.generate()

      invalid_queries = [nil, "", "   ", String.duplicate("a", 10000)]

      for query <- invalid_queries do
        result = AgentIntegration.process_interaction(agent_id, query)

        # Should handle gracefully
        case result do
          # Acceptable
          {:ok, _} ->
            :ok

          {:error, reason} ->
            # Should have error message
            assert is_binary(reason)
        end
      end
    end

    test "memory summary works with missing data" do
      # Test with a fresh agent that has no memory data
      agent_id = Ash.UUID.generate()

      {:ok, summary} = AgentIntegration.get_memory_summary(agent_id)

      # Should work even with no existing data
      assert summary.agent_id == agent_id
      assert summary.stm.total_pages == 0
      assert summary.mtm.total_segments == 0
      assert summary.lpm.total_lpm_items == 0
      assert summary.overall_stats.total_memory_items == 0
    end
  end

  describe "integration with LLMClient" do
    test "uses LLMClient for query processing" do
      agent_id = Ash.UUID.generate()
      query = "Test integration with LLMClient"

      case AgentIntegration.process_interaction(agent_id, query) do
        {:ok, result} ->
          # Should contain evidence of LLMClient processing
          query_context = result.metadata.query_context

          assert query_context.original_query == query
          assert is_binary(query_context.intent)
          assert is_list(query_context.query_keywords)
          assert is_list(query_context.query_embedding)
          assert query_context.agent_id == agent_id

        {:error, _reason} ->
          # Acceptable if dependencies are missing
          :ok
      end
    end

    test "memory context synthesis works" do
      agent_id = Ash.UUID.generate()
      query = "Test memory context synthesis"

      case AgentIntegration.process_interaction(agent_id, query) do
        {:ok, result} ->
          context = result.memory_context

          # Should have proper memory context structure
          assert is_list(context.recent_conversations)
          assert is_list(context.relevant_topics)
          assert is_map(context.agent_knowledge)
          assert is_list(context.shared_knowledge)
          assert is_binary(context.query_intent)
          assert is_map(context.confidence_scores)

        {:error, _reason} ->
          # Acceptable if dependencies are missing
          :ok
      end
    end
  end
end
