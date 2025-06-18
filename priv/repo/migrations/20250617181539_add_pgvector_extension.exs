defmodule Smith.Repo.Migrations.AddPgvectorExtension do
  use Ecto.Migration

  def change do
    # Enable the pgvector extension for vector embeddings support
    execute "CREATE EXTENSION IF NOT EXISTS vector"
  end
end
