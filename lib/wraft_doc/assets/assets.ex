defmodule WraftDoc.Assets do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto
  import Ecto.Query
  require Logger

  alias Ecto.Multi
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Client.Minio
  alias WraftDoc.Documents
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Frames.Frame
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Repo

  @doc """
  Create an asset.
  """
  # TODO - imprvove tests
  @spec create_asset(User.t(), map) :: {:ok, Asset.t()}
  def create_asset(%{current_org_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    Multi.new()
    |> Multi.insert(:asset, current_user |> build_assoc(:assets) |> Asset.changeset(params))
    |> Multi.update(:asset_file_upload, &Asset.file_changeset(&1.asset, params))
    |> Repo.transaction()
    |> case do
      {:ok, %{asset_file_upload: asset}} -> {:ok, asset}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def create_asset(_, _), do: {:error, :fake}

  @doc """
  Index of all assets in an organisation.
  """
  # TODO - improve tests
  @spec asset_index(integer, map) :: map
  def asset_index(%{current_org_id: organisation_id}, params) do
    query =
      from(a in Asset,
        where: a.organisation_id == ^organisation_id,
        order_by: [desc: a.inserted_at]
      )

    Repo.paginate(query, params)
  end

  def asset_index(_, _), do: {:error, :fake}

  @doc """
  Show an asset.
  """
  # TODO - improve tests
  @spec show_asset(binary, User.t()) :: %Asset{creator: User.t()}
  def show_asset(asset_id, user) do
    with %Asset{} = asset <-
           get_asset(asset_id, user) do
      Repo.preload(asset, [:creator])
    end
  end

  @doc """
  Get an asset from its UUID.
  """
  # TODO - improve tests
  @spec get_asset(binary, User.t()) :: Asset.t()
  def get_asset(<<_::288>> = id, %{current_org_id: org_id}) do
    case Repo.get_by(Asset, id: id, organisation_id: org_id) do
      %Asset{} = asset -> asset
      _ -> {:error, :invalid_id}
    end
  end

  def get_asset(<<_::288>>, _), do: {:error, :fake}
  def get_asset(_, %{current_org_id: _}), do: {:error, :invalid_id}

  @doc """
  Update an asset.
  """
  # TODO - improve tests
  # file uploading is throwing errors, in tests
  @spec update_asset(Asset.t(), map) :: {:ok, Asset.t()} | {:error, Ecto.Changset.t()}
  def update_asset(asset, params) do
    asset |> Asset.update_changeset(params) |> Repo.update()
  end

  @doc """
  Delete an asset.
  """
  @spec delete_asset(Asset.t()) :: {:ok, Asset.t()}
  def delete_asset(asset) do
    # Delete the uploaded file
    Repo.delete(asset)
  end

  @doc """
  Preload assets of a layout.
  """
  @spec preload_asset(Layout.t()) :: Layout.t()
  def preload_asset(%Layout{} = layout) do
    Repo.preload(layout, [:assets])
  end

  def preload_asset(_), do: {:error, :not_sufficient}

  def download_slug_file(%Layout{frame: nil, slug: slug}),
    do: :wraft_doc |> :code.priv_dir() |> Path.join("slugs/#{slug}/.")

  def download_slug_file(%Layout{
        frame: %Frame{id: frame_id, name: name},
        organisation_id: organisation_id
      }) do
    :wraft_doc
    |> :code.priv_dir()
    |> Path.join("slugs/organisation/#{organisation_id}/#{name}/.")
    |> File.exists?()
    |> case do
      true ->
        :wraft_doc
        |> :code.priv_dir()
        |> Path.join("slugs/organisation/#{organisation_id}/#{name}/.")

      false ->
        slugs_dir =
          :wraft_doc
          |> :code.priv_dir()
          |> Path.join("slugs/organisation/#{organisation_id}/#{name}/.")

        File.mkdir_p!(slugs_dir)

        template_path = Path.join(slugs_dir, "template.tex")

        "organisations/#{organisation_id}/frames/#{frame_id}"
        |> Minio.download()
        |> then(&File.write!(template_path, &1))

        slugs_dir
    end
  end

  def pdf_file_path(
        %Instance{instance_id: instance_id, versions: build_versions},
        instance_dir_path,
        true
      ) do
    build_versions
    |> Documents.versioned_file_name(instance_id, :next)
    |> then(&Path.join(instance_dir_path, &1))
  end

  def pdf_file_path(
        %Instance{instance_id: instance_id, versions: build_versions},
        instance_dir_path,
        false
      ) do
    build_versions
    |> Documents.versioned_file_name(instance_id, :current)
    |> then(&Path.join(instance_dir_path, &1))
  end

  # Find the header values for the content.md file from the assets of the layout used.
  @spec find_asset_header_values(Asset.t(), String.t(), String.t(), Instance.t()) :: String.t()
  def find_asset_header_values(
        %Asset{name: name, file: file, organisation_id: org_id} = asset,
        acc,
        %Layout{frame: frame, slug: slug},
        %Instance{
          instance_id: instance_id
        }
      ) do
    binary = Minio.download("organisations/#{org_id}/assets/#{asset.id}/#{file.file_name}")

    asset_file_path =
      Path.join(File.cwd!(), "organisations/#{org_id}/contents/#{instance_id}/#{file.file_name}")

    File.write!(asset_file_path, binary)

    if frame != nil || slug == "pletter" do
      Documents.concat_strings(acc, "letterhead: #{asset_file_path} \n")
    else
      Documents.concat_strings(acc, "#{name}: #{asset_file_path} \n")
    end
  end
end
