defmodule WraftDoc.Repo.Migrations.RevampThemeAssetsIntoFont do
  use Ecto.Migration
  import Ecto.Query

  alias WraftDoc.Assets.Asset
  alias WraftDoc.Repo
  alias WraftDoc.Themes.{Font, FontAsset, Theme, ThemeAsset}

  def up do
    migrate_themes_to_fonts()
  end

  def down, do: :ok

  @doc """
  Step 2: Create fonts, font_assets and associate themes with fonts
  """
  def migrate_themes_to_fonts do
    formatted_data = get_theme_assets_formatted()

    Enum.each(formatted_data, &migrate_theme_fonts/1)

    IO.puts("🎉 Migration completed successfully!")
  end

  defp migrate_theme_fonts(theme_data) do
    Repo.transaction(fn ->
      created_fonts = create_fonts_for_theme(theme_data)
      primary_font = created_fonts[theme_data.primary_font]
      update_theme_font_association(theme_data.theme_id, primary_font.id)

      IO.puts(
        "✅ Processed theme #{theme_data.theme_name} (ID: #{theme_data.theme_id}) with primary font: #{theme_data.primary_font}"
      )
    end)
  end

  defp create_fonts_for_theme(theme_data) do
    theme_data.fonts
    |> Enum.map(fn {font_name, asset_ids} ->
      font = find_or_create_font(font_name, theme_data.organisation_id, theme_data.creator_id)
      create_font_assets(font.id, asset_ids)
      {font_name, font}
    end)
    |> Enum.into(%{})
  end

  defp get_theme_assets_formatted do
    query =
      from(ta in ThemeAsset,
        join: t in Theme,
        on: ta.theme_id == t.id,
        join: a in Asset,
        on: ta.asset_id == a.id,
        where: not is_nil(t.organisation_id),
        select: %{
          theme_id: ta.theme_id,
          theme_name: t.name,
          organisation_id: t.organisation_id,
          creator_id: t.creator_id,
          asset_id: ta.asset_id,
          asset_name: a.name
        }
      )

    theme_assets = Repo.all(query)

    # Group by theme and extract font information
    theme_assets
    |> Enum.group_by(& &1.theme_id)
    |> Enum.map(fn {theme_id, assets} ->
      # Get font names from all assets for this theme
      font_assets_map =
        assets
        |> Enum.group_by(&extract_font_name(&1.asset_name))
        |> Enum.map(fn {font_name, font_assets} ->
          {font_name, Enum.map(font_assets, & &1.asset_id)}
        end)
        |> Enum.into(%{})

      # Get first asset info for theme metadata
      first_asset = List.first(assets)

      %{
        theme_id: theme_id,
        theme_name: first_asset.theme_name,
        organisation_id: first_asset.organisation_id,
        creator_id: first_asset.creator_id,
        fonts: font_assets_map,
        primary_font: get_primary_font_name(font_assets_map)
      }
    end)
  end

  # Helper function to extract font name from asset name
  defp extract_font_name(asset_name) do
    cond do
      String.contains?(asset_name, "-") ->
        asset_name |> String.split("-") |> List.first()

      String.contains?(asset_name, ".") ->
        asset_name |> String.split(".") |> List.first()

      true ->
        asset_name
    end
  end

  # Helper function to get primary font name (first font)
  defp get_primary_font_name(fonts_map) do
    fonts_map |> Map.keys() |> List.first()
  end

  # Helper function to find existing font or create new one
  defp find_or_create_font(font_name, organisation_id, creator_id) do
    case Repo.get_by(Font, name: font_name, organisation_id: organisation_id) do
      nil ->
        %Font{}
        |> Font.changeset(%{
          name: font_name,
          organisation_id: organisation_id,
          creator_id: creator_id
        })
        |> Repo.insert!()

      existing_font ->
        existing_font
    end
  end

  # Helper function to create font_assets entries
  defp create_font_assets(font_id, asset_ids) do
    # Get existing font_assets to avoid duplicates
    existing_asset_ids =
      FontAsset
      |> where(font_id: ^font_id)
      |> select([fa], fa.asset_id)
      |> Repo.all()
      |> MapSet.new()

    # Insert only new associations
    new_asset_ids =
      asset_ids
      |> MapSet.new()
      |> MapSet.difference(existing_asset_ids)
      |> MapSet.to_list()

    font_asset_entries =
      Enum.map(new_asset_ids, fn asset_id ->
        %{
          font_id: font_id,
          asset_id: asset_id,
          inserted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
          updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        }
      end)

    if length(font_asset_entries) > 0 do
      Repo.insert_all(FontAsset, font_asset_entries)
      IO.puts("  📎 Added #{length(font_asset_entries)} new assets to font #{font_id}")
    end
  end

  # Helper function to update theme with font association
  defp update_theme_font_association(theme_id, font_id) do
    theme = Repo.get!(Theme, theme_id)

    theme
    |> Theme.changeset(%{font_id: font_id})
    |> Repo.update!()
  end

  @doc """
  Preview function to see what will be processed without making changes
  """
  def preview_migration do
    formatted_data = get_theme_assets_formatted()

    Enum.each(formatted_data, fn theme_data ->
      IO.puts("\n📋 Theme: #{theme_data.theme_name} (ID: #{theme_data.theme_id})")
      IO.puts("   Organisation: #{theme_data.organisation_id}")
      IO.puts("   Primary Font: #{theme_data.primary_font}")
      IO.puts("   Fonts to process:")

      Enum.each(theme_data.fonts, fn {font_name, asset_ids} ->
        IO.puts(
          "     • #{font_name}: #{length(asset_ids)} assets (#{Enum.join(asset_ids, ", ")})"
        )
      end)
    end)

    IO.puts("\n📊 Summary:")
    IO.puts("   Total themes to process: #{length(formatted_data)}")
    total_fonts = formatted_data |> Enum.map(&map_size(&1.fonts)) |> Enum.sum()
    IO.puts("   Total font records to create/update: #{total_fonts}")
  end
end
