defmodule WraftDocWeb.Api.V1.ThemeView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.{ContentTypeView, UserView}

  def render("create.json", %{theme: theme}) do
    %{
      id: theme.id,
      name: theme.name,
      font: theme.font,
      body_color: theme.body_color,
      primary_color: theme.primary_color,
      secondary_color: theme.secondary_color,
      default_theme: theme.default_theme,
      typescale: theme.typescale,
      file: generate_url(theme),
      # send preview_file
      # preview_file: theme.preview_file
      updated_at: theme.updated_at,
      inserted_at: theme.inserted_at
    }
  end

  def render("index.json", %{
        themes: themes,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      themes: render_many(themes, ThemeView, "create.json", as: :theme),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{theme: theme}) do
    %{
      theme: render_one(theme, ThemeView, "create.json", as: :theme),
      creator: render_one(theme.creator, UserView, "user.json", as: :user)
    }
  end

  defp generate_url(%{file: file} = theme) do
    WraftDocWeb.ThemeUploader.url({file, theme})
  end
end
