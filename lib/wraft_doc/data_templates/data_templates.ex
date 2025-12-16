defmodule WraftDoc.DataTemplates do
  @moduledoc """
  This module provides functions to manage data templates in the system.

  It includes functionality for:
    - Creating data templates
    - Listing data templates by content type and organization
    - Fetching, updating, and deleting data templates
  """

  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.Documents
  alias WraftDoc.Repo
  alias WraftDoc.Utils.CSVHelper

  @doc """
  Create a data template.
  """
  @spec create_data_template(User.t(), ContentType.t(), map) ::
          {:ok, DataTemplate.t()} | {:error, Ecto.Changeset.t()}
  # TODO - imprvove tests
  def create_data_template(%User{id: user_id}, %ContentType{id: c_type_id}, params) do
    params = Map.merge(params, %{"creator_id" => user_id, "content_type_id" => c_type_id})

    %DataTemplate{}
    |> DataTemplate.changeset(params)
    |> Repo.insert()
  end

  def create_data_template(%User{}, _, _), do: {:error, :invalid_id, "ContentType"}
  def create_data_template(_, _, _), do: {:error, :fake}

  @doc """
  List all data templates under a content types.
  """
  @spec data_template_index(binary, map) :: map
  def data_template_index(<<_::288>> = c_type_id, params) do
    DataTemplate
    |> join(:inner, [dt], ct in ContentType,
      on: ct.id == dt.content_type_id and ct.id == ^c_type_id
    )
    |> where(^filter_data_templates_by_title(params))
    |> order_by(^sort_data_templates(params))
    |> preload([:content_type])
    |> Repo.paginate(params)
  end

  @doc """
  List all data templates under current user's organisation.
  """
  @spec data_templates_index_of_an_organisation(User.t(), map) :: map
  def data_templates_index_of_an_organisation(%{current_org_id: org_id}, params) do
    DataTemplate
    |> join(:inner, [dt], ct in ContentType, on: ct.id == dt.content_type_id)
    |> where([dt, ct], ct.organisation_id == ^org_id)
    |> where(^filter_data_templates_by_title(params))
    |> order_by(^sort_data_templates(params))
    |> preload(:content_type)
    |> Repo.paginate(params)
  end

  def data_templates_index_of_an_organisation(_, _), do: {:error, :fake}

  @doc """
  Get a data template from its uuid and organisation ID of user.
  """
  # TODO - imprvove tests
  @spec get_data_template(User.t(), Ecto.UUID.t()) :: DataTemplat.t() | nil
  def get_data_template(%User{current_org_id: org_id}, <<_::288>> = d_temp_id) do
    query =
      from(d in DataTemplate,
        where: d.id == ^d_temp_id,
        join: c in ContentType,
        on: c.id == d.content_type_id and c.organisation_id == ^org_id
      )

    case Repo.one(query) do
      %DataTemplate{} = data_template -> data_template
      _ -> {:error, :invalid_id, "DataTemplate"}
    end
  end

  def get_data_template(%{current_org_id: _}, _), do: {:error, :invalid_id, "DataTemplate"}
  def get_data_template(_, <<_::288>>), do: {:error, :fake}
  def get_data_template(_, _), do: {:error, :fake}

  @doc """
  Show a data template.
  """
  # TODO - imprvove tests
  @spec show_data_template(User.t(), Ecto.UUID.t()) ::
          %DataTemplate{creator: User.t(), content_type: ContentType.t()} | nil
  def show_data_template(user, d_temp_id) do
    with %DataTemplate{} = data_template <- get_data_template(user, d_temp_id) do
      Repo.preload(data_template, [
        :creator,
        [content_type: [{:fields, [:field_type, :content_type_fields]}]]
      ])
    end
  end

  @doc """
  Update a data template
  """
  # TODO - imprvove tests
  @spec update_data_template(DataTemplate.t(), map) ::
          %DataTemplate{creator: User.t(), content_type: ContentType.t()}
          | {:error, Ecto.Changeset.t()}
  def update_data_template(d_temp, params) do
    d_temp
    |> DataTemplate.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, d_temp} ->
        Repo.preload(d_temp, [:creator, [content_type: [{:fields, :field_type}]]])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Creates data templates in bulk from the file given.
  """
  ## TODO - improve tests
  @spec insert_data_template_bulk(User.t(), ContentType.t(), map, String.t()) ::
          [{:ok, DataTemplate.t()}] | {:error, :not_found}
  def insert_data_template_bulk(%User{} = current_user, %ContentType{} = c_type, mapping, path) do
    # TODO Map will be arranged in the ascending order
    # of keys. This causes unexpected changes in decoded CSV
    mapping_keys = Map.keys(mapping)

    path
    |> CSVHelper.decode_csv(mapping_keys)
    |> Stream.map(fn x -> bulk_d_temp_creation(x, current_user, c_type, mapping) end)
    |> Enum.to_list()
  end

  def insert_data_template_bulk(_, _, _, _), do: {:error, :not_found}

  @doc """
  Delete a data template
  """
  # TODO - imprvove tests
  @spec delete_data_template(DataTemplate.t()) :: {:ok, DataTemplate.t()}
  def delete_data_template(d_temp), do: Repo.delete(d_temp)

  @doc """
  Create a background job for data template bulk import.
  """
  @spec insert_data_template_bulk_import_work(binary, binary, map, Plug.Uploap.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, Oban.Job.t()}
  def insert_data_template_bulk_import_work(user_id, c_type_id, mapping \\ %{}, file)

  def insert_data_template_bulk_import_work(
        <<_::288>> = user_id,
        <<_::288>> = c_type_id,
        mapping,
        %Plug.Upload{
          filename: filename,
          path: path
        }
      ) do
    File.mkdir_p("temp/bulk_import_source/d_template")
    dest_path = "temp/bulk_import_source/d_template/#{filename}"
    System.cmd("cp", [path, dest_path])

    data = %{
      user_id: user_id,
      c_type_uuid: c_type_id,
      mapping: mapping,
      file: dest_path
    }

    Documents.create_bulk_job(data, ["data template"])
  end

  def insert_data_template_bulk_import_work(_, <<_::288>>, _mapping, %Plug.Upload{
        filename: _filename,
        path: _path
      }),
      do: {:error, :fake}

  def insert_data_template_bulk_import_work(<<_::288>>, _, _mapping, %Plug.Upload{
        filename: _filename,
        path: _path
      }),
      do: {:error, :invalid_id, "ContentType"}

  def insert_data_template_bulk_import_work(_, _, _, _), do: {:error, :invalid_data}

  @doc """
  Creates a background job for block template bulk import.
  """
  @spec insert_block_template_bulk_import_work(User.t(), map, Plug.Uploap.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, Oban.Job.t()}
  def insert_block_template_bulk_import_work(user, mapping \\ %{}, file)

  def insert_block_template_bulk_import_work(%User{id: user_id}, mapping, %Plug.Upload{
        filename: filename,
        path: path
      }) do
    File.mkdir_p("temp/bulk_import_source/b_template")
    dest_path = "temp/bulk_import_source/b_template/#{filename}"
    System.cmd("cp", [path, dest_path])

    data = %{
      user_id: user_id,
      mapping: mapping,
      file: dest_path
    }

    Documents.create_bulk_job(data, ["block template"])
  end

  # def insert_block_template_bulk_import_work(_, _, %Plug.Upload{filename: _, path: _}),
  #   do: {:error, :fake}

  def insert_block_template_bulk_import_work(_, _, _), do: {:error, :invalid_data}

  @spec bulk_d_temp_creation(map, User.t(), ContentType.t(), map) :: {:ok, DataTemplate.t()}
  defp bulk_d_temp_creation(data, user, c_type, mapping) do
    params = CSVHelper.update_keys(data, mapping)
    create_data_template(user, c_type, params)
  end

  defp filter_data_templates_by_title(%{"title" => title} = _params),
    do: dynamic([dt], ilike(dt.title, ^"%#{title}%"))

  defp filter_data_templates_by_title(_), do: true

  defp sort_data_templates(%{"sort" => "inserted_at"}), do: [asc: dynamic([dt], dt.inserted_at)]

  defp sort_data_templates(%{"sort" => "inserted_at_desc"}),
    do: [desc: dynamic([dt], dt.inserted_at)]

  defp sort_data_templates(%{"sort" => "updated_at"} = _params),
    do: [asc: dynamic([dt], dt.updated_at)]

  defp sort_data_templates(%{"sort" => "updated_at_desc"}),
    do: [desc: dynamic([dt], dt.updated_at)]

  defp sort_data_templates(_), do: []
end
