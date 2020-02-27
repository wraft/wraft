defmodule WraftDoc.Document do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto
  alias WraftDoc.{Repo, Account.User, Document.Layout, Document.ContentType}

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

  @doc """
  Create a content type.
  """
  @spec create_content_type(%User{}, map) :: %ContentType{} | {:error, Ecto.Changeset.t()}
  def create_content_type(current_user, params) do
    current_user
    |> build_assoc(:content_types)
    |> ContentType.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, %ContentType{} = content_type} ->
        content_type |> Repo.preload(:layout)

      changeset = {:error, _} ->
        changeset
    end
  end
end
