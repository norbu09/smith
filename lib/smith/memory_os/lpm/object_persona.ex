defmodule Smith.MemoryOS.LPM.ObjectPersona do
  use Ash.Resource,
    domain: Smith.MemoryOS,
    data_layer: AshPostgres.DataLayer

  @moduledoc """
  Long-Term Personal Memory (LPM) ObjectPersona Resource

  Flexible storage for any entity the agent interacts with, such as users, domains, products, etc.
  """

  postgres do
    table "memory_lpm_object_personas"
    repo Smith.Repo
  end

  code_interface do
    define :create
    define :read
    define :by_id, args: [:id], action: :read
    define :get_or_create, args: [:agent_id, :type, :identifier, :profile]
    define :add_knowledge, args: [:id, :fact, :confidence]
    define :add_trait, args: [:id, :name, :value, :confidence]
    define :update
    define :destroy
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :get_or_create do
      description "Get an existing ObjectPersona or create if it doesn't exist"

      argument :agent_id, :uuid do
        allow_nil? false
      end

      argument :type, :string do
        allow_nil? false
      end

      argument :identifier, :string do
        allow_nil? false
      end

      argument :profile, :map do
        default %{}
      end

      # Set attributes from arguments
      change set_attribute(:agent_id, arg(:agent_id))
      change set_attribute(:type, arg(:type))
      change set_attribute(:identifier, arg(:identifier))
      change set_attribute(:profile, arg(:profile))

      # Use upsert to either create or get existing
      upsert? true
      upsert_identity :unique_per_agent
    end

    update :add_knowledge do
      description "Add a piece of knowledge to this object persona"
      require_atomic? false

      # Accept the id parameter to align with code_interface
      argument :id, :uuid do
        allow_nil? false
        description "The ID of the object persona to add knowledge to"
      end

      argument :fact, :string do
        allow_nil? false
      end

      argument :confidence, :float do
        default 1.0
        constraints min: 0.0, max: 1.0
      end

      # Instead of using a custom Change module, implement the functionality directly
      change fn changeset, _context ->
        # Create a new KnowledgeBaseEntry associated with this persona
        knowledge_attrs = %{
          object_persona_id: changeset.data.id,
          fact: Ash.Changeset.get_argument(changeset, :fact),
          confidence: Ash.Changeset.get_argument(changeset, :confidence)
        }

        case Smith.MemoryOS.LPM.KnowledgeBaseEntry.create(knowledge_attrs) do
          {:ok, _entry} -> changeset
          {:error, error} -> Ash.Changeset.add_error(changeset, error)
        end
      end
    end

    update :add_trait do
      description "Add a trait to this object persona"
      require_atomic? false

      # Accept the id parameter to align with code_interface
      argument :id, :uuid do
        allow_nil? false
        description "The ID of the object persona to add trait to"
      end

      argument :name, :string do
        allow_nil? false
      end

      argument :value, :string do
        allow_nil? false
      end

      argument :confidence, :float do
        default 1.0
        constraints min: 0.0, max: 1.0
      end

      # Instead of using a custom Change module, implement the functionality directly
      change fn changeset, _context ->
        # Create a new TraitEntry associated with this persona
        trait_attrs = %{
          object_persona_id: changeset.data.id,
          name: Ash.Changeset.get_argument(changeset, :name),
          value: Ash.Changeset.get_argument(changeset, :value),
          confidence: Ash.Changeset.get_argument(changeset, :confidence)
        }

        case Smith.MemoryOS.LPM.TraitEntry.create(trait_attrs) do
          {:ok, _entry} -> changeset
          {:error, error} -> Ash.Changeset.add_error(changeset, error)
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :string do
      description "The type of entity (user, domain, product, etc.)"
      allow_nil? false
    end

    attribute :identifier, :string do
      description "Unique identifier for the entity"
      allow_nil? false
    end

    attribute :profile, :map do
      description "Flexible map of static attributes"
      default %{}
    end

    attribute :agent_id, :uuid do
      description "Reference to the owning agent"
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    # For knowledge base entries
    has_many :knowledge_base_entries, Smith.MemoryOS.LPM.KnowledgeBaseEntry do
      destination_attribute :object_persona_id
    end

    # For trait entries
    has_many :trait_entries, Smith.MemoryOS.LPM.TraitEntry do
      destination_attribute :object_persona_id
    end
  end

  # Identity ensures we don't create duplicate objects for the same entity
  identities do
    identity :unique_per_agent, [:agent_id, :type, :identifier]
  end
end
