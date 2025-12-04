defmodule WraftDoc.Forms do
  @moduledoc """
  Context module for Wraft Forms.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias WraftDoc.Account.User
  alias WraftDoc.Fields
  alias WraftDoc.Fields.Field
  alias WraftDoc.Fields.FieldType
  alias WraftDoc.Forms.Form
  alias WraftDoc.Forms.FormEntry
  alias WraftDoc.Forms.FormField
  alias WraftDoc.Forms.FormMapping
  alias WraftDoc.Forms.FormPipeline
  alias WraftDoc.Pipelines
  alias WraftDoc.Pipelines.TriggerHistories
  alias WraftDoc.Repo
  alias WraftDoc.Validations.Validator

  require Logger

  @doc """
  Create a form
  """
  @spec create(User.t(), map) :: Form.t() | {:error, Ecto.Changeset.t()}
  def create(%{id: user_id, current_org_id: organisation_id}, params) do
    params =
      params
      |> Map.put("fields", form_field_ordering(params))
      |> Map.merge(%{"organisation_id" => organisation_id, "creator_id" => user_id})

    Multi.new()
    |> Multi.insert(:form, Form.changeset(%Form{}, params))
    |> Multi.run(:form_fields, fn _, %{form: form} ->
      create_or_update_form_fields(form, params)
    end)
    |> Multi.run(:form_pipelines, fn _, %{form: form} -> create_form_pipelines(form, params) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{form: form}} ->
        Repo.preload(form, [:pipelines, [form_fields: [{:field, :field_type}]]])

      {:error, _, error, _} ->
        {:error, error}
    end
  end

  @doc """
    Show a form
  """
  @spec show_form(User.t(), Ecto.UUID.t()) :: Form.t() | nil
  def show_form(%{current_org_id: organisation_id}, <<_::288>> = form_id) do
    %{current_org_id: organisation_id}
    |> get_form(form_id)
    |> Repo.preload([:pipelines, [form_fields: [{:field, :field_type}]]])
  end

  @doc """
  Get a form
  """
  @spec get_form(User.t(), Ecto.UUID.t()) :: Form.t() | nil
  def get_form(%{current_org_id: organisation_id}, <<_::288>> = form_id) do
    Repo.get_by(Form, id: form_id, organisation_id: organisation_id)
  end

  def get_form(_, _), do: nil

  @doc """
  Delete a form
  """
  @spec delete_form(Form.t()) ::
          {:ok, Form.t()} | {:error, Ecto.Changeset.t()} | {:error, String.t()}
  def delete_form(%Form{pipelines: [], form_pipelines: []} = form) do
    Multi.new()
    |> Multi.delete_all(:form_fields, from(ff in FormField, where: ff.form_id == ^form.id))
    |> Multi.delete_all(:form_mappings, from(fm in FormMapping, where: fm.form_id == ^form.id))
    |> Multi.delete(:form, form)
    |> Repo.transaction()
    |> case do
      {:ok, %{form: form}} ->
        form

      {:error, _, error, _} ->
        {:error, error}
    end
  end

  def delete_form(%Form{pipelines: _pipelines, form_pipelines: _form_pipelines}),
    do: {:error, "Form has pipelines"}

  @doc """
    Update form status
  """
  @spec update_status(Form.t(), map()) :: Form.t() | {:error, Ecto.Changeset.t()}
  def update_status(form, params) do
    form
    |> Form.update_changeset(params)
    |> Repo.update()
  end

  @doc """
  Update a form
  """
  def update_form(form, params) do
    Multi.new()
    |> Multi.update(:form, Form.changeset(form, params))
    |> Multi.run(:removed_fields, fn _, %{form: form} -> remove_form_fields(form, params) end)
    |> Multi.run(:form_fields, fn _, %{form: form, removed_fields: fields} ->
      create_or_update_form_fields(form, %{
        "fields" => form_field_ordering(%{"fields" => fields})
      })
    end)
    |> Multi.run(:form_pipelines, fn _, %{form: form} -> update_form_pipelines(form, params) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{form: form}} ->
        Repo.preload(form, [:pipelines, [form_fields: [{:field, :field_type}]]])

      {:error, _, error, _} ->
        {:error, error}
    end
  end

  # Private
  defp form_field_ordering(%{"fields" => form_fields} = _params) do
    form_fields
    |> Enum.with_index(1)
    |> Enum.map(fn {form_field, index} -> Map.put(form_field, "order", index) end)
  end

  @doc """
    Get Form Field
  """
  @spec get_form_field(Form.t(), Field.t()) :: FormField.t() | nil
  def get_form_field(form, field) do
    case Repo.get_by(FormField, form_id: form.id, field_id: field.id) do
      %FormField{} = form_field ->
        form_field

      nil ->
        nil
    end
  end

  defp remove_form_fields(form, %{"fields" => fields} = params) do
    Enum.each(fields, fn field ->
      if should_delete_field?(field) do
        delete_form_field_if_exists(form, field["field_id"])
      end
    end)

    {:ok, Enum.filter(params["fields"], fn field -> map_size(field) != 1 end)}
  end

  defp should_delete_field?(field) do
    Map.has_key?(field, "field_id") && map_size(field) == 1
  end

  defp delete_form_field_if_exists(form, field_id) do
    case Repo.get_by(FormField, field_id: field_id, form_id: form.id) do
      %FormField{} = form_field ->
        Repo.delete(form_field)
        on_delete_form_field_order(form, form_field.order)

      nil ->
        nil
    end
  end

  # Private
  defp on_delete_form_field_order(form, order) do
    query = from(ff in FormField, where: ff.form_id == ^form.id and ff.order > ^order)
    Repo.update_all(query, inc: [order: -1])
  end

  defp create_or_update_form_fields(form, %{"fields" => fields} = _params) do
    # TODO May be add a feedback loop to inform if some fields are not created
    {:ok, fields |> Stream.map(&create_form_field(form, &1)) |> Enum.to_list()}
  end

  defp create_form_field(form, %{"field_type_id" => field_type_id} = params) do
    field_type_id
    |> Fields.get_field_type()
    |> case do
      %FieldType{meta: %{"allowed validations" => allowed_validations}} = field_type ->
        params =
          params
          |> Map.put("organisation_id", form.organisation_id)
          |> Map.put("validations", reject_unallowed_validations(params, allowed_validations))

        case Map.has_key?(params, "field_id") && Fields.get_field(params["field_id"]) do
          %Field{} = field -> update_form_field(form, field, params)
          false -> create_form_field(form, field_type, params)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp create_form_field(form, field_type, params) do
    Multi.new()
    |> Multi.run(:field, fn _, _ -> Fields.create_field(field_type, params) end)
    |> Multi.insert(:form_field, fn %{field: field} ->
      form_field = %FormField{field: field}

      FormField.changeset(form_field, %{
        order: params["order"],
        form_id: form.id,
        field_id: field.id,
        validations: params["validations"],
        machine_name: params["machine_name"]
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, step, error, _} ->
        Logger.error("Form field creation failed in step #{inspect(step)}", error: error)
        :error
    end
  end

  defp update_form_field(form, field, params) do
    case get_form_field(form, field) do
      %FormField{} = form_field ->
        update_existing_form_field(form_field, field, params)

      error ->
        error
    end
  end

  defp update_existing_form_field(form_field, field, params) do
    form_field = Repo.preload(form_field, :field)

    Multi.new()
    |> Multi.run(:field, fn _, _ -> Fields.update_field(field, params) end)
    |> Multi.update(:form_field, fn %{field: updated_field} ->
      field_for_machine_name = extract_field_for_machine_name(updated_field, form_field, field)

      form_field_with_field = %{form_field | field: field_for_machine_name}

      FormField.update_changeset(form_field_with_field, %{
        validations: params["validations"],
        order: params["order"],
        machine_name: params["machine_name"]
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, step, error, _} ->
        Logger.error("Form field update failed in step #{inspect(step)}", error: error)
        :error
    end
  end

  defp extract_field_for_machine_name(updated_field, form_field, field) do
    case updated_field do
      {:ok, f} -> f
      {:error, _} -> form_field.field || field
      f -> f
    end
  end

  defp reject_unallowed_validations(params, allowed_validations),
    do: Enum.reject(params["validations"], &(&1["validation"]["rule"] not in allowed_validations))

  defp create_form_pipelines(form, %{"pipeline_ids" => pipeline_ids}) do
    # TODO May be add a feedback loop to inform if some fields are not created
    {:ok, Enum.each(pipeline_ids, &create_form_pipeline(form, &1))}
  end

  defp create_form_pipelines(_, _), do: {:ok, "ok"}

  defp update_form_pipelines(form, %{"pipeline_ids" => pipeline_ids}) do
    form = Repo.preload(form, :form_pipelines)
    existing_pipeline_ids = form |> Map.get(:form_pipelines) |> Enum.map(& &1.pipeline_id)
    pipeline_ids_to_be_added_to_form = pipeline_ids -- existing_pipeline_ids
    pipeline_ids_to_be_removed_from_form = existing_pipeline_ids -- pipeline_ids

    form_pipeline_ids =
      Enum.filter(form.form_pipelines, &(&1.pipeline_id in pipeline_ids_to_be_removed_from_form))

    Enum.each(form_pipeline_ids, &Repo.delete(&1))

    {:ok, Enum.each(pipeline_ids_to_be_added_to_form, &create_form_pipeline(form, &1))}
  end

  defp update_form_pipelines(_, _), do: {:ok, "ok"}

  @spec create_form_pipeline(Form.t(), Ecto.UUID.t()) ::
          {:ok, FormPipeline.t()} | {:error, Ecto.Changeset.t()}
  def create_form_pipeline(form, pipeline_id) do
    %FormPipeline{}
    |> FormPipeline.changeset(%{
      form_id: form.id,
      pipeline_id: pipeline_id,
      organisation_id: form.organisation_id
    })
    |> Repo.insert()
  end

  @doc """
  Get a form pipeline
  """
  @spec get_form_pipeline(Form.t(), Ecto.UUID.t()) :: FormPipeline.t() | nil
  def get_form_pipeline(form, <<_::288>> = pipeline_id) do
    Repo.get_by(FormPipeline, form_id: form.id, pipeline_id: pipeline_id)
  end

  @doc """
  Delete a form pipeline
  """
  @spec delete_form_pipeline(Pipeline.t()) ::
          {:ok, FormPipeline.t()} | {non_neg_integer(), nil}
  def delete_form_pipeline(pipeline) do
    query = from(fp in FormPipeline, where: fp.pipeline_id == ^pipeline.id)
    Repo.delete_all(query)
  end

  @doc """
  List of all forms in the user's organisation
  """
  @spec form_index(User.t(), map) :: map
  def form_index(%{current_org_id: org_id}, params) do
    Form
    |> where([f], f.organisation_id == ^org_id)
    |> where(^form_filter_by_name(params))
    |> order_by([f], ^form_sort(params))
    |> Repo.paginate(params)
  end

  defp form_filter_by_name(%{"name" => name} = _params),
    do: dynamic([f], ilike(f.name, ^"%#{name}%"))

  defp form_filter_by_name(_), do: true

  defp form_sort(%{"sort" => "name_desc"} = _params), do: [desc: dynamic([f], f.name)]

  defp form_sort(%{"sort" => "name"} = _params), do: [asc: dynamic([f], f.name)]

  defp form_sort(%{"sort" => "inserted_at"}), do: [asc: dynamic([f], f.inserted_at)]

  defp form_sort(%{"sort" => "inserted_at_desc"}),
    do: [desc: dynamic([f], f.inserted_at)]

  defp form_sort(_), do: []

  @doc """
    Show form entry
  """
  @spec show_form_entry(User.t(), map) :: FormEntry.t() | nil
  def show_form_entry(
        %{current_org_id: organisation_id},
        %{"form_id" => form_id, "id" => form_entry_id} = _params
      ) do
    FormEntry
    |> join(:inner, [fe], f in Form,
      on: fe.form_id == f.id and f.organisation_id == ^organisation_id
    )
    |> where([fe], fe.form_id == ^form_id and fe.id == ^form_entry_id)
    |> Repo.one()
  end

  def show_form_entry(_, _), do: nil

  @doc """
    Create form entry
  """
  @spec create_form_entry(User.t(), Form.t(), map) ::
          {:ok, FormEntry.t()} | {:error, list(map)} | {:error, Ecto.Changeset.t()}
  def create_form_entry(
        current_user,
        %Form{form_fields: fields} = form,
        %{"data" => data} = _params
      ) do
    data_map =
      Enum.reduce(data, %{}, fn %{"field_id" => field_id, "value" => value}, acc ->
        Map.put(acc, field_id, value)
      end)

    if check_data_mapping(fields, data) do
      case validate_form_entry(fields, data_map) do
        [] -> insert_form_entry(current_user, form, data_map)
        error_list -> {:error, error_list}
      end
    else
      {:error, :invalid_data}
    end
  end

  defp insert_form_entry(user, form, data_map) do
    %FormEntry{}
    |> FormEntry.changeset(%{
      form_id: form.id,
      status: "draft",
      user_id: user.id,
      data: data_map
    })
    |> Repo.insert()
  end

  # Validate form entry data
  defp validate_form_entry(fields, data_map) do
    fields
    |> Enum.flat_map(fn field -> validate(field, data_map) end)
    |> Enum.reject(&is_nil/1)
  end

  defp validate(field, data_map) do
    Enum.map(field.validations, fn validation ->
      validate_single_field(validation, field, data_map)
    end)
  end

  defp validate_single_field(validation, field, data_map) do
    validator_module = Module.concat(Validator, Macro.camelize(validation.validation["rule"]))

    field_value =
      Map.get(data_map, field.machine_name)

    case validator_module.validate(validation, field_value) do
      {:error, error} ->
        Logger.error("Validation failed for field #{field.id}", error: error)
        %{field_id: field.field_id, error: error}

      _ ->
        nil
    end
  end

  defp check_data_mapping(fields, data) do
    form_field_ids = fields |> Enum.map(& &1.field_id) |> Enum.sort()
    data_field_ids = data |> Enum.map(& &1["field_id"]) |> Enum.sort()

    form_field_ids == data_field_ids
  end

  @doc """
    List of all form entries for the given form.
  """
  @spec form_entry_index(User.t(), map) :: map
  def form_entry_index(
        %{current_org_id: org_id},
        %{"form_id" => form_id} = params
      ) do
    FormEntry
    |> join(:inner, [fe], f in Form, on: fe.form_id == f.id and f.organisation_id == ^org_id)
    |> where([fe], fe.form_id == ^form_id)
    |> order_by(^form_entry_index_sort(params))
    |> Repo.paginate(params)
  end

  def form_entry_index(_, _), do: {:error, :invalid_id}

  defp form_entry_index_sort(%{"sort" => "inserted_at"}), do: [asc: dynamic([i], i.inserted_at)]

  defp form_entry_index_sort(%{"sort" => "inserted_at_desc"}),
    do: [desc: dynamic([i], i.inserted_at)]

  defp form_entry_index_sort(_), do: []

  @doc """
    Create form mapping
  """
  @spec create_form_mapping(map) :: {:ok, Form.t()} | {:error, Ecto.Changeset.t()}
  def create_form_mapping(params) do
    %FormMapping{}
    |> FormMapping.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Get form mapping
  """
  @spec get_form_mapping(User.t(), map()) :: FormMapping.t() | nil
  def get_form_mapping(
        %User{current_org_id: org_id},
        %{"mapping_id" => mapping_id, "form_id" => form_id} = _params
      ) do
    FormMapping
    |> join(:inner, [fp], f in Form, on: f.id == fp.form_id and f.organisation_id == ^org_id)
    |> where([fp], fp.id == ^mapping_id and fp.form_id == ^form_id)
    |> Repo.one()
  end

  def get_form_mapping(_, _), do: nil

  @doc """
    Update form mapping
  """
  @spec update_form_mapping(FormMapping.t(), map) ::
          {:ok, FormMapping.t()} | {:error, Ecto.Changeset.t()}
  def update_form_mapping(form_mapping, params) do
    form_mapping
    |> FormMapping.update_changeset(params)
    |> Repo.update()
  end

  @doc """
    Trigger form pipelines
  """
  @spec trigger_pipelines(User.t(), Form.t(), FormEntry.t()) :: :ok
  def trigger_pipelines(
        %User{} = current_user,
        %Form{pipelines: pipelines} = _form,
        %FormEntry{data: data} = _form_entry
      ) do
    pipelines
    |> Enum.with_index()
    |> Enum.each(fn {pipeline, index} ->
      trigger_pipeline(current_user, pipeline.id, data, index)
    end)
  end

  @doc """
    Trigger pipeline
  """
  @spec trigger_pipeline(User.t(), Ecto.UUID.t(), map(), integer()) :: :ok | {:error, String.t()}
  def trigger_pipeline(current_user, pipeline_id, data, scheduled_at_offset) do
    Multi.new()
    |> Multi.run(:pipeline, fn _, _ ->
      {:ok, Pipelines.get_pipeline(current_user, pipeline_id)}
    end)
    |> Multi.run(:trigger_history, fn _, %{pipeline: pipeline} ->
      TriggerHistories.create_trigger_history(current_user, pipeline, data)
    end)
    |> Multi.run(:pipeline_job, fn _, %{trigger_history: trigger_history} ->
      TriggerHistories.create_pipeline_job(
        current_user,
        trigger_history,
        DateTime.add(DateTime.utc_now(), scheduled_at_offset, :second)
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{trigger_history: trigger_history}} ->
        {:ok, %{pipeline_id: pipeline_id, trigger_id: trigger_history.id}}

      {:error, step, error, _} ->
        Logger.error("Pipeline failed in step #{inspect(step)}", error: error)
        {:error, "Pipeline failed"}
    end
  end

  @doc """
    Transform form entry data fields by form mapping
  """
  @spec transform_data_by_mapping(FormMapping.t(), map()) :: map() | {:error, String.t()}
  def transform_data_by_mapping(
        %FormMapping{mapping: mappings, form_id: form_id} = _form_mapping,
        data
      ) do
    mappings
    |> transform_mappings
    |> transform_data(data, form_id)
    |> Enum.into(%{})
  end

  def transform_data_by_mapping(nil, _data), do: {:error, "No mappings found"}

  defp transform_data(mappings, data, form_id) do
    # Convert form data with field_id => value to machine_name (or name) => value
    # Look up form_fields to get machine_name
    form_data =
      data
      |> Enum.map(fn {field_id, value} ->
        form_field =
          Repo.one(
            from(ff in FormField,
              where: ff.form_id == ^form_id and ff.field_id == ^field_id,
              preload: [:field]
            )
          )

        field_identifier =
          case form_field do
            %{machine_name: machine_name} when not is_nil(machine_name) ->
              machine_name

            %{field: %{name: name}} ->
              name

            _ ->
              field = Repo.get(Field, field_id)
              (field && field.name) || "field_#{field_id}"
          end

        {field_identifier, value}
      end)
      |> Map.new()

    Enum.flat_map(mappings, fn {content_type_field_name, form_field_name} ->
      case Map.get(form_data, form_field_name) do
        nil -> []
        value -> [{content_type_field_name, value}]
      end
    end)
  end

  defp transform_mappings(mappings) do
    Enum.reduce(mappings, %{}, fn mapping, acc ->
      destination_name = mapping.destination["name"]
      source_name = mapping.source["name"]
      Map.put(acc, destination_name, source_name)
    end)
  end

  @doc """
    Align form fields
  """
  @spec align_fields(Form.t(), map) :: Form.t() | Ecto.Changeset.t()
  def align_fields(%Form{form_fields: form_fields} = form, %{"fields" => fields} = _params) do
    form
    |> Ecto.Changeset.change(form_fields: update_form_fields_order(form_fields, fields))
    |> Repo.update()
    |> case do
      {:ok, form} -> form
      {:error, _} = changeset -> changeset
    end
  end

  # Private
  defp update_form_fields_order(form_fields, fields) do
    Enum.map(form_fields, fn %FormField{field_id: field_id} = form_field ->
      FormField.order_update_changeset(
        form_field,
        %{order: Map.get(fields, field_id)}
      )
    end)
  end
end
