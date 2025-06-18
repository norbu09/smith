defmodule Anderson.MemoryOS.LPM.KnowledgeBaseEntry do
  use Ash.Resource,
    domain: Anderson.MemoryOS,
    data_layer: AshPostgres.DataLayer

  @moduledoc """
  Long-Term Personal Memory (LPM) KnowledgeBaseEntry Resource
  
  Stores factual information about entities that agents interact with.
  Implemented as a fixed-size queue for each ObjectPersona.
  """

  postgres do
    table "memory_lpm_knowledge_base_entries"
    repo Anderson.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :fact, :string do
      description "The factual knowledge to store"
      allow_nil? false
    end

    attribute :confidence, :float do
      description "Confidence level in the fact (0.0-1.0)"
      default 1.0
      constraints min: 0.0, max: 1.0
    end

    attribute :created_at, :utc_datetime do
      description "When this fact was recorded"
      default &DateTime.utc_now/0
    end

    attribute :object_persona_id, :uuid do
      description "Reference to the owning ObjectPersona"
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :object_persona, Anderson.MemoryOS.LPM.ObjectPersona do
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  code_interface do
    define :create
    define :read
    define :by_id, args: [:id], action: :read
    define :update
    define :destroy
  end
end
