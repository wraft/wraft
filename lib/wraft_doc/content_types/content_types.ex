defmodule WraftDoc.ContentTypes do
  @moduledoc "
  Module that handles the repo connections of the document context.
  "
  import Ecto
  import Ecto.Query
  require Logger

  alias Ecto.Multi
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.User
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.ContentTypes.ContentTypeField
  alias WraftDoc.ContentTypes.ContentTypeRole
  alias WraftDoc.Documents
  alias WraftDoc.Documents.FieldType
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Layouts
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Repo

  @doc """
  Create a content type.
  """
  # TODO - improve tests
  @spec create_content_type(User.t(), map) :: ContentType.t() | {:error, Ecto.Changeset.t()}
  def create_content_type(%{current_org_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:content_types)
    |> ContentType.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, %ContentType{} = content_type} ->
        fetch_and_associate_fields(content_type, params)

        Repo.preload(content_type, [
          :creator,
          :layout,
          :flow,
          {:theme, :assets},
          {:fields, :field_type},
          creator: [:profile]
        ])

      changeset = {:error, _} ->
        changeset
    end
  end

  @spec fetch_and_associate_fields(ContentType.t(), map) :: list
  # Iterate throught the list of field types and associate with the content type
  defp fetch_and_associate_fields(content_type, %{"fields" => fields}) do
    fields
    |> Stream.map(fn x -> create_field_for_content_type(content_type, x) end)
    |> Enum.to_list()
  end

  defp fetch_and_associate_fields(_content_type, _params), do: nil

  @spec create_field_for_content_type(ContentType.t(), map) ::
          {:ok, ContentTypeField.t()} | {:error, Ecto.Changeset.t()} | nil
  defp create_field_for_content_type(
         content_type,
         %{"field_type_id" => field_type_id} = params
       ) do
    field_type_id
    |> Documents.get_field_type()
    |> case do
      %FieldType{} = field_type ->
        create_content_type_field(field_type, content_type, params)

      _ ->
        nil
    end
  end

  defp create_field_for_content_type(_content_type, _field), do: nil

  defp create_content_type_field(field_type, content_type, params) do
    params = Map.merge(params, %{"organisation_id" => content_type.organisation_id})

    Multi.new()
    |> Multi.run(:field, fn _, _ -> Documents.create_field(field_type, params) end)
    |> Multi.insert(:content_type_field, fn %{field: field} ->
      ContentTypeField.changeset(%ContentTypeField{}, %{
        content_type_id: content_type.id,
        field_id: field.id
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, step, error, _} ->
        Logger.error("Content type field creation failed in step #{inspect(step)}", error: error)
        :error
    end
  end

  @doc """
  List all content types.
  """
  @spec content_type_index(User.t(), map) :: map
  def content_type_index(%{current_org_id: org_id}, params) do
    ContentType
    |> where([ct], ct.organisation_id == ^org_id)
    |> where(^content_type_filter_by_name(params))
    |> where(^content_type_filter_by_prefix(params))
    |> order_by([ct], ^content_type_sort(params))
    |> preload([:layout, :flow, {:theme, :assets}, {:fields, :field_type}, creator: [:profile]])
    |> Repo.paginate(params)
  end

  defp content_type_filter_by_name(%{"name" => name} = _params),
    do: dynamic([ct], ilike(ct.name, ^"%#{name}%"))

  defp content_type_filter_by_name(_), do: true

  defp content_type_filter_by_prefix(%{"prefix" => prefix} = _params),
    do: dynamic([ct], ilike(ct.prefix, ^"%#{prefix}%"))

  defp content_type_filter_by_prefix(_), do: true

  defp content_type_sort(%{"sort" => "name_desc"} = _params), do: [desc: dynamic([ct], ct.name)]

  defp content_type_sort(%{"sort" => "name"} = _params), do: [asc: dynamic([ct], ct.name)]

  defp content_type_sort(%{"sort" => "inserted_at"}), do: [asc: dynamic([ct], ct.inserted_at)]

  defp content_type_sort(%{"sort" => "inserted_at_desc"}),
    do: [desc: dynamic([ct], ct.inserted_at)]

  defp content_type_sort(_), do: []

  @doc """
  Show a content type.
  """
  # TODO - improve tests
  @spec show_content_type(User.t(), Ecto.UUID.t()) ::
          %ContentType{layout: Layout.t(), creator: User.t()} | nil
  def show_content_type(user, id) do
    with %ContentType{} = content_type <- get_content_type(user, id) do
      Repo.preload(content_type, [
        :layout,
        :creator,
        {:theme, :assets},
        [{:fields, :field_type}, {:flow, :states}]
      ])
    end
  end

  @doc """
  Get a content type from its UUID and user's organisation ID.
  """
  @spec get_content_type(User.t(), Ecto.UUID.t()) ::
          ContentType.t() | {:error, :invalid_id, String.t()}
  def get_content_type(%User{current_org_id: org_id}, <<_::288>> = id) do
    ContentType
    |> Repo.get_by(id: id, organisation_id: org_id)
    |> case do
      %ContentType{} = content_type ->
        Repo.preload(content_type, [
          :layout,
          :creator,
          {:theme, :assets},
          [{:flow, :states}, {:fields, :field_type}]
        ])

      _ ->
        {:error, :invalid_id, "ContentType"}
    end
  end

  def get_content_type(%User{current_org_id: _org_id}, _),
    do: {:error, :invalid_id, "ContentType"}

  def get_content_type(_, _), do: {:error, :fake}

  @doc """
  Get a content type from its ID. Also fetches all its related datas.
  """
  # TODO - improve tests
  @spec get_content_type_from_id(integer()) :: %ContentType{layout: %Layout{}, creator: %User{}}
  def get_content_type_from_id(id) do
    ContentType
    |> Repo.get(id)
    |> Repo.preload([:layout, :creator, [{:flow, :states}, {:fields, :field_type}]])
  end

  @doc """
  Get a content type field from its UUID.
  """
  @spec get_content_type_field(binary, User.t()) :: ContentTypeField.t()
  def get_content_type_field(<<_::288>> = id, %{current_org_id: org_id}) do
    query =
      from(cf in ContentTypeField,
        where: cf.id == ^id,
        join: c in ContentType,
        on: c.id == cf.content_type_id and c.organisation_id == ^org_id
      )

    case Repo.one(query) do
      %ContentTypeField{} = content_type_field -> content_type_field
      _ -> {:error, :invalid_id, "ContentTypeField"}
    end
  end

  def get_content_type_field(<<_::288>>, _), do: {:error, :invalid_id, "ContentTypeField"}
  def get_content_type_field(_, %{current_org_id: _}), do: {:error, :fake}

  @doc """
    Get Content Type field from content type id and field id
  """
  @spec get_content_type_field(map) :: ContentTypeField.t() | nil
  def get_content_type_field(%{"content_type_id" => content_type_id, "field_id" => field_id}),
    do: Repo.get_by(ContentTypeField, content_type_id: content_type_id, field_id: field_id)

  @doc """
  Update a content type.
  """
  @spec update_content_type(ContentType.t(), User.t(), map) ::
          %ContentType{
            layout: Layout.t(),
            creator: User.t()
          }
          | {:error, Ecto.Changeset.t()}
  def update_content_type(
        content_type,
        user,
        %{"layout_uuid" => layout_uuid, "flow_uuid" => f_uuid} = params
      ) do
    %Layout{id: id} = Layouts.get_layout(layout_uuid, user)
    %Flow{id: f_id} = Enterprise.get_flow(f_uuid, user)
    {_, params} = Map.pop(params, "layout_uuid")
    {_, params} = Map.pop(params, "flow_uuid")
    params = Map.merge(params, %{"layout_id" => id, "flow_id" => f_id})
    update_content_type(content_type, user, params)
  end

  def update_content_type(content_type, _user, params) do
    content_type
    |> ContentType.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, content_type} ->
        fetch_and_associate_fields(content_type, params)

        Repo.preload(content_type, [
          :layout,
          :creator,
          {:theme, :assets},
          [{:flow, :states}, {:fields, :field_type}]
        ])
    end
  end

  @doc """
  Delete a content type.
  """
  @spec delete_content_type(ContentType.t()) ::
          {:ok, ContentType.t()} | {:error, Ecto.Changeset.t()}
  def delete_content_type(content_type) do
    content_type
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :instances,
      message:
        "Cannot delete the content type. There are many contents under this content type. Delete those contents and try again.!"
    )
    |> Repo.delete()
  end

  @doc """
  Delete a content type field.
  """
  @spec delete_content_type_field(ContentTypeField.t()) ::
          {:ok, ContentTypeField.t()} | {:error, Ecto.Changeset.t()}
  def delete_content_type_field(content_type_field) do
    %ContentTypeField{field: field} = Repo.preload(content_type_field, :field)
    Repo.delete(field)
    Repo.delete(content_type_field)
    :ok
  end

  @doc """
   Get the content type by there id with preloading the data roles
  """
  def get_content_type_roles(id) do
    query = from(c in ContentType, where: c.id == ^id)
    query |> Repo.one() |> Repo.preload(:roles)
  end

  @doc """
    Get the role name by there uuid with preloading the content types
  """
  def get_content_type_under_roles(id) do
    query = from(r in Role, where: r.id == ^id)
    query |> Repo.one() |> Repo.preload(:content_types)
  end

  @doc """
  Get the content type with the id
  """
  def get_content_type(id) do
    query = from(c in ContentType, where: c.id == ^id)
    Repo.one(query)
  end

  @doc """
  create content type role function
  """
  def create_content_type_role(params) do
    %ContentTypeRole{}
    |> ContentTypeRole.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, content_type_role} ->
        Repo.preload(content_type_role, [:role, :content_type])

      {:error, _} = changeset ->
        changeset
    end
  end

  def filter_content_type_title(name, params) do
    query =
      from(ct in ContentType,
        where: ilike(ct.name, ^"%#{name}%"),
        preload: [:fields, :layout, :flow]
      )

    Repo.paginate(query, params)
  end

  def get_role_of_content_type(id, c_id) do
    query = from(r in Role, where: r.id == ^id, join: ct in ContentType, on: ct.id == ^c_id)

    Repo.one(query)
  end

  @doc """
  get the content type from the respective role
  """

  def get_content_type_role(id, role_id) do
    query = from(ct in ContentType, where: ct.id == ^id, join: r in Role, on: r.id == ^role_id)

    Repo.one(query)
  end

  def get_content_type_and_role(id) do
    query = from(ctr in ContentTypeRole, where: ctr.id == ^id)
    Repo.one(query)
  end

  def delete_content_type_role(content_type_role) do
    content_type_role
    |> Repo.delete()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, content_type_role} ->
        content_type_role
    end
  end

  @doc """
  delete the role of the content type
  """
  # TODO improve tests
  def delete_role_of_the_content_type(role) do
    role
    |> Repo.delete()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, role} ->
        role
    end
  end

  # def create_content_type_role(content_id, params) do
  #   content_type = get_content_type(content_id)

  #   Multi.new()
  #   |> Multi.insert(:role, Role.changeset(%Role{}, params))
  #   |> Multi.insert(:content_type_role, fn %{role: role} ->
  #     ContentTypeRole.changeset(%ContentTypeRole{}, %{
  #       content_type_id: content_type.id,
  #       role_id: role.id
  #     })
  #   end)
  #   |> Repo.transaction()
  #   |> case do
  #     {:error, _, changeset, _} ->
  #       {:error, changeset}

  #     {:ok, %{role: _role, content_type_role: content_type_role}} ->
  #       content_type_role
  #   end
  # end
end
