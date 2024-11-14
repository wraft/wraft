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
  @document_meta_types ~w(contract document)

  def type, do: :map

  def cast(%{type: type} = meta_data) when type in @document_meta_types do
    type
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
  def cast_meta(changeset, attrs) do
    # Add the document type to the meta
    attrs = %{attrs | meta: Map.put(attrs[:meta], :type, get_field(changeset, :document_type))}
    # Cast the meta data
    changeset = cast(changeset, attrs, [:meta])
    # If the meta data is valid, add it to the changeset
    case get_change(changeset, :meta) do
      %Ecto.Changeset{valid?: true} ->
        %{changeset | changes: Map.put(changeset.changes, :meta, attrs[:meta])}

      %Ecto.Changeset{valid?: false} = meta_changeset ->
        # Merge errors from the nested changeset (meta) into the parent changeset
        changeset = add_error(changeset, :meta, "invalid meta data", meta_changeset.errors)
        # Delete the nested meta changeset from the parent changeset
        %{changeset | changes: Map.delete(changeset.changes, :meta)}

      nil ->
        changeset
    end
  end
end
