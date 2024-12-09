defmodule WraftDoc.EctoType.DocumentMetaType do
  @moduledoc """
   A generic Ecto type for polymorphic metadata that can handle different schemas.
  The type will be parameterized by the schema and fields to allow for flexible usage.
  """
  use Ecto.Type
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Document.Instance

  # List of supported document types
  @document_meta_types ~w(contract document)a

  def type, do: :map

  def cast(%{"type" => type} = meta_data) when type in @document_meta_types do
    type
    |> to_string()
    |> document_module()
    |> then(&{:ok, &1.changeset(struct(&1), meta_data)})
  end

  def cast(_), do: :error

  def load(meta_data) do
    {:ok, meta_data}
  end

  def dump(meta_data) do
    {:ok, meta_data}
  end

  # Get the module based on the type
  defp document_module(type), do: Module.concat(Instance, :"#{Macro.camelize(type)}Meta")

  # Add meta data to the changeset
  def cast_meta(changeset, %{"meta" => meta} = attrs) when is_map(meta) do
    attrs =
      update_in(attrs["meta"], &Map.put_new(&1, "type", get_field(changeset, :document_type)))

    changeset
    |> cast(attrs, [:meta])
    |> validate_meta_changes()
  end

  def cast_meta(changeset, attrs) when is_map(attrs) do
    cast_meta(
      changeset,
      Map.put(attrs, "meta", %{"type" => get_field(changeset, :document_type)})
    )
  end

  def cast_meta(changeset, _), do: changeset

  defp validate_meta_changes(changeset) do
    case get_change(changeset, :meta) do
      %Ecto.Changeset{valid?: true, changes: changes} ->
        put_change(changeset, :meta, changes)

      %Ecto.Changeset{valid?: false, errors: errors} ->
        changeset
        |> add_error(:meta, inspect(errors))
        |> delete_change(:meta)

      nil ->
        changeset
    end
  end
end
