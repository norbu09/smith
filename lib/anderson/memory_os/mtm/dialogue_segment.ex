defmodule Anderson.MemoryOS.MTM.DialogueSegment do
  use Ash.Resource,
    domain: Anderson.MemoryOS,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAi, AshOban]

  @moduledoc """
  Mid-Term Memory (MTM) DialogueSegment Resource

  Groups related DialoguePages by topic and manages them based on heat score.
  """

  postgres do
    table "memory_mtm_dialogue_segments"
    repo Anderson.Repo
  end

  # Set up vectorization for the segment content
  # This will be used for similarity searching
  vectorize do
    full_text do
      text fn segment ->
        # Combine topic summary and keywords for vectorization
        """
        Topic: #{segment.topic_summary}
        Keywords: #{Enum.join(segment.keywords, ", ")}
        """
      end

      # When these attributes change, embeddings will be rebuilt
      used_attributes [:topic_summary, :keywords]
    end

    strategy :ash_oban
    ash_oban_trigger_name :vectorize_segment
    # Store the embedding in the embedding attribute
    attributes topic_summary: :embedding

    # We'll create a proper embedding model later
    embedding_model Anderson.OpenAiEmbeddingModel
  end

  oban do
    triggers do
      # Periodically update heat scores for segments
      trigger :update_heat do
        action :update_heat_score
        worker_read_action :read
        queue :memory
        worker_module_name Anderson.MemoryOS.Workers.UpdateHeatScoreWorker
        scheduler_module_name Anderson.MemoryOS.MTM.DialogueSegment.AshOban.Scheduler.UpdateHeat
        # The worker implementation will be defined separately
      end
    end
  end

  oban do
    triggers do
      trigger :vectorize_segment do
        action :ash_ai_update_embeddings
        worker_read_action :read
        worker_module_name __MODULE__.AshOban.Worker.UpdateEmbeddings
        scheduler_module_name __MODULE__.AshOban.Scheduler.UpdateEmbeddings
        queue :memory
      end
    end
  end

  code_interface do
    define :create
    define :read
    define :by_id, args: [:id], action: :read
    define :create_from_page, args: [:page_id]
    define :add_page_to_segment, args: [:id, :page_id]
    define :update
    define :destroy
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :create_from_page do
      description "Create a new segment from a dialogue page"

      argument :page_id, :uuid do
        allow_nil? false
      end

      # Direct implementation instead of using a custom Change module
      change fn changeset, _context ->
        # Get the page ID from arguments
        page_id = Ash.Changeset.get_argument(changeset, :page_id)

        # Fetch the page
        case Anderson.MemoryOS.STM.DialoguePage.get(page_id) do
          {:ok, page} ->
            # Setup attributes for the segment from the page
            changeset
            |> Ash.Changeset.set_attribute(:topic_summary, "Topic from page #{page_id}")
            |> Ash.Changeset.set_attribute(:agent_id, page.agent_id)
            |> Ash.Changeset.after_transaction(fn result, _changeset ->
              case result do
                {:ok, segment} ->
                  # Link the page to the new segment
                  page_changeset =
                    Ash.Changeset.for_update(page, %{})
                    |> Ash.Changeset.set_attribute(:dialogue_segment_id, segment.id)

                  case Anderson.MemoryOS.update(page_changeset) do
                    {:ok, _} -> {:ok, segment}
                    {:error, err} -> {:error, err}
                  end

                {:error, _} = error ->
                  error
              end
            end)

          {:error, error} ->
            Ash.Changeset.add_error(changeset, error)
        end
      end
    end

    update :add_page_to_segment do
      description "Add a dialogue page to this segment"
      require_atomic? false

      # Accept the id parameter to align with code_interface
      argument :id, :uuid do
        allow_nil? false
        description "The ID of the dialogue segment to add the page to"
      end

      argument :page_id, :uuid do
        allow_nil? false
      end

      # Direct implementation instead of using a custom Change module
      change fn changeset, _context ->
        # Get the page ID from arguments
        page_id = Ash.Changeset.get_argument(changeset, :page_id)
        segment_id = Ash.Changeset.get_argument(changeset, :id)

        # Update the dialogue page to reference this segment
        case Anderson.MemoryOS.STM.DialoguePage.get(page_id) do
          {:ok, page} ->
            page_changeset =
              Ash.Changeset.for_update(page, %{})
              |> Ash.Changeset.set_attribute(:dialogue_segment_id, segment_id)

            case Anderson.MemoryOS.update(page_changeset) do
              {:ok, _updated_page} -> changeset
              {:error, error} -> Ash.Changeset.add_error(changeset, error)
            end

          {:error, error} ->
            Ash.Changeset.add_error(changeset, error)
        end
      end
    end

    update :update_heat_score do
      description "Recalculate and update the heat score"
      require_atomic? false

      change fn segment, _context ->
        # We'll use the heat calculation
        {:ok, segment} =
          Ash.Changeset.for_update(segment, %{})
          |> Ash.Changeset.load_calculation(:calculate_heat)
          |> Ash.Changeset.force_change_attribute(:heat_score, segment.calculate_heat)
          |> Anderson.MemoryOS.update()

        {:ok, segment}
      end
    end

    read :find_best_segment_for_page do
      description "Find the best segment for a dialogue page by Fscore"

      argument :page_id, :uuid do
        allow_nil? false
      end

      filter expr(agent_id == ^arg(:agent_id))

      prepare fn query, context ->
        page_id = context.arguments.page_id

        # Implementation would:
        # 1. Load page
        # 2. Extract embedding and keywords
        # 3. Calculate Fscore for each segment
        # 4. Return segment with highest Fscore if above threshold

        # Placeholder implementation
        query
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :topic_summary, :string do
      description "LLM-generated summary of segment content"
    end

    # Store the embedding vector generated by the vectorize DSL
    attribute :embedding, {:array, :float} do
      description "Vector representation for similarity calculations"
    end

    attribute :keywords, {:array, :string} do
      description "Set of keywords extracted by LLM"
      default []
    end

    attribute :heat_score, :float do
      description "Calculated engagement score"
      default 0.0
    end

    attribute :visit_count, :integer do
      description "Number of retrievals"
      default 0
    end

    attribute :last_accessed, :utc_datetime do
      description "Timestamp for recency factor"
      default &DateTime.utc_now/0
    end

    attribute :agent_id, :uuid do
      description "Reference to the owning agent"
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    has_many :dialogue_pages, Anderson.MemoryOS.STM.DialoguePage do
      description "Links to STM pages"
    end
  end

  calculations do
    # Vector similarity using pgvector
    calculate :cosine_similarity, :float, private?: true do
      description "Calculate cosine similarity between segment embedding and query embedding"
      # Note: This calculation will be used with the supplied query embedding during runtime

      # Will be implemented using a database fragment once necessary
      # fn segment, context ->
      #   query_embedding = context.query_embedding
      #   fragment("cosine_similarity(?::vector, ?::vector)",
      #     segment.embedding,
      #     query_embedding)
      # end
      fn segment, _context ->
        Anderson.MemoryOS.Calculations.placeholder_calculation(segment, %{})
      end
    end

    # Jaccard similarity between keyword sets
    calculate :keyword_similarity, :float, private?: true do
      description "Calculate Jaccard similarity between segment keywords and query keywords"
      # Note: This calculation will be used with supplied query keywords during runtime

      # Will be implemented once necessary
      # Use an anonymous function wrapper instead of direct function reference
      fn segment, _context ->
        Anderson.MemoryOS.Calculations.placeholder_calculation(segment, %{})
      end
    end

    # Final Fscore combining both measures
    calculate :fscore, :float, depends_on: [:cosine_similarity, :keyword_similarity] do
      description "Combined similarity score (cosine + Jaccard)"

      fn segment, _ ->
        segment.cosine_similarity + segment.keyword_similarity
      end
    end

    # Recency factor calculation
    calculate :recency_factor, :float, private?: true do
      description "Calculate recency factor based on exponential decay"

      fn segment, context ->
        μ = context[:time_constant] || 1.0e7
        delta_t = DateTime.diff(DateTime.utc_now(), segment.last_accessed, :second)
        :math.exp(-delta_t / μ)
      end
    end

    # Heat score calculation
    calculate :calculate_heat, :float, depends_on: [:visit_count, :recency_factor] do
      description "Calculate heat based on visit count, page count and recency"

      fn segment, context ->
        # These values should come from configuration in practice
        α = context[:heat_alpha] || 1.0
        β = context[:heat_beta] || 0.5
        γ = context[:heat_gamma] || 2.0

        # Get the page count
        page_count = length(segment.dialogue_pages)

        α * segment.visit_count +
          β * page_count +
          γ * segment.recency_factor
      end
    end
  end
end
