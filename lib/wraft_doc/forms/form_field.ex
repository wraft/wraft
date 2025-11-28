defmodule WraftDoc.Forms.FormField do
  @moduledoc """
    form field  model.
  """
  alias __MODULE__
  alias WraftDoc.Validations.Validation
  use WraftDoc.Schema
  import Ecto.Query
  alias WraftDoc.Repo

  @fields [:form_id, :field_id, :order, :machine_name]

  schema "form_field" do
    field(:order, :integer)
    field(:machine_name, :string)
    embeds_many(:validations, Validation, on_replace: :delete)
    belongs_to(:form, WraftDoc.Forms.Form)
    belongs_to(:field, WraftDoc.Fields.Field)

    timestamps()
  end

  def changeset(%FormField{} = form_field, attrs \\ %{}) do
    form_field
    |> cast(attrs, @fields)
    |> cast_embed(:validations, required: true, with: &Validation.changeset/2)
    |> validate_required([:form_id, :field_id, :order])
    |> generate_machine_name()
    |> validate_machine_name()
    |> unique_constraint([:form_id, :field_id],
      name: :form_field_unique_index,
      message: "already exist"
    )
    |> unique_constraint([:machine_name, :form_id],
      name: :form_field_machine_name_form_unique_index,
      message: "Machine name already exists in this form"
    )
    |> unique_constraint(:order,
      message: "Order already exists.!",
      name: :form_field_order_field_id_index
    )
    |> unique_constraint([:form_id, :machine_name],
      name: :form_machine_name_unique_per_form,
      message: "Machine name already exists in this form"
    )
    |> foreign_key_constraint(:form_id, message: "Please enter an existing form")
    |> foreign_key_constraint(:field_id, message: "Please enter a valid field")
  end

  def update_changeset(%FormField{} = form_field, attrs \\ %{}) do
    form_field
    |> cast(attrs, @fields)
    |> cast_embed(:validations, required: true, with: &Validation.changeset/2)
    |> generate_machine_name()
    |> validate_machine_name()
    |> unique_constraint([:machine_name, :form_id],
      name: :form_field_machine_name_form_unique_index,
      message: "Machine name already exists in this form"
    )
  end

  def order_update_changeset(%FormField{} = form_field, attrs \\ %{}) do
    form_field
    |> cast(attrs, [:order])
    |> unique_constraint(:order,
      message: "Order already exists.!",
      name: :form_field_order_field_id_index
    )
  end

  defp generate_machine_name(changeset) do
    case get_change(changeset, :machine_name) do
      nil ->
        field_name = get_field_name_for_machine_name(changeset)

        if field_name do
          base_machine_name = to_machine_name(field_name)
          form_id = get_change(changeset, :form_id) || get_field(changeset, :form_id)
          unique_machine_name = ensure_unique_machine_name(changeset, base_machine_name, form_id)
          put_change(changeset, :machine_name, unique_machine_name)
        else
          changeset
        end

      machine_name ->
        form_id = get_change(changeset, :form_id) || get_field(changeset, :form_id)
        unique_machine_name = ensure_unique_machine_name(changeset, machine_name, form_id)
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

  defp ensure_unique_machine_name(_changeset, base_name, form_id) when is_nil(form_id) do
    base_name
  end

  defp ensure_unique_machine_name(changeset, base_name, form_id) do
    form_field_id = get_field(changeset, :id)

    query =
      from(ff in FormField,
        where: ff.machine_name == ^base_name and ff.form_id == ^form_id
      )

    query =
      if form_field_id do
        where(query, [ff], ff.id != ^form_field_id)
      else
        query
      end

    case Repo.one(query) do
      nil -> base_name
      _ -> find_unique_machine_name(base_name, form_id, form_field_id, 1)
    end
  end

  defp find_unique_machine_name(base_name, form_id, form_field_id, suffix) do
    candidate = "#{base_name}_#{suffix}"

    query =
      from(ff in FormField,
        where: ff.machine_name == ^candidate and ff.form_id == ^form_id
      )

    query =
      if form_field_id do
        where(query, [ff], ff.id != ^form_field_id)
      else
        query
      end

    case Repo.one(query) do
      nil -> candidate
      _ -> find_unique_machine_name(base_name, form_id, form_field_id, suffix + 1)
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
