defmodule WraftDoc.Themes.Fonts do
  @moduledoc """
    Module for managing fonts.
  """
  import Ecto.Query

  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Repo
  alias WraftDoc.Themes.Font
  alias WraftDoc.Themes.FontAsset

  def list_fonts(%{current_org_id: current_org_id} = _current_user) do
    Font
    |> where([f], f.organisation_id == ^current_org_id)
    |> Repo.all()
    |> Repo.preload(:assets)
  end

  def get_font(id) do
    Font
    |> Repo.get(id)
    |> Repo.preload(:assets)
  end

  def create_font(%{id: user_id, current_org_id: current_org_id} = current_user, attrs \\ %{}) do
    %Font{}
    |> Font.changeset(
      Map.merge(attrs, %{"creator_id" => user_id, "organisation_id" => current_org_id})
    )
    |> Repo.insert()
    |> case do
      {:ok, font} ->
        fetch_and_associate_assets_with_font(font, current_user, attrs)

        {:ok, Repo.preload(font, [:assets])}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_font(%Font{} = font, attrs) do
    font
    |> Font.changeset(attrs)
    |> Repo.update()
  end

  def delete_font(%Font{} = font) do
    Repo.delete(font)
  end

  # TODO accept files directly then create assets
  # Get all the assets from their UUIDs and associate them with the given theme.
  defp fetch_and_associate_assets_with_font(font, current_user, %{"assets" => assets}) do
    (assets || "")
    |> String.split(",")
    |> Stream.map(fn asset -> Assets.get_asset(asset, current_user) end)
    |> Stream.map(fn asset -> associate_font_and_asset(font, asset) end)
    |> Enum.to_list()
  end

  defp fetch_and_associate_assets_with_font(_font, _current_user, _params), do: []

  # Associate the asset with the given theme, ie; insert a ThemeAsset entry.
  defp associate_font_and_asset(font, %Asset{} = asset) do
    %FontAsset{}
    |> FontAsset.changeset(%{font_id: font.id, asset_id: asset.id})
    |> Repo.insert()
  end

  defp associate_font_and_asset(_font, _asset), do: nil
end
