defmodule WraftDoc.TemplateAssets do
  @moduledoc """
  Context module for Template Assets.
  """
  import Ecto
  import Ecto.Query

  alias Ecto.Multi
  alias WraftDoc.Repo
  alias WraftDoc.TemplateAssets.TemplateAsset

  @doc """
  Create a template asset.
  """
  # TODO - write test
  @spec create_template_asset(User.t(), map) :: {:ok, TemplateAsset.t()}
  def create_template_asset(%{current_org_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    Multi.new()
    |> Multi.insert(
      :template_asset,
      current_user |> build_assoc(:template_assets) |> TemplateAsset.changeset(params)
    )
    |> Multi.update(
      :template_asset_file_upload,
      &TemplateAsset.file_changeset(&1.template_asset, params)
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{template_asset_file_upload: template_asset}} -> {:ok, template_asset}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def create_template_asset(_, _), do: {:error, :fake}

  @doc """
  Index of all template assets in an organisation.
  """
  # TODO - Write tests
  @spec template_asset_index(integer, map) :: map
  def template_asset_index(%{current_org_id: organisation_id}, params) do
    query =
      from(a in TemplateAsset,
        where: a.organisation_id == ^organisation_id,
        order_by: [desc: a.inserted_at]
      )

    Repo.paginate(query, params)
  end

  def template_asset_index(_, _), do: {:error, :fake}

  @doc """
  Show a template asset.
  """
  # TODO - write tests
  @spec show_template_asset(binary, User.t()) :: %TemplateAsset{creator: User.t()}
  def show_template_asset(template_asset_id, user) do
    template_asset_id
    |> get_template_asset(user)
    |> Repo.preload([:creator])
  end

  @doc """
  Get a template asset from its UUID.
  """
  # TODO - Write tests
  @spec get_template_asset(binary, User.t()) :: TemplateAsset.t()
  def get_template_asset(<<_::288>> = id, %{current_org_id: org_id}) do
    case Repo.get_by(TemplateAsset, id: id, organisation_id: org_id) do
      %TemplateAsset{} = template_asset -> template_asset
      _ -> {:error, :invalid_id}
    end
  end

  def get_template_asset(<<_::288>>, _), do: {:error, :fake}
  def get_template_asset(_, %{current_org_id: _}), do: {:error, :invalid_id}

  @doc """
  Update a template asset.
  """
  # TODO - Write tests
  # TODO - Add file update
  @spec update_template_asset(TemplateAsset.t(), map) ::
          {:ok, TemplateAsset.t()} | {:error, Ecto.Changset.t()}
  def update_template_asset(template_asset, params) do
    template_asset |> TemplateAsset.update_changeset(params) |> Repo.update()
  end

  @doc """
  Delete a template asset.
  """
  @spec delete_template_asset(Asset.t()) :: {:ok, TemplateAsset.t()}
  def delete_template_asset(%TemplateAsset{} = template_asset) do
    # Delete the uploaded file
    Repo.delete(template_asset)
  end
end
