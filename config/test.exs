import Config
config :smith, Oban, testing: :manual

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :smith, Smith.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "smith_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :smith, SmithWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "oqpIBodLVh8FUGnBKTZ5s3jNYm+boOqiSdFWOvNUgteJyGjLDECIatSOO9WiTBY/",
  server: false

# In test we don't send emails
config :smith, Smith.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# MemoryOS configuration for test environment
config :smith,
  # Always use mock embeddings in test environment
  use_mock_embeddings: true,
  # No OpenAI API key needed for tests
  openai_api_key: nil
