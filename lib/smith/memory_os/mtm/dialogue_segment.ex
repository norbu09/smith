defmodule Smith.MemoryOS.MTM.DialogueSegment do
  use Ash.Resource,
    domain: Smith.MemoryOS,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAi, AshOban]

  @moduledoc """
  Mid-Term Memory (MTM) DialogueSegment Resource

  Groups related DialoguePages by topic and manages them based on heat score.
  """

  postgres do
    table "memory_mtm_dialogue_segments"
    repo Smith.Repo
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
    embedding_model Smith.OpenAiEmbeddingModel
  end

  oban do
    triggers do
      # Periodically update heat scores for segments
      trigger :update_heat do
        action :update_heat_score
        worker_read_action :read
        queue :memory
        worker_module_name Smith.MemoryOS.Workers.UpdateHeatScoreWorker
        scheduler_module_name Smith.MemoryOS.MTM.DialogueSegment.AshOban.Scheduler.UpdateHeat
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
        case Smith.MemoryOS.STM.DialoguePage.get(page_id) do
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

                  case Smith.MemoryOS.update(page_changeset) do
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
        case Smith.MemoryOS.STM.DialoguePage.get(page_id) do
          {:ok, page} ->
            page_changeset =
              Ash.Changeset.for_update(page, %{})
              |> Ash.Changeset.set_attribute(:dialogue_segment_id, segment_id)

            case Smith.MemoryOS.update(page_changeset) do
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
          |> Smith.MemoryOS.update()

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
    has_many :dialogue_pages, Smith.MemoryOS.STM.DialoguePage do
      description "Links to STM pages"
    end
  end

  calculations do
    # Vector similarity using pgvector - will be computed when context provides query embedding
    calculate :cosine_similarity,
              :float,
              {Smith.MemoryOS.Calculations, :segment_cosine_similarity, []},
              public?: false,
              description:
                "Calculate cosine similarity between segment embedding and query embedding"

    # Jaccard similarity between keyword sets - will be computed when context provides query keywords
    calculate :keyword_similarity,
              :float,
              {Smith.MemoryOS.Calculations, :segment_jaccard_similarity, []},
              public?: false,
              description:
                "Calculate Jaccard similarity between segment keywords and query keywords"

    # Final Fscore combining both measures - implements MemoryOS paper: Fscore = cos(e_s, e_p) + FJacard(K_s, K_p)
    calculate :fscore, :float, {Smith.MemoryOS.Calculations, :segment_fscore, []},
      description: "Combined similarity score implementing MemoryOS Fscore formula"

    # Recency factor calculation - implements MemoryOS paper: R_recency = exp(-Δt / μ)
    calculate :recency_factor,
              :float,
              expr(fragment("exp(-EXTRACT(EPOCH FROM (NOW() - ?)) / 1.0e7)", last_accessed)),
              description:
                "Calculate recency factor based on exponential decay from MemoryOS paper"

    # Count of dialogue pages in this segment for heat calculation
    calculate :page_count, :integer, expr(count(dialogue_pages, field: :id)),
      description: "Number of dialogue pages in this segment"

    # Heat score calculation - implements MemoryOS paper: Heat = α·N_visit + β·L_interaction + γ·R_recency
    calculate :calculate_heat, :float, {Smith.MemoryOS.Calculations, :segment_heat_score, []},
      description: "Calculate heat score based on MemoryOS paper formula with α=β=γ=1.0"
  end
end
