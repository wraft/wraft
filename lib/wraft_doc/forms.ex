defmodule WraftDoc.Forms do
  @moduledoc """
  Context module for Wraft Forms.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias WraftDoc.Document
  alias WraftDoc.Document.FieldType
  alias WraftDoc.Forms.Form
  alias WraftDoc.Forms.FormField
  alias WraftDoc.Forms.FormPipeline
  alias WraftDoc.Repo

  require Logger

  def create(%{id: user_id, current_org_id: organisation_id}, params) do
    params = Map.merge(params, %{"organisation_id" => organisation_id, "creator_id" => user_id})

    Multi.new()
    |> Multi.insert(:form, Form.changeset(%Form{}, params))
    |> Multi.run(:form_fields, fn _, %{form: form} -> create_form_fields(form, params) end)
    |> Multi.run(:form_pipelines, fn _, %{form: form} -> create_form_pipelines(form, params) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{form: form}} ->
        Repo.preload(form, [:pipelines, [form_fields: [{:field, :field_type}]]])

      {:error, _, error, _} ->
        {:error, error}
    end
  end

  defp create_form_fields(form, %{"fields" => fields} = _params) do
    # TODO May be add a feedback loop to inform if some fields are not created
    {:ok, fields |> Stream.map(&create_form_field(form, &1)) |> Enum.to_list()}
  end

  defp create_form_field(form, %{"field_type_id" => field_type_id} = params) do
    field_type_id
    |> Document.get_field_type()
    |> case do
      %FieldType{meta: %{"allowed validations" => allowed_validations}} = field_type ->
        params =
          params
          |> Map.put("organisation_id", form.organisation_id)
          |> Map.put("validations", reject_unallowed_validations(params, allowed_validations))

        create_form_field(form, field_type, params)

      _ ->
        nil
    end
  end

  defp create_form_field(form, field_type, params) do
    Multi.new()
    |> Multi.run(:field, fn _, _ -> Document.create_field(field_type, params) end)
    |> Multi.insert(:form_field, fn %{field: field} ->
      FormField.changeset(%FormField{}, %{
        form_id: form.id,
        field_id: field.id,
        validations: params["validations"]
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

  defp reject_unallowed_validations(params, allowed_validations),
    do: Enum.reject(params["validations"], &(&1["validation"]["rule"] not in allowed_validations))

  defp create_form_pipelines(form, %{"pipeline_ids" => pipeline_ids}) do
    # TODO May be add a feedback loop to inform if some fields are not created
    {:ok, Enum.each(pipeline_ids, &create_form_pipeline(form, &1))}
  end

  defp create_form_pipelines(_, _), do: {:ok, "ok"}

  defp create_form_pipeline(form, pipeline_id) do
    %FormPipeline{}
    |> FormPipeline.changeset(%{
      form_id: form.id,
      pipeline_id: pipeline_id,
      organisation_id: form.organisation_id
    })
    |> Repo.insert()
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
end
