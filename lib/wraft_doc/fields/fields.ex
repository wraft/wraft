defmodule WraftDoc.Fields do
  @moduledoc """
  The Fields context.
  """
  import Ecto
  require Logger

  alias WraftDoc.Account.User
  alias WraftDoc.Fields.Field
  alias WraftDoc.Fields.FieldType
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

  @doc """
  Create a field type
  """
  @spec create_field_type(User.t(), map) :: {:ok, FieldType.t()}
  def create_field_type(%User{} = current_user, params) do
    current_user
    |> build_assoc(:field_types)
    |> FieldType.changeset(params)
    |> Repo.insert()
  end

  def create_field_type(_, _), do: {:error, :fake}

  @doc """
  Index of all field types.
  """
  @spec field_type_index() :: [FieldType.t()]
  def field_type_index, do: Repo.all(FieldType, order_by: [desc: :id])

  @doc """
  Get a field type.
  """
  @spec get_field_type(binary) :: FieldType.t()
  def get_field_type(<<_::288>> = field_type_id) do
    case Repo.get(FieldType, field_type_id) do
      %FieldType{} = field_type -> field_type
      _ -> {:error, :invalid_id, "FieldType"}
    end
  end

  def get_field_type(_), do: {:error, :fake}

  @spec get_field_type_by_name(String.t()) :: FieldType.t() | nil
  def get_field_type_by_name(field_type_name) do
    case Repo.get_by(FieldType, name: field_type_name) do
      %FieldType{} = field_type -> field_type
      _ -> nil
    end
  end

  @doc """
  Update a field type
  """
  @spec update_field_type(FieldType.t(), map) :: FieldType.t() | {:error, Ecto.Changeset.t()}
  def update_field_type(field_type, params) do
    field_type
    |> FieldType.changeset(params)
    |> Repo.update()
  end

  @doc """
  Deleta a field type
  """
  @spec delete_field_type(FieldType.t()) :: {:ok, FieldType.t()} | {:error, Ecto.Changeset.t()}
  def delete_field_type(field_type) do
    field_type
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :fields,
      message:
        "Cannot delete the field type. Some Content types depend on this field type. Update those content types and then try again.!"
    )
    |> Repo.delete()
  end
end
