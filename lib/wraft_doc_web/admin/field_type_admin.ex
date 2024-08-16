defmodule WraftDocWeb.FieldTypeAdmin do
  @moduledoc """
  Admin panel management for the FieldType module.
  """
  import Ecto.Query
  alias WraftDoc.Document.FieldType

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      description: %{name: "Description", value: fn x -> x.description end},
      meta: %{name: "Meta", value: fn x -> Jason.encode!(x.meta) end},
      is_disabled: %{name: "Disabled", value: fn x -> x.is_disabled end},
      inserted_at: %{name: "Created At", value: fn x -> x.inserted_at end},
      updated_at: %{name: "Updated At", value: fn x -> x.updated_at end}
    ]
  end

  def custom_index_query(_conn, _schema, query) do
    from(q in query, preload: [:creator])
  end

  def update_changeset(entry, attrs) do
    parsed_attrs = parse_validations(attrs)
    FieldType.changeset(entry, parsed_attrs)
  end

  def create_changeset(entry, attrs) do
    parsed_attrs = parse_validations(attrs)
    FieldType.changeset(entry, parsed_attrs)
  end

  defp parse_validations(attrs) do
    case Map.get(attrs, "validations") do
      nil -> attrs
      validations_str when is_binary(validations_str) ->
        case Jason.decode(validations_str) do
          {:ok, parsed_validations} -> Map.put(attrs, "validations", parsed_validations)
          {:error, _} ->
            attrs
        end
      _ -> attrs
    end
  end

  def ordering(_) do
    [asc: :inserted_at]
  end
end
