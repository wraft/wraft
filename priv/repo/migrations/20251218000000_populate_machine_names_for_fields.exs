defmodule WraftDoc.Repo.Migrations.PopulateMachineNamesForFields do
  @moduledoc """
  Populates machine_name field for existing form_field and content_type_field records.

  This migration ensures all existing fields have valid machine names that follow
  the format: lowercase, alphanumeric with underscores, unique within their parent form/content type.
  """
  use Ecto.Migration

  def up do
    populate_form_field_machine_names()
    populate_content_type_field_machine_names()
  end

  def down do
    # Machine names are intentionally kept even on rollback
    # They are included in API responses and clearing them would break API consumers
    :ok
  end

  defp populate_form_field_machine_names do
    query = """
    SELECT ff.id, ff.form_id, f.name as field_name
    FROM form_field ff
    INNER JOIN field f ON f.id = ff.field_id
    WHERE ff.machine_name IS NULL
    ORDER BY ff.form_id, ff.id
    """

    {:ok, result} = repo().query(query)

    Enum.reduce(result.rows, %{}, fn [id, form_id, field_name], acc ->
      base_machine_name = to_machine_name(field_name)
      used_names = Map.get(acc, form_id, MapSet.new())
      unique_machine_name = ensure_unique_name(base_machine_name, used_names)

      update_query = """
      UPDATE form_field
      SET machine_name = $1
      WHERE id = $2
      """

      repo().query!(update_query, [unique_machine_name, id])

      Map.put(acc, form_id, MapSet.put(used_names, unique_machine_name))
    end)
  end

  defp populate_content_type_field_machine_names do
    query = """
    SELECT ctf.id, ctf.content_type_id, f.name as field_name
    FROM content_type_field ctf
    INNER JOIN field f ON f.id = ctf.field_id
    WHERE ctf.machine_name IS NULL
    ORDER BY ctf.content_type_id, ctf.id
    """

    {:ok, result} = repo().query(query)

    Enum.reduce(result.rows, %{}, fn [id, content_type_id, field_name], acc ->
      base_machine_name = to_machine_name(field_name)
      used_names = Map.get(acc, content_type_id, MapSet.new())
      unique_machine_name = ensure_unique_name(base_machine_name, used_names)

      update_query = """
      UPDATE content_type_field
      SET machine_name = $1
      WHERE id = $2
      """

      repo().query!(update_query, [unique_machine_name, id])

      Map.put(acc, content_type_id, MapSet.put(used_names, unique_machine_name))
    end)
  end

  defp to_machine_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.replace(~r/\s+/, "_")
    |> String.trim()
    |> case do
      "" -> "field"
      machine_name -> machine_name
    end
  end

  defp to_machine_name(_), do: "field"

  defp ensure_unique_name(base_name, used_names, suffix \\ nil) do
    candidate = if suffix, do: "#{base_name}_#{suffix}", else: base_name

    if MapSet.member?(used_names, candidate) do
      next_suffix = if suffix, do: suffix + 1, else: 1
      ensure_unique_name(base_name, used_names, next_suffix)
    else
      candidate
    end
  end
end
