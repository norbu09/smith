defmodule Smith.MemoryOS.SystemMemory do
  use Ash.Resource,
    domain: Smith.MemoryOS,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAi, AshOban]

  @moduledoc """
  System Memory Resource

  Cross-agent shared knowledge accessible by all agents based on importance scoring.
  """

  postgres do
    table "memory_system_memories"
    repo Smith.Repo
  end

  # Set up vectorization for system memory content
  vectorize do
    full_text do
      text fn entry ->
        entry.content
      end

      used_attributes [:content]
    end

    strategy :ash_oban
    ash_oban_trigger_name :generate_embedding
    attributes content: :embedding
    embedding_model Smith.OpenAiEmbeddingModel
  end

  oban do
    triggers do
      trigger :generate_embedding do
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
    define :contribute, args: [:content, :source_agent_id, :importance_score]
    define :search_by_similarity, args: [:query_text, :limit]
    define :update
    define :destroy
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :contribute do
      description "Contribute a new piece of knowledge to the system memory"

      argument :content, :string do
        allow_nil? false
      end

      argument :source_agent_id, :uuid do
        allow_nil? false
      end

      argument :importance_score, :float do
        default 0.5
        constraints min: 0.0, max: 1.0
      end

      change set_attribute(:content, arg(:content))
      change set_attribute(:source_agent_id, arg(:source_agent_id))
      change set_attribute(:importance_score, arg(:importance_score))

      # We'll handle the embedding generation in an after_transaction hook
      change fn changeset, _context ->
        # After a successful create, schedule the embedding generation
        changeset
        |> Ash.Changeset.after_transaction(fn _result, changeset ->
          record = Ash.Changeset.get_record(changeset)
          AshOban.schedule(record, :generate_embedding)
          {:ok, record}
        end)
      end
    end

    read :search_by_similarity do
      description "Find relevant system memory entries by similarity search"

      argument :query_text, :string do
        description "The query text to find relevant memories for"
        allow_nil? false
      end

      argument :limit, :integer do
        description "Maximum number of results to return"
        default 10
        constraints min: 1, max: 100
      end

      prepare fn query, _context ->
        # In a real implementation, this would:
        # 1. Generate an embedding for the query text
        # 2. Use vector similarity search to find the most similar entries
        # For now, we'll just return a sorted query
        query
        |> Ash.Query.sort(desc: :importance_score)
        |> Ash.Query.limit(query.arguments.limit)
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      description "The shared knowledge/fact"
      allow_nil? false
    end

    attribute :embedding, {:array, :float} do
      description "Vector for similarity search"
    end

    attribute :source_agent_id, :uuid do
      description "Agent that contributed this entry"
    end

    attribute :importance_score, :float do
      description "Measure of global importance"
      default 0.0
      constraints min: 0.0, max: 1.0
    end

    attribute :creation_timestamp, :utc_datetime do
      description "When it was added"
      default &DateTime.utc_now/0
    end

    timestamps()
  end
end
