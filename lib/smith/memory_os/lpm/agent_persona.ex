defmodule Smith.MemoryOS.LPM.AgentPersona do
  use Ash.Resource,
    domain: Smith.MemoryOS,
    data_layer: AshPostgres.DataLayer

  @moduledoc """
  Long-Term Personal Memory (LPM) AgentPersona Resource

  Stores agent's own traits and history, forming its core identity.
  """

  postgres do
    table "memory_lpm_agent_personas"
    repo Smith.Repo
  end

  code_interface do
    define :create
    define :read
    define :by_id, args: [:id], action: :read
    define :get_or_create, args: [:agent_id, :profile]
    define :add_trait, args: [:id, :name, :value, :confidence]
    define :update_profile, args: [:id, :profile_updates]
    define :update
    define :destroy
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :get_or_create do
      description "Get an existing AgentPersona or create if it doesn't exist"

      argument :agent_id, :uuid do
        allow_nil? false
      end

      argument :profile, :map do
        default %{}
      end

      # Set attributes from arguments
      change set_attribute(:agent_id, arg(:agent_id))
      change set_attribute(:profile, arg(:profile))

      # Use upsert to either create or get existing
      upsert? true
      upsert_identity :unique_agent
    end

    update :add_trait do
      description "Add a trait to this agent persona"
      require_atomic? false

      # Add id argument to align with code_interface
      argument :id, :uuid do
        allow_nil? false
        description "The ID of the agent persona to add trait to"
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

      # Direct implementation instead of using a custom Change module
      change fn changeset, _context ->
        # Create the TraitEntry for this agent persona
        agent_persona_id = Ash.Changeset.get_attribute(changeset, :id)
        name = Ash.Changeset.get_argument(changeset, :name)
        value = Ash.Changeset.get_argument(changeset, :value)
        confidence = Ash.Changeset.get_argument(changeset, :confidence)

        trait_params = %{
          name: name,
          value: value,
          confidence: confidence,
          agent_persona_id: agent_persona_id,
          object_persona_id: nil
        }

        case Smith.MemoryOS.LPM.TraitEntry.create(trait_params) do
          {:ok, _trait} -> changeset
          {:error, error} -> Ash.Changeset.add_error(changeset, error)
        end
      end
    end

    update :update_profile do
      description "Update the agent's profile"
      require_atomic? false

      # Add id argument to align with code_interface
      argument :id, :uuid do
        allow_nil? false
        description "The ID of the agent persona to update the profile for"
      end

      argument :profile_updates, :map do
        allow_nil? false
      end

      change fn changeset, _ ->
        current_profile = Ash.Changeset.get_attribute(changeset, :profile) || %{}

        updated_profile =
          Map.merge(current_profile, Ash.Changeset.get_argument(changeset, :profile_updates))

        Ash.Changeset.change_attribute(changeset, :profile, updated_profile)
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :profile, :map do
      description "Agent's core identity settings"
      default %{}
    end

    attribute :agent_id, :uuid do
      description "Reference to the agent itself"
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    # For trait entries
    has_many :trait_entries, Smith.MemoryOS.LPM.TraitEntry do
      destination_attribute :agent_persona_id
    end
  end

  # Identity ensures we don't create duplicate agent personas
  identities do
    identity :unique_agent, [:agent_id]
  end
end
