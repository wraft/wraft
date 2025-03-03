defmodule WraftDoc.CollectionForms do
  @moduledoc """
    The collection forms context.
  """
  import Ecto.Query

  alias WraftDoc.CollectionForms.CollectionForm
  alias WraftDoc.CollectionForms.CollectionFormField
  alias WraftDoc.Repo

  @doc """
  Return collection form by user and collection form id
  ## Parameters
  * User - user struct
  * id - Collection form field
  """
  def get_collection_form(%{current_org_id: org_id}, <<_::288>> = id) do
    case Repo.get_by(CollectionForm, id: id, organisation_id: org_id) do
      %CollectionForm{} = collection_form ->
        collection_form

      _ ->
        {:error, :invalid_id, "CollectionForm"}
    end
  end

  def get_collection_form(_, _), do: {:error, :invalid_id, "CollectionForm"}

  def create_collection_form(%{id: usr_id, current_org_id: org_id}, params) do
    params = Map.merge(params, %{"creator_id" => usr_id, "organisation_id" => org_id})

    %CollectionForm{}
    |> CollectionForm.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, %CollectionForm{} = collection_form} ->
        Repo.preload(collection_form, [:fields, :creator])

      changeset = {:error, _} ->
        changeset
    end
  end

  # defp create_form_fields(collection_form, fields) do
  #   Enum.each(fields, fn x -> create_collection_form_field(collection_form.id, x) end)
  # end

  def update_collection_form(collection_form, params) do
    collection_form
    |> Repo.preload(:fields)
    |> CollectionForm.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, collection_form} ->
        Repo.preload(collection_form, [:creator, :fields])
    end
  end

  def delete_collection_form(%CollectionForm{} = collection_form) do
    Repo.delete(collection_form)
  end

  def list_collection_form(%{current_org_id: org_id}, params) do
    query = from(c in CollectionForm, preload: [:fields], where: c.organisation_id == ^org_id)
    Repo.paginate(query, params)
  end

  def get_collection_form_field(%{current_org_id: org_id}, id) do
    query =
      from(cff in CollectionFormField,
        join: cf in CollectionForm,
        on: cff.collection_form_id == cf.id,
        where: cff.id == ^id and cf.organisation_id == ^org_id
      )

    case Repo.one(query) do
      %CollectionFormField{} = collection_form_field ->
        collection_form_field

      _ ->
        {:error, :invalid_id, "CollectionFormField"}
    end
  end

  def get_collection_form_field(_, _), do: {:error, :fake}

  def create_collection_form_field(c_form_id, params) do
    params = Map.put(params, "collection_form_id", c_form_id)

    %CollectionFormField{}
    |> CollectionFormField.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, %CollectionFormField{} = collection_form} ->
        collection_form

      changeset = {:error, _} ->
        changeset
    end
  end

  def update_collection_form_field(collection_form_field, params) do
    collection_form_field
    |> CollectionFormField.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, collection_form} ->
        collection_form
    end
  end

  def delete_collection_form_field(%CollectionFormField{} = collection_form_field) do
    Repo.delete(collection_form_field)
  end
end
