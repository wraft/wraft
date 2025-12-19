defmodule WraftDoc.Repo.Migrations.UpdateFormMappingMachineNames do
  @moduledoc """
  Updates form_mapping records to include machine_names in source and destination fields.

  This migration runs AFTER populate_machine_names_for_fields to add machine_name
  references to existing form_mapping entries, linking form fields to content type fields.
  """
  use Ecto.Migration

  def up do
    update_form_mapping_machine_names()
  end

  def down do
    # Machine names in mappings are kept even on rollback for consistency
    :ok
  end

  defp update_form_mapping_machine_names do
    query = """
    SELECT fm.id, fm.mapping, fm.form_id, ps.content_type_id
    FROM form_mapping fm
    INNER JOIN pipe_stage ps ON ps.id = fm.pipe_stage_id
    WHERE fm.mapping IS NOT NULL
    """

    {:ok, result} = repo().query(query)

    Enum.each(result.rows, fn [id, mapping, form_id, content_type_id] ->
      updated_mapping =
        Enum.map(mapping, &add_machine_names_to_mapping_entry(&1, form_id, content_type_id))

      save_updated_mapping(id, updated_mapping)
    end)
  end

  defp add_machine_names_to_mapping_entry(entry, form_id, content_type_id) do
    field_id_source = get_source_id(entry)
    field_id_dest = get_destination_id(entry)

    entry
    |> add_source_machine_name(field_id_source, form_id)
    |> add_destination_machine_name(field_id_dest, content_type_id)
  end

  defp add_source_machine_name(entry, field_id, form_id) do
    if should_add_source_machine_name?(entry) && valid_uuid?(field_id) do
      case get_form_field_machine_name_by_field_and_form(field_id, form_id) do
        nil -> entry
        machine_name -> put_in(entry, ["source", "machine_name"], machine_name)
      end
    else
      entry
    end
  end

  defp add_destination_machine_name(entry, field_id, content_type_id) do
    if should_add_destination_machine_name?(entry) && valid_uuid?(field_id) do
      case get_content_type_field_machine_name_by_field_and_type(field_id, content_type_id) do
        nil -> entry
        machine_name -> put_in(entry, ["destination", "machine_name"], machine_name)
      end
    else
      entry
    end
  end

  defp should_add_source_machine_name?(entry) do
    source_id = get_source_id(entry)
    has_source = entry["source"] && source_id
    no_machine_name = !entry["source"]["machine_name"]
    valid_id = has_source && valid_uuid?(source_id)

    has_source && no_machine_name && valid_id
  end

  defp should_add_destination_machine_name?(entry) do
    destination_id = get_destination_id(entry)
    has_destination = entry["destination"] && destination_id
    no_machine_name = !entry["destination"]["machine_name"]
    valid_id = has_destination && valid_uuid?(destination_id)

    has_destination && no_machine_name && valid_id
  end

  defp get_source_id(entry) do
    if entry["source"] do
      entry["source"]["id"] || entry["source"]["source_id"]
    else
      nil
    end
  end

  defp get_destination_id(entry) do
    if entry["destination"] do
      entry["destination"]["id"] || entry["destination"]["destination_id"]
    else
      nil
    end
  end

  defp valid_uuid?(value) when is_binary(value) do
    value != "nil" &&
      String.match?(value, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
  end

  defp valid_uuid?(_), do: false

  defp save_updated_mapping(id, updated_mapping) do
    update_query = """
    UPDATE form_mapping
    SET mapping = $1
    WHERE id = $2
    """

    repo().query!(update_query, [updated_mapping, id])
  end

  defp get_form_field_machine_name_by_field_and_form(field_id, form_id) do
    with {:ok, field_uuid} <- normalize_uuid(field_id),
         {:ok, form_uuid} <- normalize_uuid(form_id) do
      query = """
      SELECT machine_name
      FROM form_field
      WHERE field_id = $1
      AND form_id = $2
      """

      case repo().query(query, [field_uuid, form_uuid]) do
        {:ok, %{rows: [[machine_name]]}} -> machine_name
        _ -> nil
      end
    else
      _ -> nil
    end
  end

  defp get_content_type_field_machine_name_by_field_and_type(field_id, content_type_id) do
    with {:ok, field_uuid} <- normalize_uuid(field_id),
         {:ok, content_type_uuid} <- normalize_uuid(content_type_id) do
      query = """
      SELECT machine_name
      FROM content_type_field
      WHERE field_id = $1
      AND content_type_id = $2
      """

      case repo().query(query, [field_uuid, content_type_uuid]) do
        {:ok, %{rows: [[machine_name]]}} -> machine_name
        _ -> nil
      end
    else
      _ -> nil
    end
  end

  defp normalize_uuid(uuid) when is_binary(uuid) and byte_size(uuid) == 16 do
    {:ok, uuid}
  end

  defp normalize_uuid(uuid) when is_binary(uuid) do
    case Ecto.UUID.dump(uuid) do
      {:ok, binary_uuid} -> {:ok, binary_uuid}
      :error -> :error
    end
  end

  defp normalize_uuid(_), do: :error
end
