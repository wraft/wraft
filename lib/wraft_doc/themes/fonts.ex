defmodule WraftDoc.Themes.Fonts do
  @moduledoc """
    Module for managing fonts.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Repo
  alias WraftDoc.Themes.Font
  alias WraftDoc.Themes.FontAsset

  @doc """
  Lists all fonts for the given organisation, preloading their assets.

  ## Parameters
    - current_user: a map containing at least `:current_org_id`

  ## Returns
    - List of Font structs with preloaded assets.
  """
  @spec list_fonts(User.t()) :: [Font.t()]
  def list_fonts(%{current_org_id: current_org_id} = _current_user) do
    Font
    |> where([f], f.organisation_id == ^current_org_id)
    |> Repo.all()
    |> Repo.preload(:assets)
  end

  @doc """
  Gets a font by its ID, preloading its assets.

  ## Parameters
    - id: Font ID

  ## Returns
    - Font struct with preloaded assets, or nil if not found.
  """
  @spec get_font(Ecto.UUID.t()) :: Font.t() | nil
  def get_font(id) do
    Font
    |> Repo.get(id)
    |> Repo.preload(:assets)
  end

  @doc """
  Creates a font and its associated assets.

  ## Parameters
    - current_user: map with `:id` and `:current_org_id`
    - attrs: attributes for the font, including `"files"` for assets

  ## Returns
    - {:ok, Font.t()} on success
    - {:error, reason} on failure
  """
  @spec create_font(User.t(), map()) :: {:ok, Font.t()} | {:error, Ecto.Changeset.t()}
  def create_font(%{id: user_id, current_org_id: current_org_id} = current_user, attrs \\ %{}) do
    Multi.new()
    |> Multi.insert(:create_font, fn _changeset ->
      Font.changeset(
        %Font{},
        Map.merge(attrs, %{"creator_id" => user_id, "organisation_id" => current_org_id})
      )
    end)
    |> Multi.run(:create_assets, fn _repo, _changeset ->
      create_assets(current_user, List.wrap(attrs["files"]))
    end)
    |> Multi.run(:create_font_assets, fn _repo, %{create_font: font, create_assets: assets} ->
      Enum.each(assets, &associate_font_and_asset(font, &1))
      {:ok, nil}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{create_font: font}} ->
        {:ok, Repo.preload(font, [:assets])}

      {:error, _, error, _} ->
        {:error, error}
    end
  end

  @doc """
  Updates a font with the given attributes.

  ## Parameters
    - font: Font struct
    - current_user: User struct
    - attrs: attributes to update

  ## Returns
    - {:ok, Font.t()} on success
    - {:error, changeset} on failure
  """
  @spec update_font(Font.t(), User.t(), map()) :: {:ok, Font.t()} | {:error, Ecto.Changeset.t()}
  def update_font(%Font{} = font, current_user, attrs) do
    Multi.new()
    |> Multi.update(:update_font, Font.changeset(font, attrs))
    |> maybe_replace_assets(font, current_user, attrs)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_font: font}} ->
        {:ok, Repo.preload(font, [:assets])}

      {:error, _, error, _} ->
        {:error, error}
    end
  end

  @doc """
  Deletes the given font.

  ## Parameters
    - font: Font struct

  ## Returns
    - {:ok, Font.t()} on success
    - {:error, changeset} on failure
  """
  @spec delete_font(Font.t()) :: {:ok, Font.t()} | {:error, Ecto.Changeset.t()}
  def delete_font(%Font{} = font), do: Repo.delete(font)

  defp associate_font_and_asset(font, %Asset{} = asset) do
    %FontAsset{}
    |> FontAsset.changeset(%{font_id: font.id, asset_id: asset.id})
    |> Repo.insert()
  end

  defp associate_font_and_asset(_font, _asset), do: nil

  defp maybe_replace_assets(multi, font, current_user, %{"files" => files})
       when is_list(files) and length(files) > 0 do
    multi
    |> Multi.delete_all(:delete_font_assets, Ecto.assoc(font, :font_assets))
    |> Multi.delete_all(:delete_assets, Ecto.assoc(font, :assets))
    |> Multi.run(:create_assets, fn _repo, _changes ->
      create_assets(current_user, files)
    end)
    |> Multi.run(:create_font_assets, fn _repo, %{update_font: font, create_assets: assets} ->
      Enum.each(assets, &associate_font_and_asset(font, &1))
      {:ok, nil}
    end)
  end

  defp maybe_replace_assets(multi, _font, _current_user, _attrs), do: multi

  defp create_assets(current_user, files) do
    files
    |> Enum.map(
      &Assets.create_asset(current_user, %{
        "file" => &1,
        "type" => "theme",
        "name" => &1.filename
      })
    )
    |> Enum.reduce({:ok, []}, fn
      {:ok, asset}, {:ok, acc} -> {:ok, [asset | acc]}
      {:error, _} = err, _ -> err
    end)
  end
end
