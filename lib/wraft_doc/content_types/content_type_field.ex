defmodule WraftDoc.ContentTypes.ContentTypeField do
  @moduledoc """
  The ContentType Field schema
  """
  alias __MODULE__
  alias WraftDoc.Validations.Validation
  use WraftDoc.Schema
  import Ecto.Query
  alias WraftDoc.Repo

  @fields [:content_type_id, :field_id, :order, :machine_name]

  schema "content_type_field" do
    field(:order, :integer, default: 0)
    field(:machine_name, :string)
    embeds_many(:validations, Validation, on_replace: :delete)
    belongs_to(:content_type, WraftDoc.ContentTypes.ContentType)
    belongs_to(:field, WraftDoc.Fields.Field)

    timestamps()
  end

  def changeset(%ContentTypeField{} = content_type_field, attrs \\ %{}) do
    content_type_field
    |> cast(attrs, @fields)
    |> cast_embed(:validations, required: false, with: &Validation.changeset/2)
    |> validate_required([:content_type_id, :field_id])
    |> generate_machine_name()
    |> validate_machine_name()
    |> foreign_key_constraint(:content_type_id, message: "Please enter an existing content type")
    |> foreign_key_constraint(:field_id, message: "Please enter a valid field")
    |> unique_constraint([:content_type_id, :field_id],
      name: :field_content_type_unique_index,
      message: "already exist"
    )
    |> unique_constraint([:machine_name, :content_type_id],
      name: :content_type_field_machine_name_content_type_unique_index,
      message: "Machine name already exists in this content type"
    )
  end

  def update_changeset(%ContentTypeField{} = content_type_field, attrs \\ %{}) do
    content_type_field
    |> cast(attrs, @fields)
    |> cast_embed(:validations, required: false, with: &Validation.changeset/2)
    |> generate_machine_name()
    |> validate_machine_name()
    |> unique_constraint([:content_type_id, :field_id],
      name: :field_content_type_unique_index,
      message: "already exist"
    )
    |> unique_constraint([:machine_name, :content_type_id],
      name: :content_type_field_machine_name_content_type_unique_index,
      message: "Machine name already exists in this content type"
    )
  end

  defp generate_machine_name(changeset) do
    case get_change(changeset, :machine_name) do
      nil ->
        field_name = get_field_name_for_machine_name(changeset)

        if field_name do
          base_machine_name = to_machine_name(field_name)

          content_type_id =
            get_change(changeset, :content_type_id) || get_field(changeset, :content_type_id)

          unique_machine_name =
            ensure_unique_machine_name(changeset, base_machine_name, content_type_id)

          put_change(changeset, :machine_name, unique_machine_name)
        else
          changeset
        end

      machine_name ->
        content_type_id =
          get_change(changeset, :content_type_id) || get_field(changeset, :content_type_id)

        unique_machine_name = ensure_unique_machine_name(changeset, machine_name, content_type_id)
        put_change(changeset, :machine_name, unique_machine_name)
    end
  end

  defp get_field_name_for_machine_name(changeset) do
    case get_field(changeset, :field) do
      %{name: name} ->
        name

      _ ->
        get_field_name_from_field_id(changeset)
    end
  end

  defp get_field_name_from_field_id(changeset) do
    field_id = get_change(changeset, :field_id) || get_field(changeset, :field_id)

    case field_id do
      nil ->
        nil

      field_id ->
        get_field_name_by_id(field_id)
    end
  end

  defp get_field_name_by_id(field_id) do
    case Repo.get(WraftDoc.Fields.Field, field_id) do
      %{name: name} -> name
      _ -> nil
    end
  end

  defp ensure_unique_machine_name(_changeset, base_name, content_type_id)
       when is_nil(content_type_id) do
    base_name
  end

  defp ensure_unique_machine_name(changeset, base_name, content_type_id) do
    content_type_field_id = get_field(changeset, :id)

    query =
      from(ctf in ContentTypeField,
        where: ctf.machine_name == ^base_name and ctf.content_type_id == ^content_type_id
      )

    query =
      if content_type_field_id do
        where(query, [ctf], ctf.id != ^content_type_field_id)
      else
        query
      end

    case Repo.one(query) do
      nil -> base_name
      _ -> find_unique_machine_name(base_name, content_type_id, content_type_field_id, 1)
    end
  end

  defp find_unique_machine_name(base_name, content_type_id, content_type_field_id, suffix) do
    candidate = "#{base_name}_#{suffix}"

    query =
      from(ctf in ContentTypeField,
        where: ctf.machine_name == ^candidate and ctf.content_type_id == ^content_type_id
      )

    query =
      if content_type_field_id do
        where(query, [ctf], ctf.id != ^content_type_field_id)
      else
        query
      end

    case Repo.one(query) do
      nil -> candidate
      _ -> find_unique_machine_name(base_name, content_type_id, content_type_field_id, suffix + 1)
    end
  end

  defp to_machine_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.replace(~r/\s+/, "_")
    |> String.trim()
    |> then(fn
      "" -> "field"
      machine_name -> machine_name
    end)
  end

  defp to_machine_name(_), do: "field"

  defp validate_machine_name(changeset) do
    case get_change(changeset, :machine_name) do
      nil ->
        changeset

      machine_name ->
        if Regex.match?(~r/^[a-z0-9_]+$/, machine_name) do
          changeset
        else
          add_error(
            changeset,
            :machine_name,
            "must contain only lowercase letters, numbers, and underscores"
          )
        end
    end
  end
end
