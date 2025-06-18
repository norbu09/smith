defmodule Anderson.OpenAiEmbeddingModel do
  use AshAi.EmbeddingModel

  @moduledoc """
  Embedding model that uses OpenAI API to generate vector embeddings.

  This implementation uses the text-embedding-3-large model to generate
  embeddings with 3072 dimensions.
  """

  @impl true
  def dimensions(_opts), do: 3072

  @impl true
  def generate(texts, _opts) do
    # API key should be fetched from environment or configuration
    # For development, we'll use Application config for now
    api_key = Application.get_env(:anderson, :openai_api_key) || System.get_env("OPENAI_API_KEY")

    unless api_key do
      raise "OpenAI API key not found. Please set it in config or as OPENAI_API_KEY environment variable"
    end

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    body = %{
      "input" => texts,
      "model" => "text-embedding-3-large"
    }

    case Req.post("https://api.openai.com/v1/embeddings",
           json: body,
           headers: headers
         ) do
      {:ok, %{status: 200, body: response}} ->
        response["data"]
        |> Enum.map(fn %{"embedding" => embedding} -> embedding end)
        |> then(&{:ok, &1})

      {:ok, %{status: status, body: body}} ->
        {:error, "OpenAI API error: #{status}, #{inspect(body)}"}

      {:error, error} ->
        {:error, "Request error: #{inspect(error)}"}
    end
  end
end
