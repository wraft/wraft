defmodule WraftDoc.Document do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto
  alias WraftDoc.{Repo, Account.User, Document.Layout}

  @doc """
  Create a layout.
  """
  @spec create_layout(%User{}, map) :: %Layout{} | {:error, Ecto.Changeset.t()}
  def create_layout(current_user, params) do
    current_user
    |> build_assoc(:layouts)
    |> Layout.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, layout} ->
        layout |> Repo.preload(:engine)

      changeset = {:error, _} ->
        changeset
    end
  end
end
