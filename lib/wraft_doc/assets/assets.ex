defmodule WraftDoc.Assets do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto
  import Ecto.Query
  require Logger

  alias Ecto.Multi
  alias WraftDoc.Account.User
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Client.Minio
  alias WraftDoc.Documents
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Frames.Frame
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Repo
  alias WraftDoc.Utils.FileHelper

  @doc """
  Create an asset.
  """
  # TODO - imprvove tests
  @spec create_asset(User.t(), map()) ::
          {:ok, Asset.t()} | {:error, Ecto.Changset.t() | String.t()}
  def create_asset(%User{current_org_id: org_id} = current_user, params) do
    with {:ok, params} <- update_asset_params(Map.put(params, "organisation_id", org_id)),
         {:ok, %Asset{} = asset} <- create_asset_with_params(current_user, params) do
      {:ok, asset}
    end
  end

  def create_asset(nil, params), do: create_asset_with_params(nil, params)

  def update_asset_params(%{"type" => "global_file", "file" => file} = params) do
    file
    |> FileHelper.get_file_metadata()
    |> case do
      {:ok, metadata} ->
        {:ok, Map.merge(params, metadata)}

      {:error, error} ->
        {:error, error}
    end
  end

  def update_asset_params(params), do: {:ok, params}

  defp create_asset_with_params(current_user, params) do
    Multi.new()
    |> public_asset_multi(current_user, params)
    |> Multi.update(:asset_file_upload, &Asset.file_changeset(&1.asset, params))
    |> Repo.transaction()
    |> case do
      {:ok, %{asset_file_upload: asset}} -> {:ok, asset}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  defp public_asset_multi(multi, nil, params) do
    Multi.insert(
      multi,
      :asset,
      Asset.public_changeset(%Asset{}, params)
    )
  end

  defp public_asset_multi(multi, %User{} = current_user, params) do
    Multi.insert(
      multi,
      :asset,
      current_user |> build_assoc(:assets) |> Asset.changeset(params)
    )
  end

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

  def get_asset(<<_::288>> = asset_id, nil), do: Repo.get(Asset, asset_id)
  def get_asset(<<_::288>>, _), do: {:error, :fake}
  def get_asset(_, %{current_org_id: _}), do: {:error, :invalid_id}
  def get_asset(<<_::288>> = asset_id), do: Repo.get(Asset, asset_id)

  @doc """
  Update an asset.
  """
  # TODO - improve tests
  # file uploading is throwing errors, in tests
  @spec update_asset(Asset.t(), map()) :: {:ok, Asset.t()} | {:error, Ecto.Changset.t()}
  def update_asset(asset, params) do
    asset
    |> Asset.update_changeset(params)
    |> Repo.update()
  end

  @doc """
    Get asset image url
  """
  @spec get_image_url(Asset.t()) :: String.t() | nil
  def get_image_url(%Asset{type: "document", url: nil, expiry_date: nil} = asset),
    do: update_expiry_date(asset)

  def get_image_url(%Asset{type: "document", url: image_url, expiry_date: expiry_date} = asset) do
    if expired?(expiry_date) do
      update_expiry_date(asset)
    else
      image_url
    end
  end

  def get_image_url(_), do: nil

  defp update_expiry_date(%Asset{file: file} = asset) do
    asset
    |> Asset.update_expiry_date_changeset(%{
      expiry_date: new_expiry_date(1, :hour),
      url: WraftDocWeb.AssetUploader.url({file, asset}, signed: true, expires_in: 3600)
    })
    |> Repo.update()
    |> case do
      {:ok, asset} -> asset.url
      _ -> nil
    end
  end

  @doc """
  Check if a date is expired.
  """
  @spec expired?(String.t()) :: boolean()
  def expired?(expiry_date) do
    DateTime.compare(expiry_date, DateTime.utc_now()) == :lt
  end

  @doc """
  Generate a new expiry date
  """
  @spec new_expiry_date(integer(), atom()) :: String.t()
  def new_expiry_date(amount, unit) do
    DateTime.utc_now()
    |> DateTime.add(amount, unit)
    |> DateTime.to_iso8601()
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
    Repo.preload(layout, [
      :asset,
      :creator,
      :organisation,
      :engine,
      frame: [:asset]
    ])
  end

  def preload_asset(_), do: {:error, :not_sufficient}

  @doc """
  Download slug / frame files.
  """
  @spec download_slug_file(Layout.t()) :: String.t()
  def download_slug_file(%Layout{frame: nil, slug: slug}),
    do: :wraft_doc |> :code.priv_dir() |> Path.join("slugs/#{slug}/.")

  def download_slug_file(%Layout{
        frame: %Frame{
          asset: %{id: asset_id, file: file}
        },
        organisation_id: organisation_id
      }) do
    binary =
      Minio.get_object("organisations/#{organisation_id}/assets/#{asset_id}/#{file.file_name}")

    asset_file_path = Briefly.create!(type: :directory)

    FileHelper.extract_file(binary, asset_file_path)
  end

  @doc """
  Return the path of PDF file.
  """
  @spec pdf_file_path(Instance.t(), String.t(), boolean()) :: String.t()
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

  @doc """
  Find the header values for the content.md file from the assets of the layout used.
  """
  @spec find_asset_header_values(String.t(), Layout.t(), Instance.t()) :: String.t()
  def find_asset_header_values(
        acc,
        %Layout{
          frame: frame,
          asset: %Asset{id: asset_id, file: file, organisation_id: org_id}
        },
        %Instance{
          instance_id: instance_id
        }
      ) do
    binary = Minio.download("organisations/#{org_id}/assets/#{asset_id}/#{file.file_name}")

    asset_file_path =
      Path.join(File.cwd!(), "organisations/#{org_id}/contents/#{instance_id}/#{file.file_name}")

    File.write!(asset_file_path, binary)

    header =
      if frame == nil do
        Documents.concat_strings(acc, "letterhead: #{asset_file_path} \n")
      else
        acc
      end

    {:ok, header}
  end

  def find_asset_header_values(_, %Layout{}, _), do: {"Layout background not found.", 1099}

  # TODO update preview.
  @doc """
  Preview asset.
  """
  @spec preview_asset(String.t()) :: {:ok, map()} | {:error, String.t()}
  def preview_asset(file_path) do
    file_path
    |> FileHelper.read_file_contents()
    |> case do
      {:ok, file_binary} ->
        FileHelper.get_wraft_json(file_binary)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
