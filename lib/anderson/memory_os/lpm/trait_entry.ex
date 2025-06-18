defmodule Anderson.MemoryOS.LPM.TraitEntry do
  use Ash.Resource,
    domain: Anderson.MemoryOS,
    data_layer: AshPostgres.DataLayer

  @moduledoc """
  Long-Term Personal Memory (LPM) TraitEntry Resource
  
  Stores inferred traits/properties of entities that agents interact with.
  Implemented as a fixed-size queue for each ObjectPersona or AgentPersona.
  """

  postgres do
    table "memory_lpm_trait_entries"
    repo Anderson.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      description "The name of the trait"
      allow_nil? false
    end

    attribute :value, :string do
      description "The value of the trait"
      allow_nil? false
    end

    attribute :confidence, :float do
      description "Confidence level in the trait (0.0-1.0)"
      default 1.0
      constraints min: 0.0, max: 1.0
    end

    attribute :created_at, :utc_datetime do
      description "When this trait was recorded"
      default &DateTime.utc_now/0
    end

    attribute :object_persona_id, :uuid do
      description "Reference to the owning ObjectPersona, if applicable"
      default nil
    end

    attribute :agent_persona_id, :uuid do
      description "Reference to the owning AgentPersona, if applicable"
      default nil
    end

    timestamps()
  end

  relationships do
    belongs_to :object_persona, Anderson.MemoryOS.LPM.ObjectPersona do
      attribute_writable? true
      allow_nil? true
    end

    belongs_to :agent_persona, Anderson.MemoryOS.LPM.AgentPersona do
      attribute_writable? true
      allow_nil? true
    end
  end

  # Custom validation will be implemented in a before_action hook
  validations do
    # This will be replaced with custom validation logic
  end
  
  # Add a custom validation in a before_action hook
  actions do
    defaults [:read, :destroy]
    
    create :create do
      before_action :validate_relationships
    end
    
    update :update do
      before_action :validate_relationships
    end
  end
  
  # Define the function to validate exactly one of object_persona_id or agent_persona_id is set
  identities do
    identity :exclusive_persona, [:object_persona_id, :agent_persona_id]
  end

  code_interface do
    define :create
    define :read
    define :by_id, args: [:id], action: :read
    define :update
    define :destroy
  end
end
