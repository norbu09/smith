defmodule Anderson.MemoryOS.Configuration do
  use Ash.Resource,
    domain: Anderson.MemoryOS,
    data_layer: AshPostgres.DataLayer

  @moduledoc """
  Configuration Resource for MemoryOS

  Stores agent-specific memory management settings like capacity limits,
  thresholds, and heat score calculation parameters.
  """

  postgres do
    table "memory_configurations"
    repo Anderson.Repo
  end

  code_interface do
    define :create
    define :read
    define :by_id, args: [:id], action: :read
    define :get_or_create, args: [:agent_id, :agent_type, :settings]
    define :update
    define :destroy
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :get_or_create do
      description "Get an existing Configuration or create if it doesn't exist"

      argument :agent_id, :uuid do
        allow_nil? false
      end

      argument :agent_type, :string do
        default "default"
      end

      argument :settings, :map do
        description "Map of configuration settings to override defaults"
        default %{}
      end

      # Set attributes from arguments
      change set_attribute(:agent_id, arg(:agent_id))
      change set_attribute(:agent_type, arg(:agent_type))

      # Apply any overridden settings
      change fn changeset, _context ->
        settings = Ash.Changeset.get_argument(changeset, :settings)

        # Only apply settings that are specified
        Enum.reduce(settings, changeset, fn {key, value}, acc ->
          # Use a list of valid configuration fields to avoid cyclic dependency
          valid_config_keys = [
            :agent_id,
            :stm_max_pages,
            :mtm_max_segments,
            :lpm_max_entries,
            :system_memory_max_entries,
            :embedding_model,
            :embedding_dimensions,
            :heat_decay_coefficient,
            :heat_alpha,
            :heat_beta,
            :heat_gamma
          ]

          if key in valid_config_keys do
            Ash.Changeset.change_attribute(acc, key, value)
          else
            acc
          end
        end)
      end

      # Use upsert to either create or get existing
      upsert? true
      upsert_identity :unique_agent_config
      # List the fields explicitly rather than using Map.keys on the struct
      # since we can't access the struct before it's defined
      upsert_fields [
        :agent_id,
        :agent_type,
        :stm_capacity,
        :mtm_capacity,
        :mtm_fscore_threshold,
        :heat_alpha,
        :heat_beta,
        :heat_gamma,
        :heat_threshold,
        :object_kb_capacity,
        :object_traits_capacity,
        :agent_traits_capacity,
        :system_memory_importance_threshold
      ]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :agent_id, :uuid do
      description "Reference to the agent this configuration applies to"
      allow_nil? false
    end

    attribute :agent_type, :string do
      description "Type of agent, for applying type-specific defaults"
      default "default"
    end

    # STM Configuration
    attribute :stm_capacity, :integer do
      description "Maximum number of DialoguePages in STM"
      default 7
      constraints min: 1
    end

    # MTM Configuration
    attribute :mtm_capacity, :integer do
      description "Maximum number of DialogueSegments in MTM"
      default 200
      constraints min: 1
    end

    attribute :mtm_fscore_threshold, :float do
      description "Minimum Fscore for adding a page to an existing segment"
      default 0.6
      constraints min: 0.0, max: 1.0
    end

    # Heat Score Parameters
    attribute :heat_alpha, :float do
      description "Visit count weight in heat calculation"
      default 1.0
    end

    attribute :heat_beta, :float do
      description "Page count weight in heat calculation"
      default 0.5
    end

    attribute :heat_gamma, :float do
      description "Recency weight in heat calculation"
      default 2.0
    end

    attribute :heat_threshold, :float do
      description "Threshold for promoting MTM segments to LPM"
      default 5.0
    end

    # LPM Configuration
    attribute :object_kb_capacity, :integer do
      description "Maximum knowledge base entries per ObjectPersona"
      default 100
      constraints min: 1
    end

    attribute :object_traits_capacity, :integer do
      description "Maximum trait entries per ObjectPersona"
      default 50
      constraints min: 1
    end

    attribute :agent_traits_capacity, :integer do
      description "Maximum trait entries per AgentPersona"
      default 30
      constraints min: 1
    end

    # System Memory Configuration
    attribute :system_memory_importance_threshold, :float do
      description "Minimum importance for memory promotion to system memory"
      default 0.8
      constraints min: 0.0, max: 1.0
    end

    timestamps()
  end

  # Helper function to get configuration for a specific agent
  def get_agent_config(agent_id) do
    case Anderson.MemoryOS.Configuration.get_or_create(agent_id, "default", %{}) do
      {:ok, config} ->
        config

      {:error, _} ->
        # Create a map with default values instead of using the struct directly
        %{
          agent_id: agent_id,
          stm_max_pages: Application.get_env(:anderson, :memory_os)[:stm_max_pages],
          mtm_max_segments: Application.get_env(:anderson, :memory_os)[:mtm_max_segments],
          lpm_max_entries: Application.get_env(:anderson, :memory_os)[:lpm_max_entries],
          system_memory_max_entries:
            Application.get_env(:anderson, :memory_os)[:system_memory_max_entries],
          embedding_model: Application.get_env(:anderson, :memory_os)[:embedding_model],
          embedding_dimensions: Application.get_env(:anderson, :memory_os)[:embedding_dimensions],
          heat_decay_coefficient:
            Application.get_env(:anderson, :memory_os)[:heat_decay_coefficient],
          heat_alpha: Application.get_env(:anderson, :memory_os)[:heat_alpha],
          heat_beta: Application.get_env(:anderson, :memory_os)[:heat_beta],
          heat_gamma: Application.get_env(:anderson, :memory_os)[:heat_gamma]
        }
    end
  end

  # Identity ensures we don't create duplicate configurations for the same agent
  identities do
    identity :unique_agent_config, [:agent_id]
  end
end
