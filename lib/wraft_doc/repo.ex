defmodule WraftDoc.Repo do
  use Ecto.Repo, otp_app: :wraft_doc, adapter: Ecto.Adapters.Postgres
  use Scrivener, page_size: 10

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """

  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end

  @doc """
  Function to Reduce structs preloaded field during update to get updated data on next preload
  """
  def unpreload(struct, field, cardinality \\ :one) do
    %{
      struct
      | field => %Ecto.Association.NotLoaded{
          __field__: field,
          __owner__: struct.__struct__,
          __cardinality__: cardinality
        }
    }
  end
end
