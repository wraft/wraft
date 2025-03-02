defmodule WraftDoc.Fields do
  @moduledoc """
  The Fields context.
  """
  import Ecto
  require Logger

  alias WraftDoc.Fields.Field
  alias WraftDoc.Repo

  @doc """
  Creates a field.

  ## Example

  iex> create_field(%FieldType{}, %{name: "name"})
  {:ok, %Field{}}

  iex> create_field(%FieldType{}, %{})
  {:error, %Ecto.Changeset{}}
  """
  def create_field(field_type, params) do
    field_type
    |> build_assoc(:fields)
    |> Field.changeset(params)
    |> Repo.insert()
  end

  # TODO write test
  @doc """
    Update a field
  """
  @spec update_field(Field.t(), map) :: Field.t() | nil
  def update_field(%Field{} = field, params) do
    field
    |> Field.update_changeset(params)
    |> Repo.update()
  end

  # TODO write test
  @doc """
    Get field
  """
  @spec get_field(Ecto.UUID.t()) :: Field.t() | nil
  def get_field(<<_::288>> = field_id) do
    Repo.get(Field, field_id)
  end

  def get_field(_), do: nil
end
