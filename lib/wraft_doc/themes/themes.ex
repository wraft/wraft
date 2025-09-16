defmodule WraftDoc.Themes do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto
  import Ecto.Query
  require Logger

  alias WraftDoc.Account.User
  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Client.Minio
  alias WraftDoc.Documents
  alias WraftDoc.Repo
  alias WraftDoc.Themes.Theme
  alias WraftDoc.Themes.ThemeAsset

  @doc """
  Create a theme.
  """
  @spec create_theme(User.t(), map) :: {:ok, Theme.t()} | {:error, Ecto.Changeset.t()}
  def create_theme(%{current_org_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:themes)
    |> Theme.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, theme} ->
        theme_preview_file_upload(theme, params)
        fetch_and_associcate_assets_with_theme(theme, current_user, params)

        Repo.preload(theme, [:assets])

      {:error, _} = changeset ->
        changeset
    end
  end

  # Get all the assets from their UUIDs and associate them with the given theme.
  defp fetch_and_associcate_assets_with_theme(theme, current_user, %{"assets" => assets}) do
    (assets || "")
    |> String.split(",")
    |> Stream.map(fn asset -> Assets.get_asset(asset, current_user) end)
    |> Stream.map(fn asset -> associate_theme_and_asset(theme, asset) end)
    |> Enum.to_list()
  end

  defp fetch_and_associcate_assets_with_theme(_theme, _current_user, _params), do: []

  # Associate the asset with the given theme, ie; insert a ThemeAsset entry.
  defp associate_theme_and_asset(theme, %Asset{} = asset) do
    %ThemeAsset{}
    |> ThemeAsset.changeset(%{theme_id: theme.id, asset_id: asset.id})
    |> Repo.insert()
  end

  defp associate_theme_and_asset(_theme, _asset), do: nil

  @doc """
  Upload theme preview file.
  """
  @spec theme_preview_file_upload(Theme.t(), map) ::
          {:ok, %Theme{}} | {:error, Ecto.Changeset.t()}
  def theme_preview_file_upload(theme, %{"preview_file" => _} = params) do
    theme |> Theme.file_changeset(params) |> Repo.update()
  end

  def theme_preview_file_upload(theme, _params) do
    {:ok, theme}
  end

  @doc """
  Index of themes inside current user's organisation.
  """
  @spec theme_index(User.t(), map) :: map
  def theme_index(%User{current_org_id: org_id}, params) do
    Theme
    |> where([t], t.organisation_id == ^org_id)
    |> where(^theme_filter_by_name(params))
    |> order_by(^theme_sort(params))
    |> preload(:assets)
    |> Repo.paginate(params)
  end

  defp theme_filter_by_name(%{"name" => name} = _params),
    do: dynamic([t], ilike(t.name, ^"%#{name}%"))

  defp theme_filter_by_name(_), do: true

  defp theme_sort(%{"sort" => "name_desc"} = _params), do: [desc: dynamic([t], t.name)]

  defp theme_sort(%{"sort" => "name"} = _params), do: [asc: dynamic([t], t.name)]

  defp theme_sort(%{"sort" => "inserted_at"}), do: [asc: dynamic([t], t.inserted_at)]

  defp theme_sort(%{"sort" => "inserted_at_desc"}), do: [desc: dynamic([t], t.inserted_at)]

  defp theme_sort(_), do: []

  @doc """
  Get a theme from its UUID.
  """
  # TODO - improve test
  @spec get_theme(binary, User.t()) :: Theme.t() | nil
  def get_theme(theme_uuid, %{current_org_id: org_id}) do
    Theme
    |> Repo.get_by(id: theme_uuid, organisation_id: org_id)
    |> Repo.preload(:assets)
  end

  def get_theme(theme_id, org_id) do
    Logger.info(
      "Theme not found for theme_id #{inspect(theme_id)} - organisation_id #{inspect(org_id)}"
    )

    nil
  end

  @doc """
  Show a theme.
  """
  # TODO - improve test
  @spec show_theme(binary, User.t()) :: %Theme{creator: User.t()} | nil
  def show_theme(theme_uuid, user) do
    theme_uuid |> get_theme(user) |> Repo.preload([:creator])
  end

  @doc """
  Update a theme.
  """
  # TODO - improve test
  @spec update_theme(Theme.t(), User.t(), map()) ::
          {:ok, Theme.t()} | {:error, Ecto.Changeset.t()}
  def update_theme(theme, current_user, params) do
    theme
    |> Theme.update_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, theme} ->
        theme_preview_file_upload(theme, params)
        fetch_and_associcate_assets_with_theme(theme, current_user, params)

        Repo.preload(theme, [:assets])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Delete a theme.
  """
  @spec delete_theme(Theme.t()) :: {:ok, Theme.t()}
  def delete_theme(%{organisation_id: org_id} = theme) do
    asset_query =
      from(asset in Asset,
        join: theme_asset in ThemeAsset,
        on: asset.id == theme_asset.asset_id and theme_asset.theme_id == ^theme.id,
        select: asset.id
      )

    theme_asset_query = from(ta in ThemeAsset, where: ta.theme_id == ^theme.id)

    # Delete the theme preview file
    Minio.delete_file("organisations/#{org_id}/theme/theme_preview/#{theme.id}")

    # Deletes the asset files
    asset_query
    |> Repo.all()
    |> Enum.each(&Minio.delete_file("organisations/#{org_id}/assets/#{&1}"))

    Repo.delete_all(asset_query)
    Repo.delete_all(theme_asset_query)
    Repo.delete(theme)
  end

  @spec get_theme_details(Theme.t(), String.t()) :: map()
  def get_theme_details(%Theme{} = theme, mkdir),
    do:
      Map.merge(
        %{
          body_color: theme.body_color,
          primary_color: theme.primary_color,
          secondary_color: theme.secondary_color,
          typescale: Jason.encode!(theme.typescale)
        },
        get_font_details(theme, mkdir)
      )

  defp get_font_details(%Theme{assets: [%{file: %{file_name: file_name}} | _]} = theme, mkdir) do
    [font_name, _, file_type] = String.split(file_name, ~r/[-.]/)

    %{
      base_font_name: get_base_font_name(font_name),
      font_name: "#{font_name}-Regular.#{file_type}",
      font_options: font_options(theme, mkdir)
    }
  end

  defp get_font_details(_, mkdir) do
    File.cp(File.cwd!() <> "/priv/wraft_files/Roboto/.", mkdir <> "/fonts")

    %{
      base_font_name: "Roboto",
      font_name: "Roboto-Regular.ttf",
      font_options: [
        "ItalicFont=Roboto-Italic.ttf",
        "BoldItalicFont=Roboto-BoldItalic.ttf",
        "BoldFont=Roboto-Bold.ttf"
      ]
    }
  end

  defp font_options(%Theme{organisation_id: org_id} = theme, mkdir) do
    theme.assets
    |> Stream.map(fn asset ->
      file_name = asset.file.file_name
      binary = Minio.download("organisations/#{org_id}/assets/#{asset.id}/#{file_name}")

      mkdir
      |> Path.join("fonts")
      |> File.mkdir_p!()

      asset_file_path = Path.join(mkdir, "fonts/#{file_name}")
      File.write!(asset_file_path, binary)

      [_, font_type, _] = String.split(file_name, ~r/[-.]/)

      case Enum.member?(["Bold", "Italic", "BoldItalic"], font_type) do
        true -> "#{font_type}Font=#{file_name}"
        false -> ""
      end
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp get_base_font_name(font_name),
    do:
      font_name
      |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1 \\2")
      |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2")

  def font_option_header(header, font_options) do
    Enum.reduce(font_options, header, fn font_option, acc ->
      Documents.concat_strings(acc, "- #{font_option}\n")
    end)
  end
end
